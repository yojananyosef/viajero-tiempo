extends Node3D
## SPEC-009 — Director de Map_06: escolta de Enoc (path + oleadas en oración)
## y manto de viento. Al 1/1 → cinemática → flag manto + restore → chapter=7.
## Viaje (solo/host): a pie a Map_05, en vuelo a Map_01.

const WHISPER_SCENE: PackedScene = preload("res://scenes/enemies/Whisper.tscn")

var _quest: Node = null
var _enoc: Node3D = null
var _banner: Label3D = null
var _progress: Label3D = null
var _manto: Label3D = null
var _last_shown := ""
var _last_manto := ""
var _cine_running := false


func _ready() -> void:
	var save := get_node_or_null("/root/Save")
	if save != null and save.has_method("notify_map_changed"):
		save.notify_map_changed("map_06")
	_banner = $Banner
	_progress = $ProgressLabel
	_manto = $MantoLabel
	_banner.visible = false
	_enoc = get_tree().get_first_node_in_group("enoc")
	_quest = get_tree().get_first_node_in_group("quest_Q06")
	_wire_path()
	if _enoc != null and _enoc.has_signal("prayer_started"):
		_enoc.prayer_started.connect(_on_prayer)
	if _quest != null and _quest.has_signal("quest_changed"):
		_quest.quest_changed.connect(_on_quest_changed)
	_update_hud()


func _process(_delta: float) -> void:
	_update_hud()


func _wire_path() -> void:
	if _enoc == null:
		return
	var path_node := get_node_or_null("EnocPath")
	if path_node == null:
		return
	var pts: Array = []
	var kids := path_node.get_children()
	kids.sort_custom(func(a: Node, b: Node) -> bool: return a.name < b.name)
	for k in kids:
		if k is Node3D:
			pts.push_back((k as Node3D).global_position)
	if pts.size() >= 2 and _enoc.has_method("set_path"):
		_enoc.call("set_path", pts)


func _on_prayer(_idx: int) -> void:
	# Evento de oración: oleada de presión (2 ecos cerca de Enoc).
	if not _authoritative():
		return
	if _enoc == null:
		return
	var at: Vector3 = (_enoc as Node3D).global_position + Vector3(3, 0.5, -3)
	for i in 2:
		var w := WHISPER_SCENE.instantiate() as Node3D
		add_child(w)
		w.global_position = at + Vector3(i * 2.0, 0, 0)


func _update_hud() -> void:
	if _quest != null and _progress != null:
		var txt := "Escolta de Enoc: %d/%d" % [_quest.done_count, _quest.data.task_total]
		if txt != _last_shown:
			_last_shown = txt
			_progress.text = txt
	if _manto != null:
		var has := _has_manto()
		var txt2 := "Manto de viento: SÍ — E en montura para volar" if has else "Manto de viento: NO — completa la escolta"
		if txt2 != _last_manto:
			_last_manto = txt2
			_manto.text = txt2


func _has_manto() -> bool:
	var save := get_node_or_null("/root/Save")
	if save == null:
		return false
	return bool((save.get("state") as Dictionary).get("flags", {}).get("manto_viento", false))


func _on_quest_changed(state: StringName) -> void:
	if state == &"done" and not _cine_running:
		_cinematic()


func _cinematic() -> void:
	_cine_running = true
	for p in get_tree().get_nodes_in_group("player"):
		if p != null and p.has_method("is_local_avatar") and bool(p.call("is_local_avatar")):
			p.set("cutscene_lock", true)
	_banner.text = "Enoc caminó con Dios. El linaje fiel permanece."
	_banner.visible = true
	await get_tree().create_timer(5.0).timeout
	var save := get_node_or_null("/root/Save")
	if save != null:
		(save.get("state") as Dictionary).get("flags", {})["manto_viento"] = true
		save.save_game()
	if _authoritative() and _quest != null:
		_quest.restore()
	for p in get_tree().get_nodes_in_group("player"):
		if p != null and p.has_method("is_local_avatar") and bool(p.call("is_local_avatar")):
			p.set("cutscene_lock", false)
	_banner.text = "Manto de viento recibido: vuela Map_01↔Map_06 (solo transporte). Cap. 7."
	await get_tree().create_timer(3.0).timeout
	_banner.visible = false


func _authoritative() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()
