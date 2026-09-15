extends StaticBody3D
## SPEC-011 — Mesa de trueque justo (economía base pre-tienda de Q08).
## E cerca entrega pan: cura 25 con cooldown de 20s. Solo servidor/solo
## aplican. No cuenta en la quest; es sustento, no proeza.

const HEAL: int = 25
const COOLDOWN: float = 20.0

@export var interact_radius: float = 3.5

var _cd := 0.0
var _prompt: Label3D = null


func _ready() -> void:
	add_to_group("barter")
	_prompt = $PromptLabel
	_prompt.visible = false


func give_bread() -> bool:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return false
	if _cd > 0.0:
		return false
	var av := _nearest_avatar()
	if av == null or not av.has_method("heal"):
		return false
	av.heal(HEAL)
	_cd = COOLDOWN
	return true


func _process(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)
	var near := _nearest_avatar() != null
	if not near:
		_prompt.visible = false
		return
	_prompt.visible = true
	_prompt.text = "Pan en %ds (trueque justo)" % int(_cd) if _cd > 0.0 else "E · Pan (trueque justo)"
	if _authoritative() and _cd <= 0.0 and Input.is_action_just_pressed("interact"):
		give_bread()


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


func _authoritative() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()
