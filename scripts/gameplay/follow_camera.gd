extends SpringArm3D
## SPEC-001 — Cámara follow en 3ª persona (SpringArm3D + Camera3D).
## Sigue al Traveler (es hija suya) con órbita suavizada por lerp.
## Clic captura el ratón para orbitar; Esc lo libera. Sin captura usa el
## encuadre fijo, así que el juego es jugable solo con teclado.

@export var target_yaw: float = 0.0
@export var target_pitch_deg: float = -18.0
@export var smooth: float = 10.0
@export var mouse_sensitivity: float = 0.0035
@export var min_pitch_deg: float = -60.0
@export var max_pitch_deg: float = 20.0

@onready var _cam: Camera3D = $Camera3D


func _ready() -> void:
	rotation = Vector3(deg_to_rad(target_pitch_deg), target_yaw, 0.0)
	if is_instance_valid(_cam):
		_cam.current = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		target_yaw -= mm.relative.x * mouse_sensitivity
		target_pitch_deg = clampf(
			target_pitch_deg - mm.relative.y * mouse_sensitivity * 57.2958,
			min_pitch_deg, max_pitch_deg
		)
	if event.is_action_pressed("ui_cancel") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	var want := Vector3(deg_to_rad(target_pitch_deg), target_yaw, 0.0)
	# Lerp por componentes (pitch/yaw); el roll siempre 0.
	var t: float = minf(1.0, smooth * delta)
	rotation.x = lerp_angle(rotation.x, want.x, t)
	rotation.y = lerp_angle(rotation.y, want.y, t)
	rotation.z = 0.0
