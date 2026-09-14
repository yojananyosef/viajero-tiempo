extends MultiplayerSpawner
## SPEC-003 — Spawner con nombres deterministas = peer_id.
## Solo el servidor spawnea; el spawner replica escena+nombre a los clientes.
## spawn_path y spawnable_scenes se fijan por código para no depender del .tscn.

const AVATAR_PATH: String = "res://scenes/player/Traveler.tscn"
const AVATAR: PackedScene = preload(AVATAR_PATH)


func _ready() -> void:
	# Spawner vive en Net/Spawner: dos niveles hasta Players.
	spawn_path = NodePath("../../Players")
	add_spawnable_scene(AVATAR_PATH)


func spawn_avatar(peer_id: int) -> Node:
	var av := AVATAR.instantiate()
	av.name = str(peer_id)
	av.set_multiplayer_authority(1)  # Autoritativo servidor: solo él mueve.
	get_node(spawn_path).add_child(av)
	return av
