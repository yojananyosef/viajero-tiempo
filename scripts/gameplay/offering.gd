extends StaticBody3D
## SPEC-008 — Ofrenda (trigo/cordero). E cerca la consagra y cuenta en Q05.
## Fase A contrarreloj suave: el mapa spawnea oleadas al consagrar.
## Solo servidor/solo aplican; `offered` se sincroniza.

@export var interact_radius: float = 3.5
@export var kind: String = "trigo"

var offered := false

var _quest: Node = null
var _prompt: Label3D = null
var _label: Label3D = null
var _shown := false


func _ready() -> void:
	add_to_group("q05_offerings")
	_prompt = $PromptLabel
	_label = $KindLabel
	_label.text = "Ofrenda de trigo (Caín)" if kind == "trigo" else "Ofrenda del cordero (Abel)"
	_prompt.visible = false
	_quest = get_tree().get_first_node_in_group("quest_Q05")
	_setup_replication()


func _process(_delta: float) -> void:
	_apply_visual()
	var near := _nearest_avatar() != null
	_prompt.visible = near and not offered and _task_open()
	if _authoritative() and near and not offered and _task_open() and Input.is_action_just_pressed("interact"):
		offered = true
		if _quest != null:
			_quest.register_task()


func _apply_visual() -> void:
	if offered == _shown:
		return
	_shown = offered
	if _label != null:
		_label.modulate = Color(0.7, 1.0, 0.7) if offered else Color(1.0, 0.9, 0.5)


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
	cfg.add_property(".:offered")
	sync.replication_config = cfg
