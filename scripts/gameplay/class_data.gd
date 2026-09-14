class_name ClassData
extends Resource
## SPEC-007 — Datos puros de senda (modelo .tres). Nunca se muta en runtime.

@export var class_id: String = "guardian"
@export var title: String = "Guardián"
@export var desc: String = "Espada/escudo, tanque."
@export var max_hp: int = 150
@export var walk_speed: float = 4.2
@export var run_speed: float = 6.5
@export var skill1_name: String = "Golpe de luz"
@export var skill1_damage: int = 20
@export var skill1_cooldown: float = 0.45
@export var skill2_name: String = "Escudo fiel"
@export var skill2_heal: int = 15
@export var skill2_cooldown: float = 8.0
@export var tint: Color = Color(0.5, 0.7, 1.0)
