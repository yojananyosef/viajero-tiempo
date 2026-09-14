extends StaticBody3D
## SPEC-004 — NPC Guía (Enoc, el Mayor). Diálogo lineal con E + bendición.
## Modelo Kenney Mini Characters (túnica clara). Solo solo/servidor avanzan.

@export var interact_radius: float = 3.5

var _quest: Node = null
var _dialogue_label: Label3D = null
var _prompt_label: Label3D = null
var _near_avatar: Node3D = null


func _ready() -> void:
	_dialogue_label = $DialogueLabel
	_prompt_label = $PromptLabel
	_dialogue_label.visible = false
	_prompt_label.visible = false
	_quest = get_tree().get_first_node_in_group("q01")
	if _quest != null and _quest.has_signal("quest_changed"):
		_quest.quest_changed.connect(_on_quest_changed)
	_refresh_labels()


func _process(_delta: float) -> void:
	_near_avatar = _nearest_avatar()
	_face_near()
	if not _authoritative():
		_prompt_label.visible = false
		return
	_prompt_label.visible = _near_avatar != null and _can_talk()
	if _near_avatar != null and _can_talk() and Input.is_action_just_pressed("interact"):
		_talk()


func _talk() -> void:
	if _quest == null:
		return
	if _quest.state == &"available":
		if _quest.start():
			_dialogue_label.text = _quest.current_line()
			_dialogue_label.visible = true
	elif _quest.state == &"active":
		var line: String = _quest.advance()
		if line.is_empty():
			_dialogue_label.text = "El sello arde en tu mano. Cruza la Columna de Luz."
		else:
			_dialogue_label.text = line


func _can_talk() -> bool:
	return _quest != null and (_quest.state == &"available" or _quest.state == &"active")


func _on_quest_changed(_state: StringName) -> void:
	_refresh_labels()


func _refresh_labels() -> void:
	if _quest == null:
		return
	if _quest.state == &"done":
		_dialogue_label.text = "El sello arde en tu mano. Cruza la Columna de Luz."
		_dialogue_label.visible = true
	elif _quest.state == &"restored":
		_dialogue_label.text = "El camino al Edén se abrirá."
		_dialogue_label.visible = true


func _nearest_avatar() -> Node3D:
	var best: Node3D = null
	var best_d := interact_radius
	for p in get_tree().get_nodes_in_group("player"):
		var p3 := p as Node3D
		if p3 == null:
			continue
		var d := global_position.distance_to(p3.global_position)
		if d < best_d:
			best_d = d
			best = p3
	return best


func _face_near() -> void:
	if _near_avatar == null:
		return
	var to := _near_avatar.global_position - global_position
	to.y = 0.0
	if to.length() > 0.2:
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 0.1)


func _authoritative() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()
