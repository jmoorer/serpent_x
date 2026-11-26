extends SceneTree

# Forces each loadout's techniques at set distances and reports whether they connect.
# godot --headless --path . --fixed-fps 60 --script res://tools/tech_test.gd

const T0 := 30
const CASES := [
	# [loadout, tech, distance, enemy action, expect]
	["turtle", "tech2", 6.0, "", "hit"],
	["crane", "tech1", 3.0, "", "daze"],
	["crane", "tech1", 3.0, "block", "daze"],
	["crane", "tech2", 8.0, "", "hit"],
	["wolf", "tech2", 7.0, "strafe", "hit"],
	["wolf", "tech1", 1.6, "attack", "counter"],
	["mountain", "tech1", 1.6, "attack", "armor"],
	["mountain", "tech2", 3.0, "block", "hit"],
	["mountain", "tech2", 3.0, "hop", "miss"],
	["crane", "tech3", 3.0, "", "rush"],
	["wolf", "tech3", 3.0, "", "rush"],
	["mountain", "tech3", 3.0, "", "rush"],
]

var _case: int = -1
var _frame: int = 0
var _fight: Node
var _p
var _e
var _e_hp0: float
var _p_hp0: float
var _seen: Dictionary = {}
var _fails: int = 0


func _initialize() -> void:
	_next_case()


func _next_case() -> void:
	_case += 1
	if _case >= CASES.size():
		print("DONE  failures: %d" % _fails)
		quit()
		return
	var gs := root.get_node("GameState")
	gs.player_loadout = StringName(CASES[_case][0])
	gs.round_index = 0
	gs.showing_controls = false
	_fight = null
	_frame = 0
	change_scene_to_file("res://scenes/fight/fight.tscn")


func _process(_delta: float) -> bool:
	if _case >= CASES.size():
		return true
	if _fight == null:
		if current_scene != null and current_scene.name == "Fight" and current_scene.get("player") != null:
			_setup(current_scene)
		return false
	_frame += 1
	var c: Array = CASES[_case]
	var inp := {}
	match c[3]:
		"block":
			inp["block_held"] = true
		"strafe":
			inp["x"] = 1.0
		"hop":
			if _frame == T0 + 12:
				inp["hop"] = true
		"attack":
			if _frame == T0 + 8:
				inp["light"] = true
	_e.set_ai_input(inp)
	if _frame == T0:
		_p.ki = 100.0
		_p.confirm_ready = true
		if not _p.try_technique(StringName(c[1])):
			print("  could not start %s" % c[1])
	var su: int = (_p.moves[StringName(c[1])] as MoveData).startup
	if DisplayServer.get_name() != "headless" and _frame == T0 + su + 4:
		root.get_texture().get_image().save_png("/tmp/sx_tech_%d_%s_%s.png" % [_case, c[0], c[1]])
	if _e.state == 4 and _e.get("_daze_left") > 0:
		_seen["daze"] = true
	if _p.get("_armor_left") > 0 and _p.hp < _p_hp0 and _p.state != 4:
		_seen["armor"] = true
	if _p._move and _p._move.id == &"counter_hit":
		_seen["counter"] = true
	if _e.hp < _e_hp0:
		_seen["hit"] = true
	if c[1] == "tech3" and _e.hp < _e_hp0 - 15.0 and _e.state == 9:
		_seen["rush"] = true
	if _frame >= T0 + 150:
		var got := "miss"
		for k in ["counter", "armor", "daze", "rush", "hit"]:
			if _seen.has(k):
				got = k
				break
		var ok: bool = got == c[4]
		if not ok:
			_fails += 1
		print("%s %-9s %-6s d=%.1f enemy=%-6s -> %-8s (want %s)  E hp %.0f->%.0f" % [
			"PASS" if ok else "FAIL", c[0], c[1], c[2], c[3], got, c[4], _e_hp0, _e.hp])
		_next_case()
	return false


func _setup(fight: Node) -> void:
	_fight = fight
	_seen.clear()
	for n in fight.get_children():
		if n.get_script() == load("res://actors/ai_controller.gd"):
			n.queue_free()
	_p = fight.player
	_e = fight.enemy
	_p.is_player = false
	var c: Array = CASES[_case]
	_p.global_position = Vector3(0, 0.1, 2.0)
	_e.global_position = Vector3(0, 0.1, 2.0 - float(c[2]))
	_p.controllable = true
	_e.controllable = true
	fight.phase = 1
	fight.camera_rig.focus(null)
	_e_hp0 = _e.hp
	_p_hp0 = _p.hp
