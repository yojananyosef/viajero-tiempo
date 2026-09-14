extends CharacterBody3D
## SPEC-005 — Animal dócil del Edén. FSM Idle/Wander/Flee, sin combate.
## E cerca lo calma (revela su nombre, eco Génesis 2) y cuenta 1/8 en Q02.
## Solo el servidor/solo lo mueve; synchronizer replica pos+estado.

@export var display_name: String = "Oveja"
@export var tint: Color = Color(0.95, 0.93, 0.88)
@export var wander_radius: float = 8.0
@export var walk_speed: float = 2.0
@export var flee_speed: float = 3.5
@export var flee_radius: float = 6.0
@export var calm_radius: float = 4.0

var state: StringName = &"idle"
var calmed := false

var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _wait := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _body: MeshInstance3D = null
var _name_label: Label3D = null
var _prompt_label: Label3D = null
var _quest: Node = null
var _mat: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("q02_animals")
	_home = global_position
	_target = _home
	_body = $Body
	_name_label = $NameLabel
	_prompt_label = $PromptLabel
	_quest = get_tree().get_first_node_in_group("quest_Q02")
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = tint
	_mat.roughness = 0.8
	_body.material_override = _mat
	_name_label.text = "¿?"
	_prompt_label.visible = false
	_setup_replication()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.5
	if _authoritative():
		_tick_brain(delta)
		move_and_slide()
	_apply_visual()


func _process(_delta: float) -> void:
	# Prompt local (cada peer lo calcula; el avance real solo en servidor).
	var near := _nearest_avatar(calm_radius) != null
	_prompt_label.visible = near and not calmed and _task_open()
	if _authoritative() and near and not calmed and _task_open() and Input.is_action_just_pressed("interact"):
		_calm()


func _tick_brain(delta: float) -> void:
	if calmed:
		state = &"calmed"
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		return
	var threat := _nearest_avatar(flee_radius)
	if threat != null:
		state = &"flee"
		var away := global_position - threat.global_position
		away.y = 0.0
		_run(away.normalized(), flee_speed, delta)
		return
	_wait -= delta
	if _wait <= 0.0:
		if state == &"idle":
			state = &"wander"
			_target = _home + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * wander_radius
		else:
			state = &"idle"
			velocity.x = 0.0
			velocity.z = 0.0
		_wait = randf_range(2.5, 5.5)
	if state == &"wander":
		var to := _target - global_position
		to.y = 0.0
		if to.length() < 0.6:
			state = &"idle"
			_wait = randf_range(2.0, 4.0)
		else:
			_run(to.normalized(), walk_speed, delta)


func _run(dir: Vector3, speed: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, dir.x * speed, 12.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 12.0 * delta)
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, 8.0 * delta))


func _calm() -> void:
	calmed = true
	state = &"calmed"
	if _quest != null:
		_quest.register_task()


func _apply_visual() -> void:
	if calmed and _name_label.text != display_name:
		_name_label.text = display_name
		_mat.emission_enabled = true
		_mat.emission = tint * 0.35


func _task_open() -> bool:
	return _quest != null and (_quest.state == &"available" or _quest.state == &"active")


func _nearest_avatar(radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
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
	cfg.add_property(".:position")
	cfg.add_property(".:rotation")
	cfg.add_property(".:state")
	cfg.add_property(".:calmed")
	sync.replication_config = cfg
