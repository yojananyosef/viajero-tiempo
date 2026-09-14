extends Node
## SPEC-004 — FSM de quest Q01: locked→available→active→done→restored.
## Solo avanza en solo o como servidor (los clientes la verán en su diario
## cuando exista UI; el estado canónico vive en el host). Nunca muta el .tres.

signal quest_changed(state: StringName)

@export var data: QuestData

var state: StringName = &"locked"
var line: int = -1


func _ready() -> void:
	add_to_group("q01")
	var save := get_node_or_null("/root/Save")
	var chapter := 1
	var flags := {}
	if save != null:
		chapter = int(save.state.get("chapter", 1))
		flags = save.state.get("flags", {})
	if data != null and (chapter >= data.unlock_chapter or bool(flags.get(data.seal_flag, false))):
		state = &"restored"
	else:
		state = &"available"


func start() -> bool:
	if state != &"available" or data == null:
		return false
	state = &"active"
	line = 0
	quest_changed.emit(state)
	return true


## Avanza el diálogo. Devuelve la línea a mostrar ("" si terminó).
func advance() -> String:
	if state != &"active" or data == null:
		return ""
	line += 1
	if line >= data.dialogue.size():
		_finish_dialogue()
		return ""
	quest_changed.emit(state)
	return data.dialogue[line]


func current_line() -> String:
	if state != &"active" or data == null:
		return ""
	if line < 0 or line >= data.dialogue.size():
		return ""
	return data.dialogue[line]


func restore() -> bool:
	if state != &"done" or data == null:
		return false
	state = &"restored"
	var save := get_node_or_null("/root/Save")
	if save != null:
		save.state["chapter"] = data.unlock_chapter
		save.save_game()
	quest_changed.emit(state)
	return true


func _finish_dialogue() -> void:
	state = &"done"
	var save := get_node_or_null("/root/Save")
	if save != null and data != null:
		(save.state.get("flags", {}) as Dictionary)[data.blessing_flag] = true
		(save.state.get("flags", {}) as Dictionary)[data.seal_flag] = true
	quest_changed.emit(state)
