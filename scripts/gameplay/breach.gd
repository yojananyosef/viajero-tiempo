extends StaticBody3D
## SPEC-010 — Brecha del Arca. E cerca la sella y cuenta en Q07 (3/4).
## Solo servidor/solo aplican; `sealed` se sincroniza. Reabre con reset.

@export var interact_radius: float = 3.5

var sealed := false

var _quest: Node = null
var _prompt: Label3D = null
var _label: Label3D = null
var _shown := false


func _ready() -> void:
	add_to_group("q07_breaches")
	_prompt = $PromptLabel
	_label = $SealLabel
	_prompt.visible = false
	_quest = get_tree().get_first_node_in_group("quest_Q07")
	_setup_replication()


func seal() -> bool:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return false
	if sealed or not _task_open():
		return false
	sealed = true
	if _quest != null:
		_quest.register_task()
	return true


func reset_breach() -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	sealed = false


func _process(_delta: float) -> void:
	_apply_visual()
	var near := _nearest_avatar() != null
	_prompt.visible = near and not sealed and _task_open()
	if _authoritative() and near and not sealed and _task_open() and Input.is_action_just_pressed("interact"):
		seal()


func _apply_visual() -> void:
	if sealed == _shown:
		return
	_shown = sealed
	if _label != null:
		_label.modulate = Color(0.6, 1.0, 0.6, 1) if sealed else Color(1.0, 0.5, 0.4, 1)
		_label.text = "Brecha sellada" if sealed else "¡Brecha del Arca! (E sellar)"


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
	cfg.add_property(".:sealed")
	sync.replication_config = cfg
