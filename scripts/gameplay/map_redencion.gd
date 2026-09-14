extends Node3D
## SPEC-007 — Director de Map_04: HUD de senda + cinemática al 1/1
## (elegir senda) → restore → chapter=5 + save (sello 2).

var _quest: Node = null
var _banner: Label3D = null
var _progress: Label3D = null
var _class_label: Label3D = null
var _last_shown := ""
var _last_class := ""
var _cine_running := false


func _ready() -> void:
	var save := get_node_or_null("/root/Save")
	if save != null and save.has_method("notify_map_changed"):
		save.notify_map_changed("map_04")
	_banner = $Banner
	_progress = $ProgressLabel
	_class_label = $ClassLabel
	_banner.visible = false
	_quest = get_tree().get_first_node_in_group("quest_Q04")
	if _quest != null:
		if _quest.has_signal("quest_changed"):
			_quest.quest_changed.connect(_on_quest_changed)
		_update_progress()
	_update_class_hud()


func _process(_delta: float) -> void:
	_update_progress()
	_update_class_hud()


func _update_progress() -> void:
	if _quest == null or _progress == null:
		return
	var txt := "Plan de Redención: %d/%d" % [_quest.done_count, _quest.data.task_total]
	if txt != _last_shown:
		_last_shown = txt
		_progress.text = txt


func _update_class_hud() -> void:
	if _class_label == null:
		return
	var av := _nearest_local_avatar()
	var cid := str(av.get("class_id")) if av != null and av.get("class_id") != null else "llamado"
	var s1 := str(av.get("skill1_name")) if av != null else "-"
	var s2 := str(av.get("skill2_name")) if av != null else "-"
	var txt := "Senda: %s · F:%s · G:%s" % [cid, s1, s2]
	if txt != _last_class:
		_last_class = txt
		_class_label.text = txt


func _nearest_local_avatar() -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if p != null and p.has_method("is_local_avatar") and bool(p.call("is_local_avatar")):
			return p as Node3D
	return get_tree().get_first_node_in_group("player") as Node3D


func _on_quest_changed(state: StringName) -> void:
	if state == &"done" and not _cine_running:
		_cinematic()


func _cinematic() -> void:
	_cine_running = true
	for p in get_tree().get_nodes_in_group("player"):
		if p != null and p.has_method("is_local_avatar") and bool(p.call("is_local_avatar")):
			p.set("cutscene_lock", true)
	_banner.text = "¡Senda elegida! El plan de redención está en marcha."
	_banner.visible = true
	await get_tree().create_timer(5.0).timeout
	if _authoritative() and _quest != null:
		_quest.restore()
	for p in get_tree().get_nodes_in_group("player"):
		if p != null and p.has_method("is_local_avatar") and bool(p.call("is_local_avatar")):
			p.set("cutscene_lock", false)
	_banner.text = "Sello 2 recibido. Cap. 5 desbloqueado: Caín y Abel."
	await get_tree().create_timer(3.0).timeout
	_banner.visible = false


func _authoritative() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()
