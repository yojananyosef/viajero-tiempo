# ADR-001 — Arquitectura (decisión fija Expansión 1)

Fecha: 2026-09-14 · Estado: aceptado · Motor: Godot 4.7.2 + GDScript

## Decisión
Componentes Godot (nodos) + FSM + Observer (signals) + Object Pool + Command.
**Sin ECS.** Servidor autoritativo ENet, instancias 8-20p.

## Por qué (contexto: solo dev + IA, iGPU, red pequeña)
- Godot 4.7 no tiene ECS nativo; GDExtension ECS es inmaduro y rompe GDScript tooling.
- CipSoft 4.4.1: ENet default falla a 80-100 CCU; con 8-20p + validación servidor basta.
- Componentes pequeños = diffs pequeños = la IA no solapa ni borra.

## Reglas duras
1. `Core/` (autoloads) nunca importa `Gameplay/` ni `UI/`. `UI/` solo lee señales.
2. Modelo = `Resource` `.tres`. Vista = nodos/UI. Controlador = movers + RPC intent.
3. Prohibido renombrar nodos con `@rpc` (checksum). Prohibido mutar `.tres` sin `duplicate()`.
4. Saves: solo data + `version`, tmp+rename, `user://`. Nunca nodos.
5. Red: cliente manda `Intent`, servidor valida y broadcastea. Nada de daño/loot decidido en cliente.
6. Pool para proyectiles/mobs/drops. FSM para player/mob/quest/mount.

## Capas
- Core: GameState, Net, Save, Audio, SceneLoader, TimeLine (canon 1-10).
- Gameplay: maps 01-10, Traveler, TravelMount (travel-only), enemies, NPCs.
- UI: Login, HUD, QuestLog, MapSelect.

## Consecuencias
- Expansión 1 son datos (10 mapas/quests), no recódigo.
- Si el profiler pide DOD más tarde, se aísla en un System, no se reescribe todo.
