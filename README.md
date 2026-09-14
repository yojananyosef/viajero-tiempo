# Viajero del Tiempo — Restaurador del Canon

MMORPG bíblico por instancias (8-20 jugadores), Godot 4.7.2 + GDScript.

**Lore (único, no mezclar con FlyFF):** un viajero es llamado por Dios antes
del fin. El enemigo creó una máquina del tiempo y viaja con sus secuaces para
romper la línea real, evitando los grandes acontecimientos del canon bíblico.
Tu misión: mapa por mapa, misión por misión, restaurar cada anomalía para que
el relato ocurra tal cual debe ocurrir.

**Estilo:** FlyFF solo como guía visual (cute, colores brillantes, low-poly,
legible en iGPU). Nada de razas/clases/mapas de FlyFF.

## Expansión 1 (fija, sin saltos, en orden)
1. El origen del mal — hub atemporal + tutorial
2. La creación — Edén, recolección, sin muerte
3. La tentación y la caída — primera anomalía
4. El plan de redención — desbloqueo de sendas (Guardián/Escriba/Pastor)
5. Caín y Abel probados — ofrenda, mini-boss envidia
6. Set y Enoc — escolta, desbloqueo vuelo-travel (manto, solo transporte)
7. El diluvio — dungeon instanciada 8p, Arca
8. Después del diluvio — Ararat, reconstrucción
9. La semana literal — santuario de tiempo, puzzles 7 sellos
10. La torre de Babel — boss de torre, cierre expansión

## Arquitectura (ADR-001)
Componentes Godot + FSM + Observer (signals) + Pool + Command.
Sin ECS. Servidor autoritativo. Saves versionados `user://`.

## Estado
Workspace + specs. Sin gameplay aún. Ver `openspec/`.
Motor: Godot 4.7.2 Standard Linux. RAM recomendada 8GB.

## Reglas IA (anti-alucine)
- Un spec = un slice jugable, diffs pequeños.
- Prohibido renombrar nodos con RPC.
- Prohibido mutar `.tres` compartido sin `duplicate()`.
- UI solo lee, nunca decide daño/loot.
- Todo save lleva `version`, escritura tmp+rename.
