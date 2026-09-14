# SPEC-004 — Q01 Cap 1 El origen del mal (tutorial + llamado)

Mapa: `scenes/maps/Map_01_Origen.tscn`. Quest: `data/quests/Q01.tres`.

## Lore (fijo)
Vacío previo al contador final. Dios llama al viajero. El enemigo ya activó su
máquina y envió secuaces. Voz-guía entrega el sello del restaurador.

## Gameplay
- FSM quest: `locked→available→active→done→restored`. Solo hablar + caminar + 1 eco dócil.
- NPC Guía (Enoc mayor, no el de cap 6): diálogo lineal + bendición (buff hub).
- Sin muerte. Al cerrar, se desbloquea cap 2. Autosave.

## Assets (Kenney CC0, registrar en CREDITS)
- Suelo atemporal + pilares luz (Platformer Kit), Guía con Mini Characters túnica clara.

## Criterio OK
Offline y en host: hablar → sello → portal a cap 2 se abre, save guarda `chapter=2`.
