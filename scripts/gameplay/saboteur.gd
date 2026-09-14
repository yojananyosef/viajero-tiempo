extends CharacterBody3D
## SPEC-005 — Secuaz saboteador: marchita el Edén pero jamás pelea; siempre huye.
## Al completar Q02 es desterrado (banished se sincroniza; cada peer lo desvanece).

@export var walk_speed: float = 2.5
@export var flee_speed: float = 4.2
@export var flee_radius: float = 8.0

var state: StringName = &"idle"
var banished := false

var _wait := 0.0
var _target := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _gone := false


func _ready() -> void:
	add_to_group("saboteur")
	_target = global_position
	_darken($Model)
	_setup_replication()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.5
	if _authoritative():
		if banished:
			var away := global_position - Vector3.ZERO
			away.y = 0.0
			_run(away.normalized(), flee_speed + 2.0, delta)
			state = &"banished"
		else:
			_tick_brain(delta)
		move_and_slide()
	_apply_banish(delta)


func banish() -> void:
	banished = true


func _tick_brain(delta: float) -> void:
	var threat: Node3D = null
	var best_d := flee_radius
	for p in get_tree().get_nodes_in_group("player"):
		var p3 := p as Node3D
		if p3 == null:
			continue
		var d := global_position.distance_to(p3.global_position)
		if d < best_d:
			best_d = d
			threat = p3
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
			_target = Vector3(randf_range(-14.0, 14.0), 0.0, randf_range(-12.0, 12.0))
		else:
			state = &"idle"
			velocity.x = 0.0
			velocity.z = 0.0
		_wait = randf_range(3.0, 6.0)
	if state == &"wander":
		var to := _target - global_position
		to.y = 0.0
		if to.length() < 0.8:
			state = &"idle"
		else:
			_run(to.normalized(), walk_speed, delta)


func _run(dir: Vector3, speed: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, dir.x * speed, 12.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 12.0 * delta)
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, 8.0 * delta))


func _apply_banish(delta: float) -> void:
	if not banished or _gone:
		return
	# Todos los peers lo desvanecen a la vez; el servidor además lo libera.
	var s: float = maxf(0.01, scale.x - delta * 0.5)
	scale = Vector3.ONE * s
	if s <= 0.02:
		_gone = true
		visible = false
		set_physics_process(false)
		if _authoritative():
			queue_free()


func _darken(n: Node) -> void:
	if n == null:
		return
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is MeshInstance3D:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.12, 0.1, 0.16)
			m.emission_enabled = true
			m.emission = Color(0.5, 0.1, 0.1) * 0.4
			(c as MeshInstance3D).material_override = m
		for ch in c.get_children():
			stack.push_back(ch)


func _authoritative() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


func _setup_replication() -> void:
	var sync := get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync == null:
		return
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(".:position")
	cfg.add_property(".:rotation")
	cfg.add_property(".:banished")
	sync.replication_config = cfg
