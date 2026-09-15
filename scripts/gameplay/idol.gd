extends StaticBody3D
## SPEC-012 — Ídolo del ombligo de Q10 (cima de Babel). E lo rompe SOLO tras
## la caída de Nimrod (quest done>=4); romperlo cuenta 5/5. Solo servidor/solo
## aplican; `broken` se sincroniza. Sin ídolo roto no hay dispersión.

@export var interact_radius: float = 3.5

var broken := false

var _quest: Node = null
var _prompt: Label3D = null
var _label: Label3D = null
var _obelisk: MeshInstance3D = null
var _shown := false


func _ready() -> void:
	add_to_group("q10_idol")
	_prompt = $PromptLabel
	_label = $IdolLabel
	_obelisk = $Obelisk
	_prompt.visible = false
	_quest = get_tree().get_first_node_in_group("quest_Q10")
	_setup_replication()


func break_idol() -> bool:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return false
	if broken or not _breakable():
		return false
	broken = true
	if _quest != null:
		_quest.register_task()  # 5/5: ídolo roto.
	return true


func _process(_delta: float) -> void:
	_apply_visual()
	var near := _nearest_avatar() != null
	_prompt.visible = near and not broken and _task_open()
	if _prompt.visible:
		_prompt.text = "E · Romper el ídolo" if _breakable() else "El Heraldo lo protege… (derriba a Nimrod)"
	if _authoritative() and near and not broken and _breakable() and Input.is_action_just_pressed("interact"):
		break_idol()


func _breakable() -> bool:
	return _task_open() and _quest != null and int(_quest.done_count) >= 4


func _task_open() -> bool:
	return _quest != null and (_quest.state == &"available" or _quest.state == &"active")


func _apply_visual() -> void:
	if broken == _shown:
		return
	_shown = broken
	if _label != null:
		_label.text = "Ídolo roto — la confusión se acerca" if broken else "Ídolo del ombligo"
		_label.modulate = Color(0.7, 1.0, 0.7, 1) if broken else Color(1.0, 0.45, 0.35, 1)
	if _obelisk != null:
		var m := StandardMaterial3D.new()
		if broken:
			m.albedo_color = Color(0.45, 0.42, 0.4, 1)
			m.roughness = 0.95
		else:
			m.albedo_color = Color(0.25, 0.1, 0.2, 1)
			m.emission_enabled = true
			m.emission = Color(0.8, 0.2, 0.4, 1)
			m.emission_energy_multiplier = 0.9
		_obelisk.material_override = m


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
	cfg.add_property(".:broken")
	sync.replication_config = cfg
