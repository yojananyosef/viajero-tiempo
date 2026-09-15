extends CharacterBody3D
## SPEC-009 — Enoc, escolta de Q06. Camina con Dios por un path con pausas de
## oración (eventos que el director usa para oleadas). Solo el servidor/solo lo
## mueve; el MultiplayerSynchronizer replica pos+estado.
## Si Enoc cae → checkpoint (último punto alcanzado), sin fail total.

signal prayer_started(idx: int)
signal arrived

@export var walk_speed: float = 2.5
@export var max_hp: int = 120
@export var escort_radius: float = 9.0
@export var pray_duration: float = 4.0
@export var pray_at: Array[int] = [1]

var hp: int = 120
var state: StringName = &"idle"
var waypoint_idx: int = 1
var checkpoint_idx: int = 0
var arrived_done := false
var pray_timer: float = 0.0

var _path: Array[Vector3] = []
var _quest: Node = null
var _label: Label3D = null
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func set_path(points: Array) -> void:
	_path.clear()
	for p in points:
		if p is Vector3:
			_path.push_back(p)
	if _path.size() < 2:
		return
	waypoint_idx = 1
	checkpoint_idx = 0
	global_position = _path[0] + Vector3(0, 0.5, 0)


func path_size() -> int:
	return _path.size()


func _ready() -> void:
	add_to_group("enoc")
	hp = max_hp
	_label = $NameLabel
	_quest = get_tree().get_first_node_in_group("quest_Q06")
	if _path.is_empty():
		var home := global_position
		_path = [home, home + Vector3(0, 0, -12), home + Vector3(0, 0, -24)]
		waypoint_idx = 1
		checkpoint_idx = 0
	_update_label()
	_setup_replication()


func take_damage(amount: int) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	if arrived_done:
		return
	if hp <= 0:
		return
	hp = maxi(0, hp - amount)
	if hp <= 0:
		_checkpoint_respawn()
	else:
		_update_label()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.5
	if not _authoritative():
		return
	if arrived_done:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		move_and_slide()
		return
	# Escolta: sin avatar cerca, Enoc espera (no avanza solo).
	var escort := _nearest_avatar(escort_radius) != null
	if not escort:
		state = &"idle"
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		move_and_slide()
		_update_label()
		return
	if waypoint_idx >= _path.size():
		_arrive()
		move_and_slide()
		return
	if pray_timer > 0.0:
		state = &"pray"
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		move_and_slide()
		pray_timer -= delta
		if pray_timer <= 0.0:
			checkpoint_idx = waypoint_idx
			waypoint_idx += 1
		_update_label()
		return
	var target: Vector3 = _path[waypoint_idx]
	var to := target - global_position
	to.y = 0.0
	if to.length() < 1.0:
		if waypoint_idx in pray_at:
			pray_timer = pray_duration
			state = &"pray"
			prayer_started.emit(waypoint_idx)
		else:
			checkpoint_idx = waypoint_idx
			waypoint_idx += 1
		_update_label()
		move_and_slide()
		return
	state = &"walk"
	var dir := to.normalized()
	velocity.x = move_toward(velocity.x, dir.x * walk_speed, 12.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * walk_speed, 12.0 * delta)
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, 8.0 * delta))
	move_and_slide()
	_update_label()


func _arrive() -> void:
	if arrived_done:
		return
	arrived_done = true
	state = &"arrived"
	_update_label()
	arrived.emit()
	if _authoritative() and _quest != null:
		_quest.register_task()


func _checkpoint_respawn() -> void:
	# Caída → checkpoint, sin fail total (SPEC-009).
	hp = max_hp
	pray_timer = 0.0
	state = &"idle"
	var idx := clampi(checkpoint_idx, 0, maxi(0, _path.size() - 1))
	waypoint_idx = maxi(idx + 1, 1) if _path.size() > 1 else 0
	if idx < _path.size():
		global_position = _path[idx] + Vector3(0, 0.5, 0)
	velocity = Vector3.ZERO
	_update_label()


func _update_label() -> void:
	if _label == null:
		return
	if arrived_done:
		_label.text = "Enoc llegó — el manto desciende"
	elif pray_timer > 0.0:
		_label.text = "Enoc ora… protégelo (checkpoint %d)" % checkpoint_idx
	elif state == &"idle":
		_label.text = "Enoc espera escolta — acércate (checkpoint %d)" % checkpoint_idx
	else:
		_label.text = "Enoc camina con Dios (%d/%d)" % [mini(waypoint_idx, _path.size()), _path.size()]


func _nearest_avatar(radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for p in get_tree().get_nodes_in_group("player"):
		var p3 := p as Node3D
		if p3 == null or (p3.has_method("is_down") and bool(p3.call("is_down"))):
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
	cfg.add_property(".:hp")
	cfg.add_property(".:state")
	cfg.add_property(".:waypoint_idx")
	sync.replication_config = cfg
