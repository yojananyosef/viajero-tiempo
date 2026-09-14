extends StaticBody3D
## SPEC-006 — Sello susurrante: anomalía que miente ("el árbol es prisión").
## E cerca lo sella (luz disipa el eco) y cuenta 1/4 en Q03. Solo servidor/solo.

@export var interact_radius: float = 3.5
@export var whisper_text: String = "El árbol es tu prisión… libérate."

var sealed := false

var _quest: Node = null
var _prompt: Label3D = null
var _lore: Label3D = null
var _shown := false
var _t := 0.0
var _crystal: MeshInstance3D = null


func _ready() -> void:
	add_to_group("q03_seals")
	_prompt = $PromptLabel
	_lore = $LoreLabel
	_crystal = $Crystal
	_lore.text = "«" + whisper_text + "»"
	_prompt.visible = false
	_quest = get_tree().get_first_node_in_group("quest_Q03")
	_setup_replication()


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_crystal) and not sealed:
		_crystal.rotation.y += delta * 1.2
		_crystal.position.y = 1.4 + sin(_t * 2.0) * 0.12
	_apply_visual()
	var near := _nearest_avatar() != null
	_prompt.visible = near and not sealed and _task_open()
	if _authoritative() and near and not sealed and _task_open() and Input.is_action_just_pressed("interact"):
		sealed = true
		if _quest != null:
			_quest.register_task()


func _apply_visual() -> void:
	if sealed == _shown:
		return
	_shown = sealed
	if _lore != null:
		_lore.text = "SELLADO — el relato sigue tal cual." if sealed else "«" + whisper_text + "»"
		_lore.modulate = Color(0.7, 1.0, 0.7) if sealed else Color(1.0, 0.6, 0.8)
	if _crystal != null:
		var m := StandardMaterial3D.new()
		if sealed:
			m.albedo_color = Color(0.6, 0.9, 1.0)
			m.emission_enabled = true
			m.emission = Color(0.5, 0.85, 1.0)
			m.emission_energy_multiplier = 1.2
		else:
			m.albedo_color = Color(0.35, 0.15, 0.45)
			m.emission_enabled = true
			m.emission = Color(0.6, 0.2, 0.8)
			m.emission_energy_multiplier = 0.9
		_crystal.material_override = m


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
