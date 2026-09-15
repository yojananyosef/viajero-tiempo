extends CharacterBody3D
## SPEC-010 — Heraldo del Abismo (rango propio `ruptura`): boss de Q07 que
## intenta hundir el Arca. Duerme hasta sellar 3 brechas; al caer cuenta 4/4.
## No se libera al morir (la instancia puede reiniciarse por wipe).

@export var max_hp: int = 120
@export var chase_speed: float = 3.4
@export var attack_radius: float = 2.6
@export var attack_damage: int = 14
@export var attack_cooldown: float = 1.8

var hp: int = 120
var state: StringName = &"dormant"
var dead := false
var awakened := false

var _atk_cd := 0.0
var _home := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _quest: Node = null
var _label: Label3D = null


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("herald")
	hp = max_hp
	_home = global_position
	_darken($Model)
	_label = $NameLabel
	_quest = get_tree().get_first_node_in_group("quest_Q07")
	if _quest != null:
		if _quest.has_signal("quest_changed"):
			_quest.quest_changed.connect(_on_quest_changed)
		if _quest.has_signal("progress_changed"):
			_quest.progress_changed.connect(_on_quest_progress)
		_try_awaken()
	_update_label()
	_setup_replication()


func awaken() -> void:
	if dead or awakened:
		return
	awakened = true
	state = &"patrol"
	_update_label()


func take_damage(amount: int) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	if dead or not awakened:
		return
	hp = maxi(0, hp - amount)
	if hp <= 0:
		_die()


func reset_boss() -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	hp = max_hp
	dead = false
	awakened = false
	state = &"dormant"
	_atk_cd = 0.0
	global_position = _home
	velocity = Vector3.ZERO
	visible = true
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col != null:
		col.set_deferred("disabled", false)
	_try_awaken()
	_update_label()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.5
	if _authoritative() and awakened and not dead:
		_atk_cd -= delta
		_tick_brain(delta)
		move_and_slide()


func _tick_brain(delta: float) -> void:
	var prey := _nearest_avatar(24.0)
	if prey == null:
		state = &"patrol"
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
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
		var to := prey.global_position - global_position
		to.y = 0.0
		velocity.x = move_toward(velocity.x, to.normalized().x * chase_speed, 12.0 * delta)
		velocity.z = move_toward(velocity.z, to.normalized().z * chase_speed, 12.0 * delta)
		_face(prey.global_position, delta)


func _die() -> void:
	dead = true
	state = &"despawn"
	var pool := get_tree().get_first_node_in_group("drop_pool")
	if pool != null and pool.has_method("spawn"):
		pool.call("spawn", global_position + Vector3(1, 0.5, 0))
		pool.call("spawn", global_position + Vector3(-1, 0.5, 0))
	if _authoritative() and _quest != null:
		_quest.register_task()  # 4/4: heraldo caído.
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col != null:
		col.set_deferred("disabled", true)
	visible = false
	_update_label()


func _on_quest_changed(_s: StringName) -> void:
	_try_awaken()


func _on_quest_progress(_done: int, _total: int) -> void:
	_try_awaken()


func _try_awaken() -> void:
	if not awakened and not dead and _quest != null and _quest.done_count >= 3:
		awaken()


func _update_label() -> void:
	if _label == null:
		return
	if dead:
		_label.text = "Heraldo hundido"
	elif not awakened:
		_label.text = "Heraldo dormido… sella 3 brechas"
	else:
		_label.text = "Heraldo del Abismo (ruptura)"


func _face(p: Vector3, delta: float) -> void:
	var to := p - global_position
	to.y = 0.0
	if to.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, 10.0 * delta))


func _nearest_avatar(radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for p in get_tree().get_nodes_in_group("player"):
		var p3 := p as Node3D
		if p3 == null or (p3.has_method("is_down") and bool(p3.call("is_down"))):
			continue
		# En vuelo no hay combate aéreo: el Heraldo ignora avatares volando.
		if p3.get("fly_mode") != null and bool(p3.get("fly_mode")):
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
			m.albedo_color = Color(0.1, 0.2, 0.35, 1)
			m.emission_enabled = true
			m.emission = Color(0.2, 0.5, 1.0, 1) * 0.6
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
	cfg.add_property(".:awakened")
	cfg.add_property(".:dead")
	sync.replication_config = cfg
