# SPEC-006 — Q03 Cap 3 La tentación y la caída (primera anomalía + combate)

Mapa: `Map_03_Caida.tscn`. Quest `Q03.tres`.

## Lore
Secuaces susurran una versión torcida (árbol prohibido = prisión). Restaurar =
sellar 3 susurros y resistir al tentador, el relato debe ocurrir tal cual.

## Gameplay (servidor autoritativo)
- Pool de proyectiles luz. Command `Intent{skill}` → server valida cooldown/distancia → daño.
- Enemigos: `susurro (eco) → tentador (ruptura)` FSM Patrol/Chase/Attack/Despawn.
- Rangos propios (no FlyFF): `eco / anomalía / ruptura / heraldo`.
- Muerte player → respawn en entrada mapa, sin pérdida salvo progreso oleada.

## Criterio OK
3 sellos + tentador caído → `chapter=4`. Daño solo decidido por servidor (test: cliente hackeado no mata de 1 hit).
