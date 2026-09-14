extends Node
## SPEC-002 — Persistencia versionada (autoload `Save`).
## Solo data pura (ids, no nodos). Escritura tmp+rename + backup `.bak`.
## Load: version -> migrar -> validar -> reconstruir. Si el parse falla,
## se intenta el backup antes de rendirse.
## Debug: F5 guarda save_0.json, F9 carga.

signal game_saved(path: String)
signal game_loaded(data: Dictionary)

const SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://save_0.json"
const AUTOSAVE_PATH: String = "user://autosave.json"
const AUTOSAVE_INTERVAL: float = 60.0

var state: Dictionary = {}
var _time: float = 0.0
var _last_autosave: float = -9999.0


func _ready() -> void:
	randomize()
	state = default_state()


func default_state() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"player": {"hp": 100, "pos": [0.0, 1.0, 0.0], "class": "llamado"},
		"flags": {},
		"chapter": 1,
		"seed": randi(),
		"map": "map_01",
	}


func _player_node() -> Node3D:
	var t := get_tree()
	if t == null:
		return null
	return t.get_first_node_in_group("player") as Node3D


func capture_state() -> Dictionary:
	var data := default_state()
	var prev_player := state.get("player", {}) as Dictionary
	data["chapter"] = int(state.get("chapter", 1))
	data["flags"] = (state.get("flags", {}) as Dictionary).duplicate(true)
	data["seed"] = int(state.get("seed", randi()))
	data["map"] = str(state.get("map", "map_01"))
	var pl := data["player"] as Dictionary
	pl["hp"] = int(prev_player.get("hp", 100))
	pl["class"] = str(prev_player.get("class", "llamado"))
	var p := _player_node()
	if p != null:
		pl["pos"] = [p.global_position.x, p.global_position.y, p.global_position.z]
	return data


func save_atomic(path: String, data: Dictionary) -> Error:
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if DirAccess.rename_absolute(tmp, path) != OK:
		return FAILED
	return OK


func load_migrated(path: String) -> Dictionary:
	var data := _read_json(path)
	if data.is_empty() and FileAccess.file_exists(path + ".bak"):
		push_warning("Save corrupto, usando backup: " + path)
		data = _read_json(path + ".bak")
	if data.is_empty():
		return {}
	return _migrate(data)


func save_game(path: String = SAVE_PATH) -> Error:
	state = capture_state()
	var err := save_atomic(path, state)
	if err == OK:
		game_saved.emit(path)
	else:
		push_error("No se pudo guardar en " + path)
	return err


func load_game(path: String = SAVE_PATH) -> bool:
	var data := load_migrated(path)
	if data.is_empty():
		push_error("Sin datos válidos en " + path + " ni backup.")
		return false
	state = data
	apply_state(state)
	game_loaded.emit(state)
	return true


func apply_state(data: Dictionary) -> void:
	var p := _player_node()
	if p == null:
		return
	var pos = (data.get("player", {}) as Dictionary).get("pos", [0.0, 1.0, 0.0])
	if pos is Array and (pos as Array).size() == 3:
		p.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		if p is CharacterBody3D:
			(p as CharacterBody3D).velocity = Vector3.ZERO
	# SPEC-007: restaura la senda persistida (F9/load).
	var cid := str((data.get("player", {}) as Dictionary).get("class", "llamado"))
	if cid != "" and cid != "llamado" and p.has_method("apply_class"):
		p.call("apply_class", cid)


func notify_map_changed(map_id: String) -> void:
	state["map"] = map_id
	if _time - _last_autosave >= AUTOSAVE_INTERVAL:
		_last_autosave = _time
		save_game(AUTOSAVE_PATH)


func _process(delta: float) -> void:
	_time += delta
	if _time - _last_autosave < AUTOSAVE_INTERVAL:
		return
	_last_autosave = _time
	if _player_node() == null:
		return
	state = capture_state()
	if save_atomic(AUTOSAVE_PATH, state) == OK:
		game_saved.emit(AUTOSAVE_PATH)


func _unhandled_input(event: InputEvent) -> void:
	# Atajo de debug para probar el criterio OK sin UI (la UI llega en specs Q).
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.physical_keycode == KEY_F5:
			save_game()
			get_viewport().set_input_as_handled()
		elif k.physical_keycode == KEY_F9:
			load_game()
			get_viewport().set_input_as_handled()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	if version > SAVE_VERSION:
		push_error("Save de versión futura (%d), se ignora." % version)
		return {}
	var clean := default_state()
	for k in data.keys():
		clean[k] = data[k]
	if version < SAVE_VERSION:
		var pl := {"hp": 100, "pos": [0.0, 1.0, 0.0], "class": "llamado"}
		if clean["player"] is Dictionary:
			for pk in (clean["player"] as Dictionary).keys():
				pl[pk] = (clean["player"] as Dictionary)[pk]
		clean["player"] = pl
		clean["version"] = SAVE_VERSION
	if not (clean["player"] is Dictionary):
		push_error("Save inválido: player no es Dictionary.")
		return {}
	return clean
