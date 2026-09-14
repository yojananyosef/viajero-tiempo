# SPEC-005 — Q02 Cap 2 La creación (Edén, recolección)

Mapa: `Map_02_Creacion.tscn` (Terrain3D jardín + ríos). Quest `Q02.tres`.

## Lore
Anomalía: secuaces marchitan ríos y dispersan animales. Restaurar = nombrar/cuidar
(eco Génesis 2), no matar.

## Gameplay
- Interactor: `E` recoge/riega/suelta animal. Contador 0/8. Sin combate letal.
- Mobs: animales dóciles (FSM `Idle/Wander/Flee`), 1 secuaz saboteador que huye.
- Recompensa: cayado de pastor (arma base) + desbloqueo cap 3.

## Assets
- Nature/Mini Forest + animales Kenney + agua simple. Registrar licencias.

## Criterio OK
8/8 restaurado → cinemática corta → `chapter=3`, animal count sincronizado en red.
