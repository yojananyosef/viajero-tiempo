extends Node
## SPEC-003 — Transporte ENet autoritativo (autoload `Net`, `/root/Net` estable
## en todos los peers, cumpliendo "mismo NodePath en todos los peers").
## Contratos RPC (firmas idénticas cliente/servidor):
##   request_move(intent: Dictionary) — any_peer/reliable; el servidor valida y guarda.
##   snap_state(state: Dictionary) — authority/unreliable_ordered; snapshot del servidor.

signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal connected_to_server
signal server_disconnected

const DEFAULT_PORT: int = 27000
const MAX_CLIENTS: int = 20
const _NET_TIMEOUT: int = 2147483647

var peer: ENetMultiplayerPeer = null
var peer_intents: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func online() -> bool:
	# OJO: Godot 4 deja un OfflineMultiplayerPeer por defecto; solo hay red
	# real con un ENetMultiplayerPeer (u otro peer con red).
	var mp := multiplayer.multiplayer_peer
	return mp != null and not (mp is OfflineMultiplayerPeer)


func is_server() -> bool:
	return online() and multiplayer.is_server()


func host(port: int = DEFAULT_PORT, max_clients: int = MAX_CLIENTS) -> Error:
	_close()
	peer = ENetMultiplayerPeer.new()
	_harden(peer)
	var err := peer.create_server(port, max_clients)
	if err != OK:
		push_error("Net.host falló en puerto %d" % port)
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	_lobby().on_hosted()
	return OK


func join(ip: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	_close()
	peer = ENetMultiplayerPeer.new()
	_harden(peer)
	var err := peer.create_client(ip, port)
	if err != OK:
		push_error("Net.join falló hacia %s:%d" % [ip, port])
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	return OK  # Lobby.on_joined llega con connected_to_server.


func leave() -> void:
	_close()
	_lobby().on_left()


func send_intent(intent: Dictionary) -> void:
	if online() and not multiplayer.is_server():
		request_move.rpc_id(1, intent)


func get_intent(peer_id: int) -> Dictionary:
	return peer_intents.get(peer_id, {})


func broadcast_snapshot(snap: Dictionary) -> void:
	if is_server():
		snap_state.rpc(snap)


@rpc("any_peer", "call_local", "reliable")
func request_move(intent: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		return  # Llamada local del servidor: su avatar (id 1) usa Input directo.
	peer_intents[sender] = _sanitize_intent(intent)


@rpc("authority", "call_local", "unreliable_ordered")
func snap_state(state: Dictionary) -> void:
	if multiplayer.is_server():
		return
	_lobby().apply_snapshot(state)


func _sanitize_intent(intent: Dictionary) -> Dictionary:
	var d := Vector2.ZERO
	var raw = intent.get("dir", [0.0, 0.0])
	if raw is Array and (raw as Array).size() == 2:
		d = Vector2(float(raw[0]), float(raw[1]))
		if d.length() > 1.0:
			d = d.normalized()
	return {
		"dir": [d.x, d.y],
		"jump": bool(intent.get("jump", false)),
		"sprint": bool(intent.get("sprint", false)),
		"skill": bool(intent.get("skill", false)),
	}


func _harden(p: ENetMultiplayerPeer) -> void:
	# Anti-drop (nota CipSoft SPEC-003): timeouts máximos en ambos lados.
	# No se desactiva ni se duplica MultiplayerPoll (se usa el del SceneTree).
	if p != null and p.has_method("set_timeout"):
		p.set_timeout(_NET_TIMEOUT, _NET_TIMEOUT, _NET_TIMEOUT)


func _close() -> void:
	if peer != null:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = null
	peer_intents.clear()


func _lobby() -> Node:
	return get_node_or_null("/root/Lobby")


func _on_peer_connected(id: int) -> void:
	peer_connected.emit(id)
	_lobby().on_peer_connected(id)


func _on_peer_disconnected(id: int) -> void:
	peer_disconnected.emit(id)
	peer_intents.erase(id)
	_lobby().on_peer_disconnected(id)


func _on_connected_to_server() -> void:
	connected_to_server.emit()
	_lobby().on_joined()


func _on_server_disconnected() -> void:
	server_disconnected.emit()
	leave()  # Vuelve a modo solo recargando la escena.
