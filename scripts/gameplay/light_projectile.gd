extends Area3D
## SPEC-006 — Proyectil de luz (pool). Solo el servidor lo mueve y decide daño.
## SPEC-007 — Daño por senda (parámetro del servidor): el cliente nunca lo dicta.

const DAMAGE: int = 25
const SPEED: float = 22.0
const LIFE: float = 2.0
const RANGE: float = 30.0

var active := false
var dir := Vector3.FORWARD
var _life := 0.0
var _from := Vector3.ZERO
var _damage: int = DAMAGE

var _mesh: MeshInstance3D = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 8  # Enemigos en layer 4? hitbox en 8: ver Whisper/Tempter.
	monitoring = true
	monitorable = false
	visible = false
	set_physics_process(false)
	if _mesh == null:
		var sphere := SphereMesh.new()
		sphere.radius = 0.18
		sphere.height = 0.36
		_mesh = MeshInstance3D.new()
		_mesh.mesh = sphere
		var m := StandardMaterial3D.new()
		m.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.9, 0.5, 1.0)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.8, 0.3)
		m.emission_energy_multiplier = 2.0
		_mesh.material_override = m
		add_child(_mesh)
		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.25
		col.shape = shape
		add_child(col)
	body_entered.connect(_on_body_entered)


func fire(origin: Vector3, direction: Vector3, damage: int = DAMAGE) -> void:
	_from = origin
	global_position = origin
	dir = direction.normalized()
	_damage = damage
	_life = LIFE
	active = true
	visible = true
	set_physics_process(true)


func deactivate() -> void:
	active = false
	visible = false
	set_physics_process(false)
	global_position = Vector3(0, -50, 0)


func _physics_process(delta: float) -> void:
	if not active:
		return
	# Solo el servidor mueve (los clientes ni instancian el pool).
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	_life -= delta
	global_position += dir * SPEED * delta
	if _life <= 0.0 or global_position.distance_to(_from) > RANGE:
		deactivate()


func _on_body_entered(body: Node3D) -> void:
	if not active:
		return
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	if body != null and body.has_method("take_damage"):
		body.take_damage(_damage)
		deactivate()
