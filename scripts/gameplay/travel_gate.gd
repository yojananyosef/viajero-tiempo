extends Node3D
## Puerta de viaje entre mapas (Map_02→Map_01 y futuras). Solo solo/servidor
## cambian de escena; los clientes siguen al host en specs de viaje posteriores.

@export var target_scene: String = "res://scenes/maps/Map_01_Origen.tscn"
@export var target_map_id: String = "map_01"
@export var title: String = "Volver al Origen"


func _ready() -> void:
	$GateLabel.text = title
	$GateArea.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	if not body.is_in_group("player"):
		return
	var save := get_node_or_null("/root/Save")
	if save != null:
		(save.get("state") as Dictionary)["map"] = target_map_id
		save.save_game()
	get_tree().call_deferred("change_scene_to_file", target_scene)
