extends Node3D
## SPEC-008 — Pool de drops de luz (Object Pool, ADR-001). Corazones que curan 25.
## Loot solo servidor: solo solo/servidor spawnean y aplican la cura.

const POOL_SIZE: int = 16
const HEAL: int = 25

var _drops: Array[Area3D] = []


func _ready() -> void:
	add_to_group("drop_pool")
	for i in POOL_SIZE:
		var d := Area3D.new()
		d.name = "Drop%d" % i
		d.collision_layer = 0
		d.collision_mask = 2  # Avatares en layer 2.
		d.monitoring = true
		d.monitorable = false
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.22
		sphere.height = 0.44
		mesh.mesh = sphere
		var m := StandardMaterial3D.new()
		m.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.5, 1.0, 0.6)
		m.emission_enabled = true
		m.emission = Color(0.3, 1.0, 0.4)
		m.emission_energy_multiplier = 1.5
		mesh.material_override = m
		d.add_child(mesh)
		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.4
		col.shape = shape
		d.add_child(col)
		d.set_meta("active", false)
		d.visible = false
		d.body_entered.connect(_on_body.bind(d))
		add_child(d)
		_drops.push_back(d)


func spawn(pos: Vector3) -> bool:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return false
	for d in _drops:
		if not bool(d.get_meta("active")):
			d.set_meta("active", true)
			d.global_position = pos
			d.visible = true
			return true
	return false


func active_count() -> int:
	var n := 0
	for d in _drops:
		if bool(d.get_meta("active")):
			n += 1
	return n


func _on_body(body: Node3D, d: Area3D) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	if not bool(d.get_meta("active")):
		return
	if body != null and body.is_in_group("player") and body.has_method("heal"):
		body.heal(HEAL)
		d.set_meta("active", false)
		d.visible = false
		d.global_position = Vector3(0, -50, 0)
