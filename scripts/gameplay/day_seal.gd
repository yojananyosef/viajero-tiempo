extends StaticBody3D
## SPEC-011 — Sello del día de Q09 (semana literal). E lo enciende SOLO en
## orden (el servidor decide vía quest.try_ordered). Fuera de orden no
## penaliza: es semana de reposo, anti-burnout. `lit` se sincroniza.

@export var day_index: int = 1
@export var day_name: String = "Día 1 · Luz"
@export var interact_radius: float = 3.5

var lit := false

var _quest: Node = null
var _prompt: Label3D = null
var _label: Label3D = null
var _orb: MeshInstance3D = null
var _orb_mat: StandardMaterial3D = null
var _shown := false


func _ready() -> void:
	add_to_group("q09_seals")
	_prompt = $PromptLabel
	_label = $DayLabel
	_orb = $Orb
	_label.text = day_name
	_prompt.visible = false
	_orb_mat = StandardMaterial3D.new()
	_orb_mat.albedo_color = Color(0.4, 0.4, 0.45, 1)
	_orb_mat.roughness = 0.4
	_orb.material_override = _orb_mat
	_quest = get_tree().get_first_node_in_group("quest_Q09")
	_setup_replication()


func touch() -> bool:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return false
	if lit or _quest == null:
		return false
	if _quest.try_ordered(day_index):
		lit = true
		return true
	return false


func _process(_delta: float) -> void:
	_apply_visual()
	var near := _nearest_avatar() != null
	_prompt.visible = near and not lit and _task_open()
	if _prompt.visible and _quest != null and _quest.has_method("expected_order"):
		_prompt.text = "E · Sellar %s" % day_name if int(_quest.expected_order()) == day_index else "Toca el Día %d primero" % int(_quest.expected_order())
	if _authoritative() and near and not lit and _task_open() and Input.is_action_just_pressed("interact"):
		touch()


func _apply_visual() -> void:
	if lit == _shown:
		return
	_shown = lit
	if _orb_mat != null:
		_orb_mat.albedo_color = Color(1.0, 0.85, 0.4, 1) if lit else Color(0.4, 0.4, 0.45, 1)
		_orb_mat.emission_enabled = lit
		if lit:
			_orb_mat.emission = Color(1.0, 0.8, 0.3, 1)
			_orb_mat.emission_energy_multiplier = 1.5
	if _label != null:
		_label.modulate = Color(1.0, 0.9, 0.5, 1) if lit else Color(0.8, 0.8, 0.85, 1)


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
	cfg.add_property(".:lit")
	sync.replication_config = cfg
