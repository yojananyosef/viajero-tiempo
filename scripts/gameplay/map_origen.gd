extends Node3D
## SPEC-002 — Hook mínimo del mapa: avisa al autoload Save del mapa activo
## para que corra el autosave (throttle 60s dentro de Save).
func _ready() -> void:
	var save := get_node_or_null("/root/Save")
	if save != null and save.has_method("notify_map_changed"):
		save.notify_map_changed("map_01")
