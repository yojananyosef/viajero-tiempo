extends CharacterBody3D
## SPEC-006 — Susurro (rango propio `eco`): anomalía menor que susurra la
## versión torcida ("el árbol es prisión"). FSM Patrol/Chase/Attack/Despawn.
## HP 50 (2 rayos). Daño al jugador solo decidido por el servidor.

@export var max_hp: int = 50
@export var walk_speed: float = 2.2
@export var chase_speed: float = 3.6
@export var aggro_radius: float = 12.0
@export var attack_radius: float = 2.2
@export var attack_damage: int = 8
@export var attack_cooldown: float = 1.6

var hp: int = 50
var state: StringName = &"patrol"
var dead := false

var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _wait := 0.0
var _atk_cd := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _quest: Node = null


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("whispers")
	hp = max_hp
	_home = global_position
	_target = _home
	_darken($Model)
	_quest = get_tree().get_first_node_in_group("quest_Q03")
	_setup_replication()


func take_damage(amount: int) -> void:
	# Autoritativo: solo solo/servidor aplican. El cliente no puede matar de 1 hit.
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	if dead:
		return
	hp = maxi(0, hp - amount)
	if hp <= 0:
		_die()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.5
	if _authoritative():
		_atk_cd -= delta
		_tick_brain(delta)
		move_and_slide()


func _tick_brain(delta: float) -> void:
	if dead:
		return
	var prey := _nearest_avatar(aggro_radius)
	if prey == null:
		state = &"patrol"
		_wait -= delta
		if _wait <= 0.0:
			_target = _home + Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0))
			_wait = randf_range(3.0, 6.0)
		_move_to(_target, walk_speed, delta)
		return
	var d := global_position.distance_to(prey.global_position)
	if d <= attack_radius:
		state = &"attack"
		_face(prey.global_position, delta)
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		if _atk_cd <= 0.0:
			_atk_cd = attack_cooldown
			if prey.has_method("take_damage"):
				prey.take_damage(attack_damage)
	else:
		state = &"chase"
		_move_to(prey.global_position, chase_speed, delta)


func _move_to(p: Vector3, speed: float, delta: float) -> void:
	var to := p - global_position
	to.y = 0.0
	if to.length() < 0.8:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		return
	_run(to.normalized(), speed, delta)


func _run(dir: Vector3, speed: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, dir.x * speed, 12.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 12.0 * delta)
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, 8.0 * delta))


func _face(p: Vector3, delta: float) -> void:
	var to := p - global_position
	to.y = 0.0
	if to.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, 10.0 * delta))


func _die() -> void:
	dead = true
	state = &"despawn"
	# Los susurros no cuentan en Q03 (solo presionan); se desvanecen.
	_shrink()


func _shrink() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.6)
	tw.tween_callback(queue_free)


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


func _darken(n: Node) -> void:
	if n == null:
		return
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is MeshInstance3D:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.2, 0.12, 0.3)
			m.emission_enabled = true
			m.emission = Color(0.5, 0.2, 0.7) * 0.5
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
	cfg.add_property(".:hp")
	cfg.add_property(".:state")
	sync.replication_config = cfg
