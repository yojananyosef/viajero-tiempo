extends Node3D
## SPEC-006 — Pool de proyectiles de luz (Object Pool, ADR-001).
## Solo existe/actúa en solo o servidor. El cliente nunca dispara ni daña.

const POOL_SIZE: int = 32
const PROJECTILE_SCRIPT: Script = preload("res://scripts/gameplay/light_projectile.gd")


func _ready() -> void:
	add_to_group("light_pool")
	for i in POOL_SIZE:
		var p := PROJECTILE_SCRIPT.new() as Area3D
		p.name = "Bolt%d" % i
		add_child(p)
		p.deactivate()


func fire_from(shooter: Node3D, target_pos: Vector3) -> bool:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return false
	var origin := shooter.global_position + Vector3(0, 1.2, 0)
	var to := target_pos - origin
	to.y = 0.0
	if to.length() < 0.5 or to.length() > 28.0:
		return false
	for p in get_children():
		if p != null and p.get("active") == false:
			p.fire(origin, to.normalized())
			return true
	return false


func fire_forward(shooter: Node3D) -> bool:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return false
	var origin := shooter.global_position + Vector3(0, 1.2, 0)
	var fwd := -shooter.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.1:
		fwd = Vector3(0, 0, -1)
	for p in get_children():
		if p != null and p.get("active") == false:
			p.fire(origin, fwd.normalized())
			return true
	return false
