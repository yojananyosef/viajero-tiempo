extends Node3D
## SPEC-011 — Director de Map_08 (Ararat, reconstrucción sin boss):
## altar + arcoíris + 2 tiendas (4/4) → cinemática → pacto + chapter=9.

var _quest: Node = null
var _banner: Label3D = null
var _progress: Label3D = null
var _last_shown := ""
var _cine_running := false


func _ready() -> void:
	var save := get_node_or_null("/root/Save")
	if save != null and save.has_method("notify_map_changed"):
		save.notify_map_changed("map_08")
	_banner = $Banner
	_progress = $ProgressLabel
	_banner.visible = false
	_quest = get_tree().get_first_node_in_group("quest_Q08")
	if _quest != null:
		if _quest.has_signal("quest_changed"):
			_quest.quest_changed.connect(_on_quest_changed)
		_update_progress()


func _process(_delta: float) -> void:
	_update_progress()


func _update_progress() -> void:
	if _quest == null or _progress == null:
		return
	var txt := "Reconstrucción del Ararat: %d/%d" % [_quest.done_count, _quest.data.task_total]
	if txt != _last_shown:
		_last_shown = txt
		_progress.text = txt


func _on_quest_changed(state: StringName) -> void:
	if state == &"done" and not _cine_running:
		_cinematic()


func _cinematic() -> void:
	_cine_running = true
	for p in get_tree().get_nodes_in_group("player"):
		if p != null and p.has_method("is_local_avatar") and bool(p.call("is_local_avatar")):
			p.set("cutscene_lock", true)
	_banner.text = "El arcoíris sella el pacto. La tierra vuelve a florecer."
	_banner.visible = true
	await get_tree().create_timer(5.0).timeout
	var save := get_node_or_null("/root/Save")
	if save != null:
		(save.get("state") as Dictionary).get("flags", {})["pacto_arcoiris"] = true
		save.save_game()
	if _authoritative() and _quest != null:
		_quest.restore()
	for p in get_tree().get_nodes_in_group("player"):
		if p != null and p.has_method("is_local_avatar") and bool(p.call("is_local_avatar")):
			p.set("cutscene_lock", false)
	_banner.text = "Pacto del arcoíris recibido. Cap. 9: la semana literal."
	await get_tree().create_timer(3.0).timeout
	_banner.visible = false


func _authoritative() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()
