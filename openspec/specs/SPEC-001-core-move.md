# SPEC-001 — core-move (base jugable día 1)

## Objetivo
Traveler en 3ª persona se mueve en Map_01, cámara follow, sin red aún.

## Alcance (solo estos archivos)
- `scenes/player/Traveler.tscn` (CharacterBody3D + CollisionShape cápsula + Mesh placeholder + Mover)
- `scripts/gameplay/mover.gd` (tierra: walk/run/jump, `velocity`, `move_and_slide`, coyote 0.1s)
- `scripts/gameplay/follow_camera.gd` (SpringArm3D + Camera3D, lerp)
- `scenes/maps/Map_01_Origen.tscn` (ya existe: sol + suelo; añadir spawn point)

## Contratos
- Señales: ninguna aún (solo movimiento).
- Inputs: `move_*`, `jump`, `sprint` (InputMap proyecto).
- Prohibido: tocar red, saves, `.tres`.

## Criterio OK
Play → WASD mueve, espacio salta, cámara sigue, 60fps en iGPU sombras bajas.
