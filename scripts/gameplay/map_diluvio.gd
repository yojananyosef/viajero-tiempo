extends Node3D
## SPEC-010 — Director de Map_07 (instancia del Arca): 3 brechas + Heraldo,
## agua que sube (timer suave, oleada extra por tramo) y wipe → restart
## de instancia sin pérdida fuera (capítulo y sellos intactos).
## Al 4/4 → cinemática → tablas + restore → chapter=8.

const WHISPER_SCENE: PackedScene = preload("res://scenes/enemies/Whisper.tscn")
const WATER_TIME: float = 240.0
const WATER_MAX: float = 3.0
const WAVE_EVERY: float = 60.0

var water_level: float = 0.0

var _quest: Node = null
var _herald: Node3D = null
var _banner: Label3D = null
var _progress: Label3D = null
var _water_label: Label3D = null
var _water: MeshInstance3D = null
var _t := 0.0
var _next_wave := WAVE_EVERY
var _last_shown := ""
var _last_water := ""
var _cine_running := false
var _restarting := false


func _ready() -> void:
	var save := get_node_or_null("/root/Save")
	if save != null and save.has_method("notify_map_changed"):
		save.notify_map_changed("map_07")
	_banner = $Banner
	_progress = $ProgressLabel
	_water_label = $WaterLabel
	_water = $Water
	_banner.visible = false
	_herald = get_tree().get_first_node_in_group("herald")
	_quest = get_tree().get_first_node_in_group("quest_Q07")
	if _quest != null:
		if _quest.has_signal("quest_changed"):
			_quest.quest_changed.connect(_on_quest_changed)
		if _quest.has_signal("progress_changed"):
			_quest.progress_changed.connect(_on_quest_progress)
	_update_hud()


func _process(delta: float) -> void:
	_update_hud()
	if not _authoritative() or (_quest != null and _quest.state == &"done"):
		return
	_t += delta
	water_level = minf(WATER_MAX, _t / WATER_TIME * WATER_MAX)
	if _water != null:
		_water.position.y = 0.2 + water_level
	if _t >= _next_wave:
		_next_wave += WAVE_EVERY
		_spawn_wave()
	_check_wipe()


func restart_instance() -> void:
	# Wipe → restart de instancia, sin pérdida fuera (SPEC-010).
	if not _authoritative() or _restarting:
		return
	_restarting = true
	_t = 0.0
	water_level = 0.0
	_next_wave = WAVE_EVERY
	if _water != null:
		_water.position.y = 0.2
	if _quest != null and _quest.has_method("reset_progress"):
		_quest.call("reset_progress")
	for b in get_tree().get_nodes_in_group("q07_breaches"):
		if b != null and b.has_method("reset_breach"):
			b.call("reset_breach")
	if _herald != null and _herald.has_method("reset_boss"):
		_herald.call("reset_boss")
	for w in get_tree().get_nodes_in_group("whispers"):
		if is_instance_valid(w):
			w.queue_free()
	_spawn_wave()
	_spawn_wave()
	var sp := get_node_or_null("SpawnPoint") as Node3D
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node3D:
			if sp != null:
				(p as Node3D).global_position = sp.global_position
			if p.get("hp") != null:
				p.set("hp", p.get("max_hp"))
			if p.get("fly_mode") != null and bool(p.get("fly_mode")) and p.has_method("land"):
				p.call("land")
	_banner.text = "El Arca se mantiene — la instancia recomienza."
	_banner.visible = true
	await get_tree().create_timer(3.0).timeout
	_banner.visible = false
	_restarting = false


func _on_quest_progress(done: int, _total: int) -> void:
	if _authoritative() and done <= 3:
		_spawn_wave()


func _spawn_wave() -> void:
	if not _authoritative():
		return
	var at := Vector3(0, 1.5, -10)
	if _herald != null and is_instance_valid(_herald):
		at = (_herald as Node3D).global_position + Vector3(3, 0.5, 3)
	for i in 2:
		var w := WHISPER_SCENE.instantiate() as Node3D
		add_child(w)
		w.global_position = at + Vector3(i * 2.0, 0, 0)


func _check_wipe() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	for p in players:
		if p == null or p.get("hp") == null or int(p.get("hp")) > 0:
			return
	restart_instance()


func _update_hud() -> void:
	if _quest != null and _progress != null:
		var txt := "Arca: brechas y heraldo %d/%d" % [_quest.done_count, _quest.data.task_total]
		if txt != _last_shown:
			_last_shown = txt
			_progress.text = txt
	if _water_label != null:
		var txt2 := "Agua: %.1fm (suave)" % water_level
		if txt2 != _last_water:
			_last_water = txt2
			_water_label.text = txt2


func _on_quest_changed(state: StringName) -> void:
	if state == &"done" and not _cine_running:
		_cinematic()


func _cinematic() -> void:
	_cine_running = true
	for p in get_tree().get_nodes_in_group("player"):
		if p != null and p.has_method("is_local_avatar") and bool(p.call("is_local_avatar")):
			p.set("cutscene_lock", true)
	_banner.text = "La puerta quedó asegurada. El Arca flota sobre las aguas."
	_banner.visible = true
	await get_tree().create_timer(5.0).timeout
	var save := get_node_or_null("/root/Save")
	if save != null:
		(save.get("state") as Dictionary).get("flags", {})["tablas_pacto"] = true
		save.save_game()
	if _authoritative() and _quest != null:
		_quest.restore()
	for p in get_tree().get_nodes_in_group("player"):
		if p != null and p.has_method("is_local_avatar") and bool(p.call("is_local_avatar")):
			p.set("cutscene_lock", false)
	_banner.text = "Tablas del pacto previo recibidas. Cap. 8 desbloqueado."
	await get_tree().create_timer(3.0).timeout
	_banner.visible = false


func _authoritative() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()
