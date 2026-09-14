class_name QuestData
extends Resource
## SPEC-004 — Datos puros de quest (modelo .tres). Nunca se muta en runtime;
## el estado vivo lo lleva quest.gd. Ver ADR-001 regla 3.

@export var quest_id: String = "Q01"
@export var title: String = "El origen del mal"
@export var chapter: int = 1
@export var unlock_chapter: int = 2
@export var npc_name: String = "Enoc, el Mayor"
@export var dialogue: Array[String] = []
@export var seal_flag: String = "q01_sello"
@export var blessing_flag: String = "bendicion_guia"
