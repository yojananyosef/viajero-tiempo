extends CharacterBody3D
## SPEC-001 mover + SPEC-003 red (servidor autoritativo).
## Solo (sin peer): input local directo.
## Online: solo el SERVIDOR mueve los avatares. Cada cliente manda su intent
## con request_move; el servidor lo valida y replica el estado resultante.
## `anim_state` (idle/walk/run/jump) se sincroniza para la futura animación.

@export var walk_speed: float = 4.5
@export var run_speed: float = 7.0
@export var jump_velocity: float = 5.0
@export var acceleration: float = 30.0
@export var turn_speed: float = 12.0
@export var gravity_scale: float = 1.0
@export var max_hp: int = 100
@export var skill_cooldown: float = 0.45
@export var skill_range: float = 28.0

const COYOTE_TIME: float = 0.1
## SPEC-009 — Vuelo-travel (manto de viento): solo transporte, sin combate
## aéreo. Corredor designado a 12m, colisión simple (clamp del mapa).
const FLY_ALTITUDE: float = 12.0
const FLY_SPEED: float = 9.0
const FLY_HALF: float = 30.0
const CLASS_PATHS: Dictionary = {
	"guardian": "res://data/classes/guardian.tres",
	"escriba": "res://data/classes/escriba.tres",
	"pastor": "res://data/classes/pastor.tres",
}

var anim_state: StringName = &"idle"
var cutscene_lock := false
var hp: int = 100
var fly_mode := false
var class_id: String = "llamado"
var skill1_damage: int = 25
var skill1_name: String = "Luz"
var skill2_name: String = "—"
var skill2_heal: int = 0
var skill2_cooldown: float = 8.0

var _coyote: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _net: Node = null
var _save: Node = null
var _skill_cd: float = 0.0
var _skill2_cd: float = 0.0

@onready var _visual: Node3D = $Visual
@onready var _rig: SpringArm3D = $CameraRig
@onready var _staff: Node3D = $Staff


func _ready() -> void:
	_net = get_node_or_null("/root/Net")
	_save = get_node_or_null("/root/Save")
	hp = max_hp
	_setup_replication()
	# SPEC-007: restaura la senda persistida (save → avatar).
	if _save != null:
		var cid := str((_save.get("state") as Dictionary).get("player", {}).get("class", "llamado"))
		if cid in CLASS_PATHS:
			_apply_class_stats(cid)


## SPEC-007 — Cambio de senda (solo solo/servidor). Cambia stats/skills/HUD,
## persiste en save y se sincroniza vía `class_id` replicado.
func apply_class(cid: String) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	if not (cid in CLASS_PATHS):
		return
	_apply_class_stats(cid)
	if _save != null:
		((_save.get("state") as Dictionary).get("player", {}) as Dictionary)["class"] = cid
		_save.save_game()


func _apply_class_stats(cid: String) -> void:
	var data := load(CLASS_PATHS[cid]) as Resource
	if data == null:
		return
	class_id = cid
	max_hp = int(data.get("max_hp"))
	walk_speed = float(data.get("walk_speed"))
	run_speed = float(data.get("run_speed"))
	skill1_damage = int(data.get("skill1_damage"))
	skill1_name = str(data.get("skill1_name"))
	skill2_name = str(data.get("skill2_name"))
	skill2_heal = int(data.get("skill2_heal"))
	skill2_cooldown = float(data.get("skill2_cooldown"))
	skill_cooldown = float(data.get("skill1_cooldown"))
	hp = max_hp
	_tint_visual(data.get("tint"))


func _tint_visual(c) -> void:
	# SPEC-A1: Visual es contenedor Node3D con modelo Kenney dentro.
	# El tinte de senda se aplica a los MeshInstance3D descendientes.
	if not is_instance_valid(_visual):
		return
	var col: Color = c if c is Color else Color(0.98, 0.78, 0.42)
	if _visual is MeshInstance3D:
		var m0 := StandardMaterial3D.new()
		m0.albedo_color = col
		m0.roughness = 0.6
		m0.emission_enabled = true
		m0.emission = Color(0.45, 0.32, 0.12)
		(_visual as MeshInstance3D).material_override = m0
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.6
	m.emission_enabled = true
	m.emission = Color(0.45, 0.32, 0.12)
	for ch in _visual.find_children("*", "MeshInstance3D", true, false):
		(ch as MeshInstance3D).material_override = m


## SPEC-006 — Daño solo válido en solo/servidor. El cliente no se daña solo.
## SPEC-009 — En aire invulnerable (transporte, sin combates aire).
func take_damage(amount: int) -> void:
	if fly_mode:
		return
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	if hp <= 0:
		return
	hp = maxi(0, hp - amount)
	if hp <= 0:
		_respawn()


