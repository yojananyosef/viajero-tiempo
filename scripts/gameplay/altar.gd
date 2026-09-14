extends StaticBody3D
## SPEC-007 — Altar de la senda: E cerca cicla Guardián→Escriba→Pastor.
## Cambio libre con cooldown 10s. La primera elección cuenta 1/1 en Q04.
## Solo solo/servidor aplican; `class_id` de cada avatar se sincroniza.

signal class_chosen(class_id: String)

const ORDER: Array[String] = ["guardian", "escriba", "pastor"]
const SWITCH_COOLDOWN: float = 10.0

@export var interact_radius: float = 3.5

var _quest: Node = null
var _prompt: Label3D = null
var _info: Label3D = null
var _cd := 0.0


func _ready() -> void:
	add_to_group("altar")
	_prompt = $PromptLabel
	_info = $InfoLabel
	_quest = get_tree().get_first_node_in_group("quest_Q04")
	_update_info("Acércate y pulsa E para elegir senda.")
	_setup_replication()


func _process(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)
	var av := _nearest_avatar()
	var can: bool = _task_open() or _quest == null or _quest.state == &"done" or _quest.state == &"restored"
	_prompt.visible = av != null and _cd <= 0.0 and can
	if _authoritative() and av != null and _cd <= 0.0 and can and Input.is_action_just_pressed("interact"):
		_choose_next(av)


func _choose_next(av: Node3D) -> void:
	var cur := str(av.get("class_id")) if av.get("class_id") != null else "llamado"
	var nxt := ORDER[0]
	if cur in ORDER:
		nxt = ORDER[(ORDER.find(cur) + 1) % ORDER.size()]
	if av.has_method("apply_class"):
		av.call("apply_class", nxt)
	_cd = SWITCH_COOLDOWN
	_update_info("Senda: %s (cambio en %ds)" % [nxt, int(SWITCH_COOLDOWN)])
	class_chosen.emit(nxt)
	if _quest != null and (_quest.state == &"available" or _quest.state == &"active"):
		_quest.register_task()


func _update_info(t: String) -> void:
	if _info != null:
		_info.text = "Altar de la Redención — " + t


func _task_open() -> bool:
	return _quest != null and (_quest.state == &"available" or _quest.state == &"active")


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


func _authoritative() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


func _setup_replication() -> void:
	pass  # El altar no replica estado; la senda vive en cada avatar + save.
