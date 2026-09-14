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

var anim_state: StringName = &"idle"
var cutscene_lock := false
var hp: int = 100

var _coyote: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _net: Node = null
var _save: Node = null
var _skill_cd: float = 0.0

@onready var _visual: MeshInstance3D = $Visual
@onready var _rig: SpringArm3D = $CameraRig
@onready var _staff: Node3D = $Staff


func _ready() -> void:
	_net = get_node_or_null("/root/Net")
	_save = get_node_or_null("/root/Save")
	hp = max_hp
	_setup_replication()


## SPEC-006 — Daño solo válido en solo/servidor. El cliente no se daña solo.
func take_damage(amount: int) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	if hp <= 0:
		return
	hp = maxi(0, hp - amount)
	if hp <= 0:
		_respawn()


func is_down() -> bool:
	return hp <= 0


func _respawn() -> void:
	# Muerte → entrada del mapa, sin pérdida salvo progreso de oleada.
	var sp := get_tree().current_scene.get_node_or_null("SpawnPoint") as Node3D
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
	if not online() or owner_peer_id() == 1:
		input_vec = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_forward", "move_back")
		)
		jump_pressed = Input.is_action_just_pressed("jump")
		sprinting = Input.is_action_pressed("sprint")
		skill_pressed = Input.is_action_just_pressed("skill")
	else:
		var intent: Dictionary = _net.get_intent(owner_peer_id()) if _net != null else {}
		var d = intent.get("dir", [0.0, 0.0])
		if d is Array and (d as Array).size() == 2:
			input_vec = Vector2(float(d[0]), float(d[1]))
		jump_pressed = bool(intent.get("jump", false))
		sprinting = bool(intent.get("sprint", false))
		skill_pressed = bool(intent.get("skill", false))
	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()
	if cutscene_lock:
		input_vec = Vector2.ZERO
		jump_pressed = false
		sprinting = false
		skill_pressed = false

	# Dirección relativa al yaw de la cámara para que WASD siga al encuadre.
	var yaw: float = _rig.global_rotation.y if is_instance_valid(_rig) else global_rotation.y
	var dir: Vector3 = Basis(Vector3.UP, yaw) * Vector3(input_vec.x, 0.0, input_vec.y)

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
	if skill_pressed:
		_try_skill()


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
	if cutscene_lock:
		iv = Vector2.ZERO
		jump = false
		sprint = false
		skill = false
	_net.send_intent({"dir": [iv.x, iv.y], "jump": jump, "sprint": sprint, "skill": skill})


## SPEC-006 — Ataque de luz: el servidor valida cooldown y dispara al frente.
## El daño lo decide el proyectil (constante del servidor), nunca el cliente.
func _try_skill() -> void:
	if _skill_cd > 0.0 or cutscene_lock:
		return
	_skill_cd = skill_cooldown
	var pool := get_tree().get_first_node_in_group("light_pool")
	if pool != null and pool.has_method("fire_forward"):
		pool.call("fire_forward", self)


func _update_anim_state(sprinting: bool) -> void:
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
	cfg.add_property("Visual:rotation")
	sync.replication_config = cfg