## SPEC-009 — Manto de viento: despegue/aterrizaje sincronizados.
## Solo solo/servidor aplican; `fly_mode` se replica. Sin manto no hay vuelo.
func has_manto() -> bool:
	if _save == null:
		return false
	return bool((_save.get("state") as Dictionary).get("flags", {}).get("manto_viento", false))


func takeoff() -> bool:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return false
	if fly_mode or not has_manto():
		return false
	fly_mode = true
	global_position.y = FLY_ALTITUDE
	velocity = Vector3.ZERO
	return true


func land() -> bool:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return false
	if not fly_mode:
		return false
	fly_mode = false
	velocity.y = 0.0
	return true


## Red: solo RPC takeoff/land (confiables); el movimiento en aire viaja por
## el MultiplayerSynchronizer (no fiable ordenado). Viaje solo/host.
@rpc("any_peer", "call_local", "reliable")
func takeoff_rpc() -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		takeoff()


@rpc("any_peer", "call_local", "reliable")
func land_rpc() -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		land()


func is_down() -> bool:
	return hp <= 0


## SPEC-008 — Cura por drops (solo solo/servidor aplican).
func heal(amount: int) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	if hp <= 0:
		return
	hp = mini(max_hp, hp + amount)


func _respawn() -> void:
	# Muerte → entrada del mapa, sin pérdida salvo progreso de oleada.
	var sp: Node3D = null
	var scene := get_tree().current_scene
	if scene != null:
		sp = scene.get_node_or_null("SpawnPoint") as Node3D
	if sp == null:
		sp = get_tree().get_first_node_in_group("spawn_point") as Node3D
	if sp == null and get_parent() != null:
		sp = get_parent().get_node_or_null("SpawnPoint") as Node3D
	if sp != null:
		global_position = sp.global_position
	velocity = Vector3.ZERO
	hp = max_hp


func online() -> bool:
	# Fuente canónica: Net.online() (excluye el OfflineMultiplayerPeer).
	if _net != null and _net.has_method("online"):
		return bool(_net.call("online"))
	var mp := multiplayer.multiplayer_peer
	return mp != null and not (mp is OfflineMultiplayerPeer)


## Peer dueño del avatar (nombre determinista = peer_id en red, 0 en solo).
func owner_peer_id() -> int:
	return int(name) if String(name).is_valid_int() else 0


## ¿Es este el avatar del jugador local? (el único con cámara e input).
func is_local_avatar() -> bool:
	if not online():
		return true
	if multiplayer.is_server():
		return owner_peer_id() == 1
	return owner_peer_id() == multiplayer.get_unique_id()


func _physics_process(delta: float) -> void:
	if online() and not multiplayer.is_server():
		_client_tick()
		return
	var input_vec := Vector2.ZERO
	var jump_pressed := false
	var sprinting := false
	var skill_pressed := false
	var skill2_pressed := false
	if not online() or owner_peer_id() == 1:
		input_vec = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_forward", "move_back")
		)
		jump_pressed = Input.is_action_just_pressed("jump")
		sprinting = Input.is_action_pressed("sprint")
		skill_pressed = Input.is_action_just_pressed("skill")
		skill2_pressed = Input.is_action_just_pressed("skill2")
	else:
		var intent: Dictionary = _net.get_intent(owner_peer_id()) if _net != null else {}
		var d = intent.get("dir", [0.0, 0.0])
		if d is Array and (d as Array).size() == 2:
			input_vec = Vector2(float(d[0]), float(d[1]))
		jump_pressed = bool(intent.get("jump", false))
		sprinting = bool(intent.get("sprint", false))
		skill_pressed = bool(intent.get("skill", false))
		skill2_pressed = bool(intent.get("skill2", false))
	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()
	if cutscene_lock:
		input_vec = Vector2.ZERO
		jump_pressed = false
		sprinting = false
		skill_pressed = false
		skill2_pressed = false

	# Dirección relativa al yaw de la cámara para que WASD siga al encuadre.
	var yaw: float = _rig.global_rotation.y if is_instance_valid(_rig) else global_rotation.y
	var dir: Vector3 = Basis(Vector3.UP, yaw) * Vector3(input_vec.x, 0.0, input_vec.y)

	# SPEC-009 — En aire: corredor a FLY_ALTITUDE, sin gravedad ni skills.
	# E en aire aterriza (solo/host).
	if fly_mode:
		if not online() or owner_peer_id() == 1:
			if Input.is_action_just_pressed("interact"):
				land()
				return
		_tick_fly(delta, dir, sprinting)
		return

	# Gravedad + coyote.
	if is_on_floor():
		_coyote = COYOTE_TIME
	else:
		velocity.y -= _gravity * gravity_scale * delta
		_coyote -= delta

	if jump_pressed and (is_on_floor() or _coyote > 0.0):
		velocity.y = jump_velocity
		_coyote = 0.0

	var speed: float = run_speed if sprinting else walk_speed
	# SPEC-004: bendición del Guía (buff del hub, +15% velocidad).
	if _save != null:
		var st: Dictionary = _save.get("state") as Dictionary
		if st != null and bool((st.get("flags", {}) as Dictionary).get("bendicion_guia", false)):
			speed *= 1.15
	var target := Vector3(dir.x * speed, velocity.y, dir.z * speed)
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	move_and_slide()

	# Gira solo el visual: el cuerpo no rota para no arrastrar la cámara hija.
	if dir.length() > 0.1 and is_instance_valid(_visual):
		var target_yaw := atan2(dir.x, dir.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, minf(1.0, turn_speed * delta))
	_update_anim_state(sprinting)
	_update_staff()
	_skill_cd -= delta
	_skill2_cd -= delta
	if skill_pressed:
		_try_skill()
	if skill2_pressed:
		_try_skill2()


