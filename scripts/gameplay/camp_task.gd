extends StaticBody3D
## SPEC-011 — Puesto de reconstrucción de Q08 (altar, arcoíris, tiendas).
## E cerca lo completa una vez y cuenta en la quest del grupo indicado.
## Solo servidor/solo aplican; `done` se sincroniza. Sin combate ni fail.

@export var quest_group: String = "quest_Q08"
@export var task_name: String = "Altar"
@export var action_text: String = "E · Ofrecer gratitud"
@export var interact_radius: float = 3.5

var done := false

var _quest: Node = null
var _prompt: Label3D = null
var _label: Label3D = null
var _shown := false


func _ready() -> void:
	add_to_group("q08_tasks")
	_prompt = $PromptLabel
	_label = $TaskLabel
	_label.text = task_name
	_prompt.text = action_text
	_prompt.visible = false
	_quest = get_tree().get_first_node_in_group(quest_group)
	_setup_replication()


func complete() -> bool:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return false
	if done or not _task_open():
		return false
	done = true
	if _quest != null:
		_quest.register_task()
	return true


func _process(_delta: float) -> void:
	_apply_visual()
	var near := _nearest_avatar() != null
	_prompt.visible = near and not done and _task_open()
	if _authoritative() and near and not done and _task_open() and Input.is_action_just_pressed("interact"):
		complete()


func _apply_visual() -> void:
	if done == _shown:
		return
	_shown = done
	if _label != null:
		_label.modulate = Color(0.7, 1.0, 0.7, 1) if done else Color(1.0, 0.9, 0.6, 1)


func _task_open() -> bool:
	return _quest != null and (_quest.state == &"available" or _quest.state == &"active")


func _nearest_avatar() -> Node3D:
	var best: Node3D = null
	var best_d := interact_radius
	for p in get_tree().get_nodes_in_group("player"):
		var p3 := p as Node3D
		if p3 == null:
			continue
		var d := global_position.distance_to(p3.global_position)
		if d < best_d:
			best_d = d
			best = p3
	return best


func _authoritative() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


func _setup_replication() -> void:
	var sync := get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync == null:
		return
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(".:done")
	sync.replication_config = cfg
