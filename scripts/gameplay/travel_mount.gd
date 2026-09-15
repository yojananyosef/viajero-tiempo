extends StaticBody3D
## SPEC-009 — Pedestal de viento (montura). E cerca despega al jugador si tiene
## el manto (flag `manto_viento` que pone el director al restaurar Q06).
## El aterrizaje lo hace el avatar (E en aire). Solo solo/servidor aplican.

@export var interact_radius: float = 3.5

var _prompt: Label3D = null
var _label: Label3D = null


func _ready() -> void:
	add_to_group("travel_mount")
	_prompt = $PromptLabel
	_label = $MountLabel
	_label.text = "Montura de viento — corredor 12m (solo transporte)"
	_prompt.visible = false


func _process(_delta: float) -> void:
	var av := _nearest_grounded_avatar()
	var has := _has_manto()
	if av == null:
		_prompt.visible = false
		return
	var flying := bool(av.get("fly_mode")) if av.get("fly_mode") != null else false
	if not has:
		_prompt.text = "Se necesita el manto (completa la escolta)"
		_prompt.visible = true
		return
	if flying:
		_prompt.visible = false
		return
	_prompt.text = "E · Despegar (corredor 12m)"
	_prompt.visible = true
	if _authoritative() and Input.is_action_just_pressed("interact"):
		if av.has_method("takeoff"):
			av.call("takeoff")


func _has_manto() -> bool:
	var save := get_node_or_null("/root/Save")
	if save == null:
		return false
	return bool((save.get("state") as Dictionary).get("flags", {}).get("manto_viento", false))


func _nearest_grounded_avatar() -> Node3D:
	var best: Node3D = null
	var best_d := interact_radius
	for p in get_tree().get_nodes_in_group("player"):
		var p3 := p as Node3D
		if p3 == null:
			continue
		if p3.get("fly_mode") != null and bool(p3.get("fly_mode")):
			continue
		var d := global_position.distance_to(p3.global_position)
		if d < best_d:
			best_d = d
			best = p3
	return best


func _authoritative() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()
