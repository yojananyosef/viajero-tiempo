extends Node3D
## SPEC-012 — Director de Map_10 (Babel, torre por pisos + cima):
## 3 sellos en orden → Nimrod despierta (confusión 30s, solo efecto HUD) →
## Nimrod caído → ídolo rompible → 5/5 → dispersión → expansion1_complete
## + chapter=11 + créditos + teaser Expansión 2.

const CONFUSION_TIME: float = 30.0
const FRAGMENTS: Array[String] = [
	"…el cielo es nuestro…",
	"…¿qué dices? no te entiendo…",
	"…balal — בלל — confundir…",
	"…¡las marcas! coordina por señas…",
	"…hagamos un nombre… shem…",
	"…la torre… ¿por qué subimos?…",
]

var _quest: Node = null
var _banner: Label3D = null
var _progress: Label3D = null
var _confusion: Label3D = null
var _last_shown := ""
var _conf_t := 0.0
var _conf_on := false
var _last_frag := ""
var _cine_running := false


func _ready() -> void:
	var save := get_node_or_null("/root/Save")
	if save != null and save.has_method("notify_map_changed"):
		save.notify_map_changed("map_10")
	_banner = $Banner
	_progress = $ProgressLabel
	_confusion = $ConfusionLabel
	_banner.visible = false
	_confusion.visible = false
	_quest = get_tree().get_first_node_in_group("quest_Q10")
	if _quest != null:
		if _quest.has_signal("quest_changed"):
			_quest.quest_changed.connect(_on_quest_changed)
		if _quest.has_signal("progress_changed"):
			_quest.progress_changed.connect(_on_quest_progress)
		_update_progress()


func _process(delta: float) -> void:
	_update_progress()
	_tick_confusion(delta)


func trigger_confusion() -> void:
	# La confusión es solo efecto HUD (no bloquea nada): el grupo se
	# coordina por marcas mientras el chat se fragmenta 30s.
	_conf_on = true
	_conf_t = CONFUSION_TIME


func is_confused() -> bool:
	return _conf_on


func _on_quest_progress(done: int, _total: int) -> void:
	if _authoritative() and done == 3 and not _conf_on:
		trigger_confusion()


func _tick_confusion(delta: float) -> void:
	if _confusion == null:
		return
	if not _conf_on:
		_confusion.visible = false
		return
	_conf_t -= delta
	if _conf_t <= 0.0:
		_conf_on = false
		_confusion.visible = false
		return
	_confusion.visible = true
	var frag := FRAGMENTS[int(_conf_t / 2.0) % FRAGMENTS.size()]
	if frag != _last_frag:
		_last_frag = frag
		_confusion.text = "Confusión (%ds): %s" % [int(_conf_t), frag]


func _update_progress() -> void:
	if _quest == null or _progress == null:
		return
	var txt := "Babel: pisos y cima %d/%d" % [_quest.done_count, _quest.data.task_total]
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
	_banner.text = "La cúspide queda sellada. El ídolo yace roto."
	_banner.visible = true
	await get_tree().create_timer(5.0).timeout
	var save := get_node_or_null("/root/Save")
	if save != null:
		(save.get("state") as Dictionary).get("flags", {})["expansion1_complete"] = true
		save.save_game()
	if _authoritative() and _quest != null:
		_quest.restore()
	for p in get_tree().get_nodes_in_group("player"):
		if p != null and p.has_method("is_local_avatar") and bool(p.call("is_local_avatar")):
			p.set("cutscene_lock", false)
	_banner.text = "Y los dispersó Jehová… EXPANSIÓN 1 COMPLETA. Créditos: Génesis restaurado tal cual. Teaser: Expansión 2 · Éxodo (el portal duerme)."
	await get_tree().create_timer(3.0).timeout
	_banner.visible = false


func _authoritative() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()
