# SPEC-009 — Q06 Cap 6 Set y Enoc (escolta + vuelo-travel)

Mapa: `Map_06_Enoc.tscn` (ciudad fiel vs ciudad impía). Quest `Q06.tres`.

## Lore
Linaje fiel vs corrupción. Escoltar a Enoc que camina con Dios. Al final,
Dios concede el **manto de viento**: vuelo SOLO transporte entre mapas ya
restaurados (caps 1-6). Sin combate aéreo.

## Gameplay
- Escolta NPC con path + pausas de oración (eventos). Si Enoc cae → checkpoint, no fail total.
- Montura `TravelMount.tscn`: `fly_mode bool`, corredores designados, despegue/aterrizaje sincronizados, en aire invulnerable y sin skills.
- Red: solo RPC `takeoff/land`, movimiento aire `unreliable_ordered`, colisión simple.

## Criterio OK
Enoc llega → manto desbloqueado → volar Map_01↔Map_06 sin combates aire → `chapter=7`.
