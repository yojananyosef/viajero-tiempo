extends CharacterBody3D
## SPEC-006 — Tentador (rango propio `ruptura`): boss de Q03. Duerme hasta que
## los 3 susurros se sellan; al caer cuenta el 4/4 en Q03. FSM + respawn no.

@export var max_hp: int = 100
@export var chase_speed: float = 3.2
@export var attack_radius: float = 2.6
@export var attack_damage: int = 15
@export var attack_cooldown: float = 1.8

var hp: int = 100
var state: StringName = &"dormant"
var dead := false
var awakened := false

var _atk_cd := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _quest: Node = null
var _label: Label3D = null


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("tempter")
	hp = max_hp
	_darken($Model)
	_label = $NameLabel
	_quest = get_tree().get_first_node_in_group("quest_Q03")
	if _quest != null:
		if _quest.has_signal("quest_changed"):
			_quest.quest_changed.connect(_on_quest_changed)
		if _quest.has_signal("progress_changed"):
			_quest.progress_changed.connect(_on_quest_progress)
		_try_awaken()
	_update_sleep_visual()
	_setup_replication()


func awaken() -> void:
	if dead or awakened:
		return
	awakened = true
	state = &"patrol"
	_update_sleep_visual()


func take_damage(amount: int) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	if dead or not awakened:
		return
	hp = maxi(0, hp - amount)
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
	var prey := _nearest_avatar(20.0)
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
	if _authoritative() and _quest != null:
		_quest.register_task()  # 4/4: tentador caído.
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.8)
	tw.tween_callback(queue_free)


func _on_quest_changed(_s: StringName) -> void:
	_try_awaken()


func _on_quest_progress(_done: int, _total: int) -> void:
	# register_task emite progress_changed por sello (quest_changed solo en
	# transiciones); sin esto el tentador jamás despertaba a los 3 sellos.
	_try_awaken()


func _try_awaken() -> void:
	# Despierta al sellar los 3 susurros (done_count >= 3).
	if not awakened and _quest != null and _quest.done_count >= 3:
		awaken()


func _update_sleep_visual() -> void:
	if _label != null:
		_label.text = "Tentador (ruptura)" if awakened else "Tentador dormido… sella 3 susurros"


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


func _darken(n: Node) -> void:
	if n == null:
		return
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is MeshInstance3D:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.35, 0.08, 0.1)
			m.emission_enabled = true
			m.emission = Color(0.9, 0.15, 0.1) * 0.6
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
	sync.replication_config = cfg
