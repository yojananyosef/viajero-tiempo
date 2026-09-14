extends Node3D
## SPEC-008 — Director de Map_05: Fase A (ofrenda 0/2 contrarreloj suave +
## oleadas ecos) y Fase B (Envidia). Al 3/3 → restore → chapter=6.
## Respeto al relato: Abel no se puede salvar; solo asegurar que ocurra.

const TIME_LIMIT: float = 180.0
const WHISPER_SCENE: PackedScene = preload("res://scenes/enemies/Whisper.tscn")

var time_left: float = TIME_LIMIT

var _quest: Node = null
var _banner: Label3D = null
var _progress: Label3D = null
var _timer_label: Label3D = null
var _last_shown := ""
var _last_time := ""
var _cine_running := false
var _extra_wave := false
var _waves_spawned := 0


func _ready() -> void:
	var save := get_node_or_null("/root/Save")
	if save != null and save.has_method("notify_map_changed"):
		save.notify_map_changed("map_05")
	_banner = $Banner
	_progress = $ProgressLabel
	_timer_label = $TimerLabel
	_banner.visible = false
	_quest = get_tree().get_first_node_in_group("quest_Q05")
	if _quest != null:
		if _quest.has_signal("quest_changed"):
			_quest.quest_changed.connect(_on_quest_changed)
		if _quest.has_signal("progress_changed"):
			_quest.progress_changed.connect(_on_quest_progress)
		_update_progress()


func _process(delta: float) -> void:
	_update_progress()
	_tick_timer(delta)


func _tick_timer(delta: float) -> void:
	# Contrarreloj suave: al agotarse spawnea una oleada extra, sin fail duro.
	if _quest != null and _quest.state == &"done":
		return
	time_left = maxf(0.0, time_left - delta)
	var txt := "Ofrenda: %ds (suave)" % int(time_left)
	if txt != _last_time and _timer_label != null:
		_last_time = txt
		_timer_label.text = txt
	if time_left <= 0.0 and not _extra_wave and _authoritative():
		_extra_wave = true
		_spawn_wave()


func _on_quest_progress(done: int, _total: int) -> void:
	# Oleada eco al consagrar cada ofrenda (presión Fase A).
	if _authoritative() and done <= 2:
		_spawn_wave()


func _spawn_wave() -> void:
	if not _authoritative():
		return
	_waves_spawned += 1
	var base := get_tree().get_nodes_in_group("player")
	var at := Vector3(0, 0.5, -10)
	if not base.is_empty() and base[0] is Node3D:
		at = (base[0] as Node3D).global_position + Vector3(randf_range(-6.0, 6.0), 0.5, -6.0)
	for i in 2:
		var w := WHISPER_SCENE.instantiate() as Node3D
		add_child(w)
		w.global_position = at + Vector3(i * 2.0, 0, 0)


func _update_progress() -> void:
	if _quest == null or _progress == null:
		return
	var txt := "Ofrenda y relato: %d/%d" % [_quest.done_count, _quest.data.task_total]
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
	_banner.text = "La ofrenda ocurrió tal cual. El relato queda sin corrupción."
	_banner.visible = true
	await get_tree().create_timer(5.0).timeout
	if _authoritative() and _quest != null:
		_quest.restore()
	for p in get_tree().get_nodes_in_group("player"):
		if p != null and p.has_method("is_local_avatar") and bool(p.call("is_local_avatar")):
			p.set("cutscene_lock", false)
	_banner.text = "Cap. 6 desbloqueado: Set y Enoc."
	await get_tree().create_timer(3.0).timeout
	_banner.visible = false


func _authoritative() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()
