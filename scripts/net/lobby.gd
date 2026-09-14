extends Node
## SPEC-003 — Roster y spawn de avatares (autoload `Lobby`).
## El servidor spawnea un avatar por peer con nombre determinista = peer_id
## (vía spawner.gd); el MultiplayerSpawner lo replica a los clientes.
## Al entrar en red se retira el Traveler solo; al salir se recarga la escena.

signal roster_changed(roster: Array[int])

const SNAPSHOT_INTERVAL: float = 5.0

var roster: Array[int] = []
var _spawner: MultiplayerSpawner = null
var _snap_timer: float = 0.0


func on_hosted() -> void:
	call_deferred("_host_setup")


func on_joined() -> void:
	call_deferred("_net_enter")


func on_left() -> void:
	roster.clear()
	_spawner = null
	_snap_timer = 0.0
	get_tree().call_deferred("reload_current_scene")


func on_peer_connected(id: int) -> void:
	if _net().is_server():
		_spawn_avatar(id)
		call_deferred("_broadcast_snapshot")


func on_peer_disconnected(id: int) -> void:
	if _net().is_server():
		var av := _players().get_node_or_null(str(id))
		if av != null:
			av.queue_free()  # El spawner replica el despawn a los clientes.
		_track_remove(id)  # En el servidor no se emite despawned local.


func apply_snapshot(snap: Dictionary) -> void:
	var players := _players()
	if players == null:
		return
	for k in snap.keys():
		var av := players.get_node_or_null(str(k)) as CharacterBody3D
		var pos = snap[k]
		if av != null and pos is Array and (pos as Array).size() == 3:
			av.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
			av.velocity = Vector3.ZERO


func _process(delta: float) -> void:
	if not _net().is_server():
		return
	_snap_timer += delta
	if _snap_timer >= SNAPSHOT_INTERVAL:
		_snap_timer = 0.0
		_broadcast_snapshot()


func _host_setup() -> void:
	_net_enter()
	_spawn_avatar(1)


func _net_enter() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		push_error("Lobby sin escena activa.")
		return
	var solo := scene.get_node_or_null("Traveler")
	if solo != null:
		solo.queue_free()
	_hook_spawner(scene)


func _hook_spawner(scene: Node) -> void:
	_spawner = scene.get_node_or_null("Net/Spawner") as MultiplayerSpawner
	if _spawner == null:
		push_error("Lobby sin spawner en Net/Spawner.")
		return
	if not _spawner.spawned.is_connected(_on_spawned):
		_spawner.spawned.connect(_on_spawned)
	if not _spawner.despawned.is_connected(_on_despawned):
		_spawner.despawned.connect(_on_despawned)


func _spawn_avatar(id: int) -> void:
	if not _net().is_server() or _spawner == null:
		return
	if _players().has_node(str(id)):
		return
	var av: Node = _spawner.spawn_avatar(id)
	_track_add(id)  # En el servidor no se emite spawned local.
	if av == null:
		_track_remove(id)


func _broadcast_snapshot() -> void:
	if not _net().is_server():
		return
	_net().broadcast_snapshot(_build_snapshot())


func _build_snapshot() -> Dictionary:
	var snap := {}
	var players := _players()
	if players == null:
		return snap
	for child in players.get_children():
		if String(child.name).is_valid_int():
			var p := child as Node3D
			snap[str(child.name)] = [p.global_position.x, p.global_position.y, p.global_position.z]
	return snap


func _players() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Players")


func _on_spawned(node: Node) -> void:
	_track_add(int(str(node.name)) if String(node.name).is_valid_int() else 0)


func _on_despawned(node: Node) -> void:
	_track_remove(int(str(node.name)) if String(node.name).is_valid_int() else 0)


func _track_add(id: int) -> void:
	if id != 0 and not roster.has(id):
		roster.push_back(id)
		roster_changed.emit(roster)


func _track_remove(id: int) -> void:
	if roster.has(id):
		roster.erase(id)
		roster_changed.emit(roster)


func _net() -> Node:
	return get_node("/root/Net")
