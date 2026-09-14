# SPEC-013 — export (cliente + server headless)

## Objetivo
Builds reproducibles desde Godot 4.7.2.

## Presets (`exports/`)
- `Client Linux x86_64` + `Client Windows x86_64` (gráficos, audio, UI).
- `Server Linux headless` (`--headless -- --server port=7000 max=20 map=Map_01`).

## Pasos
1. Instalar export templates 4.7.2 en el editor (una vez).
2. `Project → Export` con los 3 presets. Probar: server headless + 2 clientes LAN.
3. No commitear builds, solo presets + notas en `exports/README.md`.

## Criterio OK
Server dedicado corre sin GPU, 2 clientes juegan Q01-Q03 completas sin desync duro.
