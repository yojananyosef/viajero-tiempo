extends StaticBody3D
## SPEC-004 — Columna de Luz / portal al cap 2. Dais Platformer Kit + 3 pilares
## de luz (haces emisivos) + joya-sello flotante. Sellado→abierto al bendecir;
## cruzar en done restaura la quest (chapter=2 + save). Solo solo/servidor.

var _quest: Node = null
var _jewel: Node3D = null
var _state_label: Label3D = null
var _beams: Array[MeshInstance3D] = []
var _open := false
var _t := 0.0

var _mat_dim: StandardMaterial3D = null
var _mat_lit: StandardMaterial3D = null


func _ready() -> void:
	_jewel = $Jewel
	_state_label = $StateLabel
	for b in $Beams.get_children():
		if b is MeshInstance3D:
			_beams.push_back(b)
	_mat_dim = _beam_material(Color(0.3, 0.45, 0.7), 0.4)
	_mat_lit = _beam_material(Color(1.0, 0.8, 0.35), 2.5)
	_quest = get_tree().get_first_node_in_group("quest_Q01")
	if _quest != null and _quest.has_signal("quest_changed"):
		_quest.quest_changed.connect(_on_quest_changed)
	_apply_visual()
	$SealArea.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_jewel):
		_jewel.rotation.y += delta * (2.5 if _open else 0.6)
		_jewel.position.y = 2.2 + sin(_t * 1.7) * 0.15


func activate() -> void:
	_open = true
	_apply_visual()


func _on_quest_changed(_state: StringName) -> void:
	_apply_visual()


func _apply_visual() -> void:
	var st := StringName("")
	if _quest != null:
		st = _quest.state
	_open = st == &"done" or st == &"restored"
	for b in _beams:
		b.material_override = _mat_lit if _open else _mat_dim
	if _state_label != null:
		_state_label.text = "Columna de Luz — ABIERTA" if _open else "Columna de Luz — sellada"


func _on_body_entered(body: Node3D) -> void:
	if not _authoritative():
		return
	if not body.is_in_group("player"):
		return
	if _quest != null and _quest.state == &"done":
		if _quest.restore():
			_state_label.text = "Capítulo 2 desbloqueado. Cruza para viajar al Edén."
	elif _quest != null and _quest.state == &"restored" and travel_scene != "":
		_travel()


## Viaje a otro mapa (solo / servidor; los clientes siguen al host en specs
## de viaje posteriores). Se difiere por venir de callback de física.
@export var travel_scene: String = ""


func _travel() -> void:
	var save := get_node_or_null("/root/Save")
	if save != null:
		(save.get("state") as Dictionary)["map"] = "map_02"
		save.save_game()
	get_tree().call_deferred("change_scene_to_file", travel_scene)


func _authoritative() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


func _beam_material(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, 0.55)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m
