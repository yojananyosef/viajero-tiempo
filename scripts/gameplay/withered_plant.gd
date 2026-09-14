extends StaticBody3D
## SPEC-005 — Planta marchita por los secuaces. E cerca la riega (marrón→verde)
## y cuenta 1/8 en Q02. Solo servidor/solo aplican; `watered` se sincroniza.

@export var interact_radius: float = 3.0

var watered := false

var _quest: Node = null
var _sprout: Node3D = null
var _prompt_label: Label3D = null
var _mats: Array[StandardMaterial3D] = []
var _shown_watered := false


func _ready() -> void:
	add_to_group("q02_plants")
	_sprout = $Sprout
	_prompt_label = $PromptLabel
	_prompt_label.visible = false
	_quest = get_tree().get_first_node_in_group("quest_Q02")
	for mi in [_sprout, $Patch]:
		_tint_dry(mi as Node)
	_apply_visual()
	_setup_replication()


func _process(_delta: float) -> void:
	_apply_visual()
	var near := _nearest_avatar() != null
	_prompt_label.visible = near and not watered and _task_open()
	if _authoritative() and near and not watered and _task_open() and Input.is_action_just_pressed("interact"):
		watered = true
		if _quest != null:
			_quest.register_task()


func _apply_visual() -> void:
	if watered == _shown_watered:
		return
	_shown_watered = watered
	var c := Color(0.35, 0.7, 0.3) if watered else Color(0.45, 0.32, 0.18)
	for m in _mats:
		m.albedo_color = c
		m.emission_enabled = watered
		m.emission = c * 0.3 if watered else Color.BLACK
	if is_instance_valid(_sprout):
		_sprout.scale = Vector3.ONE * (1.2 if watered else 0.6)


func _tint_dry(n: Node) -> void:
	if n == null:
		return
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is MeshInstance3D:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.45, 0.32, 0.18)
			m.roughness = 0.9
			(c as MeshInstance3D).material_override = m
			_mats.push_back(m)
		for ch in c.get_children():
			stack.push_back(ch)


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
	cfg.add_property(".:watered")
	sync.replication_config = cfg