## SPEC-005: el cayado aparece al recibirlo (flag local; cada peer lo muestra).
func _update_staff() -> void:
	if not is_instance_valid(_staff) or _save == null:
		return
	_staff.visible = bool((_save.get("state") as Dictionary).get("flags", {}).get("cayado_pastor", false))


func _client_tick() -> void:
	# En clientes, el avatar propio solo captura y envía intent; el servidor
	# mueve y el synchronizer devuelve el estado. Los avatares ajenos esperan.
	if _net == null or not is_local_avatar():
		return
	var iv := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_forward", "move_back"))
	var jump := Input.is_action_just_pressed("jump")
	var sprint := Input.is_action_pressed("sprint")
	var skill := Input.is_action_just_pressed("skill")
	var skill2 := Input.is_action_just_pressed("skill2")
	if cutscene_lock:
		iv = Vector2.ZERO
		jump = false
		sprint = false
		skill = false
		skill2 = false
	_net.send_intent({"dir": [iv.x, iv.y], "jump": jump, "sprint": sprint, "skill": skill, "skill2": skill2})


## SPEC-006 — Ataque de luz: el servidor valida cooldown y dispara al frente.
## El daño lo decide el servidor (daño de senda), nunca el cliente.
## SPEC-009 — En aire sin skills (solo transporte).
func _try_skill() -> void:
	if fly_mode:
		return
	if _skill_cd > 0.0 or cutscene_lock:
		return
	_skill_cd = skill_cooldown
	var pool := get_tree().get_first_node_in_group("light_pool")
	if pool != null and pool.has_method("fire_forward"):
		pool.call("fire_forward", self, skill1_damage)


## SPEC-007 — Segunda skill: cura (Pastor/Guardián) o juicio potente (Escriba).
## Solo el servidor aplica; cooldown por senda.
## SPEC-009 — En aire sin skills.
func _try_skill2() -> void:
	if fly_mode:
		return
	if _skill2_cd > 0.0 or cutscene_lock:
		return
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	_skill2_cd = skill2_cooldown
	if skill2_heal > 0:
		hp = mini(max_hp, hp + skill2_heal)
	else:
		var pool := get_tree().get_first_node_in_group("light_pool")
		if pool != null and pool.has_method("fire_forward"):
			pool.call("fire_forward", self, skill1_damage * 2)


func _update_anim_state(sprinting: bool) -> void:
	if fly_mode:
		anim_state = &"fly"
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor():
		anim_state = &"jump"
	elif planar > 0.5:
		anim_state = &"run" if sprinting else &"walk"
	else:
		anim_state = &"idle"


func _setup_replication() -> void:
	var sync := get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync == null:
		return
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(".:position")
	cfg.add_property(".:velocity")
	cfg.add_property(".:anim_state")
	cfg.add_property(".:hp")
	cfg.add_property(".:class_id")
	cfg.add_property(".:fly_mode")
	cfg.add_property("Visual:rotation")
	sync.replication_config = cfg


## SPEC-009 — Tick de vuelo: corredor fijo a FLY_ALTITUDE, colisión simple
## (clamp ±FLY_HALF). Movimiento en aire no fiable ordenado vía synchronizer.
func _tick_fly(delta: float, dir: Vector3, sprinting: bool) -> void:
	var speed: float = FLY_SPEED * (1.4 if sprinting else 1.0)
	velocity.x = move_toward(velocity.x, dir.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, acceleration * delta)
	velocity.y = clampf((FLY_ALTITUDE - global_position.y) * 4.0, -4.0, 4.0)
	move_and_slide()
	global_position.x = clampf(global_position.x, -FLY_HALF, FLY_HALF)
	global_position.z = clampf(global_position.z, -FLY_HALF, FLY_HALF)
	if dir.length() > 0.1 and is_instance_valid(_visual):
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(dir.x, dir.z), minf(1.0, turn_speed * delta))
	_update_anim_state(sprinting)
	_skill_cd -= delta
	_skill2_cd -= delta
