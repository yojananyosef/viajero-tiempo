extends CharacterBody3D
## SPEC-001 — Mover terrestre del Traveler (sin red, sin saves).
## Walk/run/jump con gravedad, coyote 0.1s y giro suavizado del visual.
## Movimiento relativo a la cámara (yaw del SpringArm3D hijo).

@export var walk_speed: float = 4.5
@export var run_speed: float = 7.0
@export var jump_velocity: float = 5.0
@export var acceleration: float = 30.0
@export var turn_speed: float = 12.0
@export var gravity_scale: float = 1.0

const COYOTE_TIME: float = 0.1

var _coyote: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

@onready var _visual: MeshInstance3D = $Visual
@onready var _rig: SpringArm3D = $CameraRig


func _physics_process(delta: float) -> void:
	var input_vec := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back")
	)
	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()

	# Dirección relativa al yaw de la cámara para que WASD siga al encuadre.
	var yaw: float = _rig.global_rotation.y if is_instance_valid(_rig) else global_rotation.y
	var dir: Vector3 = Basis(Vector3.UP, yaw) * Vector3(input_vec.x, 0.0, input_vec.y)

	# Gravedad + coyote.
	if is_on_floor():
		_coyote = COYOTE_TIME
	else:
		velocity.y -= _gravity * gravity_scale * delta
		_coyote -= delta

	if Input.is_action_just_pressed("jump") and (is_on_floor() or _coyote > 0.0):
		velocity.y = jump_velocity
		_coyote = 0.0

	var speed: float = run_speed if Input.is_action_pressed("sprint") else walk_speed
	var target := Vector3(dir.x * speed, velocity.y, dir.z * speed)
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	move_and_slide()

	# Gira solo el visual: el cuerpo no rota para no arrastrar la cámara hija.
	if dir.length() > 0.1 and is_instance_valid(_visual):
		var target_yaw := atan2(dir.x, dir.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, minf(1.0, turn_speed * delta))
