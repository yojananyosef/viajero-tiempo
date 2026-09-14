# SPEC-003 — net-lobby (multijugador mínimo autoritativo)

## Objetivo
Host/join ENet, 2+ clientes ven al otro moverse. Servidor decide.

## Archivos
- `scripts/core/net.gd` + `scripts/net/lobby.gd`: `host(port,max=20)`, `join(ip,port)`, `leave()`
- `scenes/player/Traveler.tscn` += `MultiplayerSynchronizer` (sync `position, velocity, anim_state`)
- `scripts/net/spawner.gd` (MultiplayerSpawner, spawn nombres deterministas = peer_id)

## Contratos RPC (firmas idénticas cliente/servidor)
- `@rpc("any_peer","call_local","reliable") request_move(intent: Dictionary)` → servidor valida → aplica.
- `@rpc("authority","call_local","unreliable_ordered") snap_state(state: Dictionary)`.
- Nodos con RPC mantienen `NodePath` igual en todos los peers.
- Señales: `peer_connected(id)`, `peer_disconnected(id)`, `connected_to_server`, `server_disconnected`.

## Reglas anti-drop (solo si >50 peers o drops, CipSoft)
- `peer.set_timeout(INT_MAX,INT_MAX,INT_MAX)` ambos lados, desactivar `MultiplayerPoll` doble.
- No pasar a TCP custom en este spec.

## Criterio OK
Server headless local + 2 clientes: se ven, se mueven, al cerrar uno el otro sigue.
