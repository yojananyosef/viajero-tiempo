extends Node3D
## SPEC-004 — Eco dócil: reminiscencia del Vacío que vaga sin hostilidad.
## Sin muerte, sin colisión, sin red: su deriva es paramétrica (tiempo global)
## así que todos los peers la ven igual sin sincronizar nada.

@export var radius: float = 4.0
@export var height: float = 1.2

var _home := Vector3.ZERO
var _wisp: MeshInstance3D = null


func _ready() -> void:
	_home = global_position
	_wisp = $Wisp


func _process(_delta: float) -> void:
	# Reloj del motor (igual en todos los peers) → deriva determinista.
	var t := Time.get_ticks_msec() / 1000.0
	var p := _home
	p.x += sin(t * 0.31) * radius
	p.z += sin(t * 0.23 + 1.7) * radius
	p.y = 0.5 + height + sin(t * 1.3) * 0.25
	global_position = p
	if is_instance_valid(_wisp):
		_wisp.rotation.y += 0.02
