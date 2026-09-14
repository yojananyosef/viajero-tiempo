extends CharacterBody3D
## SPEC-008 — Envidia (rango propio `ruptura`): mini-boss de Q05 que incita a
## Caín antes de tiempo. Duerme hasta ofrenda 2/3; enrage <30% (x1.5 vel, x2 daño).
## Al caer suelta drops (pool) y cuenta 3/3 en Q05. Sin PvP.

@export var max_hp: int = 150
@export var chase_speed: float = 3.0
@export var attack_radius: float = 2.6
@export var attack_damage: int = 12
@export var attack_cooldown: float = 1.7

var hp: int = 150
var state: StringName = &"dormant"
var dead := false
var awakened := false
var enraged := false

var _atk_cd := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _quest: Node = null
var _label: Label3D = null
var _body_mat: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("envy")
	hp = max_hp
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.4, 0.1, 0.35)
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(0.7, 0.15, 0.5) * 0.5
	$Model/Body.material_override = _body_mat
	$Model/Head.material_override = _body_mat
	_label = $NameLabel
	_quest = get_tree().get_first_node_in_group("quest_Q05")
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
	if hp <= maxi(1, int(max_hp * 0.3)) and not enraged:
		enraged = true
		_body_mat.emission = Color(1.0, 0.1, 0.1)
		_body_mat.emission_energy_multiplier = 1.5
		_update_label()
	if hp <= 0:
		_die()


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
	var mult := 1.5 if enraged else 1.0
	var prey := _nearest_avatar(22.0)
	if prey == null:
		state = &"patrol"
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		return
	var d := global_position.distance_to(prey.global_position)
	if d <= attack_radius:
		state = &"attack"
		_face(prey.global_position, delta)
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		if _atk_cd <= 0.0:
			_atk_cd = attack_cooldown / mult
			if prey.has_method("take_damage"):
				prey.take_damage(int(attack_damage * (2.0 if enraged else 1.0)))
	else:
		state = &"chase" if not enraged else &"enraged"
		var to := prey.global_position - global_position
		to.y = 0.0
		velocity.x = move_toward(velocity.x, to.normalized().x * chase_speed * mult, 12.0 * delta)
		velocity.z = move_toward(velocity.z, to.normalized().z * chase_speed * mult, 12.0 * delta)
		_face(prey.global_position, delta)


func _die() -> void:
	dead = true
	state = &"despawn"
	# Drops por pool, loot solo servidor (SPEC-008 criterio).
	var pool := get_tree().get_first_node_in_group("drop_pool")
	if pool != null and pool.has_method("spawn"):
		pool.call("spawn", global_position + Vector3(1, 0.5, 0))
		pool.call("spawn", global_position + Vector3(-1, 0.5, 0))
	if _authoritative() and _quest != null:
		_quest.register_task()  # 3/3: boss caído.
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.8)
	tw.tween_callback(queue_free)


func _on_quest_changed(_s: StringName) -> void:
	_try_awaken()


func _on_quest_progress(_done: int, _total: int) -> void:
	_try_awaken()


func _try_awaken() -> void:
	if not awakened and _quest != null and _quest.done_count >= 2:
		awaken()


func _update_label() -> void:
	if _label == null:
		return
	if not awakened:
		_label.text = "Envidia dormida… completa la ofrenda (0/2)"
	elif enraged:
		_label.text = "¡ENVIDIA ENFURECIDA (ruptura)!"
	else:
		_label.text = "Envidia (ruptura)"


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
	cfg.add_property(".:awakened")
	cfg.add_property(".:enraged")
	sync.replication_config = cfg
