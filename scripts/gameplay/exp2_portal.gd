extends StaticBody3D
## SPEC-012 — Portal a Expansión 2 (cima de Babel). Sellado: muestra el teaser
## pero no viaja (fuera de alcance). Solo efecto/adorno tras el cierre.

@export var interact_radius: float = 3.5

var _prompt: Label3D = null


func _ready() -> void:
	add_to_group("exp2_portal")
	_prompt = $PromptLabel
	_prompt.visible = false


func touch() -> bool:
	# Sellado hasta la próxima expansión: nunca viaja.
	return false


func _process(_delta: float) -> void:
	var near := _nearest_avatar() != null
	_prompt.visible = near
	if _prompt.visible:
		_prompt.text = "El portal duerme (Expansión 2 · Éxodo — fuera de alcance)"


func _nearest_avatar() -> Node3D:
	var best: Node3D = null
	var best_d := interact_radius
	for p in get_tree().get_nodes_in_group("player"):
		var p3 := p as Node3D
		if p3 == null:
			continue
		var d := global_position.distance_to(p3.global_position)
		if d < best_d:
			best_d = d
			best = p3
	return best
