# SPEC-002 — save-v1 (persistencia versionada)

## Objetivo
Guardar/cargar posición, senda, quest flags, capítulo desbloqueado.

## Archivos
- `scripts/core/save.gd` (autoload futuro): `capture_state() -> Dictionary`, `save_atomic(path, data)`, `load_migrated(path)`
- `user://save_0.json` + `user://autosave.json` (autosave en cambio de mapa, throttle 60s)
- `SAVE_VERSION = 1`

## Contrato
- Schema: `{version:1, player:{hp,pos,class}, flags:{}, chapter:int, seed:int}`.
- Solo data pura (ids, no nodos). Escritura tmp+rename. Backup `.bak`.
- Load: version → migrar → validar → reconstruir. Si parse falla, usar backup.

## Criterio OK
Guardar → cerrar Godot → abrir → cargar → misma posición/capítulo.
