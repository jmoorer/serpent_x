extends SceneTree

# Headless smoke test: AI drives the player against round N's opponent and logs combat events.
# godot --headless --path . --fixed-fps 60 --script res://tools/autoplay.gd -- <round 0..2>[:loadout]

var _fight: Node
var _frames: int = 0
var _hooked: bool = false
var _counts: Dictionary = {}
var _shots: Array[int] = []
var _title_only: bool = false


# Extra args are frame numbers to screenshot into /tmp/sx_shot_<frame>.png (windowed runs only).
# Round "title" / "select" just screenshots that menu.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(1, args.size()):
		_shots.append(int(args[i]))
	var gs := root.get_node("GameState")
	var spec := (args[0] if args.size() > 0 else "0").split(":")
	if spec.size() > 1:
		gs.player_loadout = StringName(spec[1])
	if spec[0] in ["title", "select"]:
		change_scene_to_file("res://scenes/%s/%s.tscn" % [spec[0], spec[0]])
		_title_only = true
		return
	gs.round_index = int(spec[0])
	gs.showing_controls = false
	change_scene_to_file("res://scenes/fight/fight.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames in _shots:
		root.get_texture().get_image().save_png("/tmp/sx_shot_%d.png" % _frames)
		if _frames == _shots.max() and _title_only:
			return true
	if _title_only:
		return false
	if not _hooked and current_scene != null and current_scene.name == "Fight" and current_scene.get("player") != null:
		_hook(current_scene)
	if _hooked and current_scene != _fight:
		print("SCENE CHANGED -> ", current_scene.scene_file_path if current_scene else "null")
		_report()
		return true
	if _frames > 60 * 120:
		print("TIMEOUT phase=%s time_left=%.1f time_scale=%.2f P hp %.0f st %s  E hp %.0f st %s" % [
			_fight.phase, _fight.time_left, Engine.time_scale, _fight.player.hp, _fight.player.state, _fight.enemy.hp, _fight.enemy.state])
		_report()
		return true
	return false


func _hook(fight: Node) -> void:
	_hooked = true
	_fight = fight
	var p = fight.player
	var e = fight.enemy
	var gs := root.get_node("GameState")
	p.is_player = false
	var ai = load("res://actors/ai_controller.gd").new()
	fight.add_child(ai)
	var prof: Dictionary = gs.opponent_profile().duplicate()
	prof["aggression"] = 0.75
	prof["uses_rush"] = true
	prof["uses_afterimage"] = true
	prof["uses_tech2"] = true
	prof["string_len"] = 4
	ai.setup(p, prof)
	for f in [p, e]:
		var who := "P" if f == p else "E"
		f.hit_landed.connect(func (_t, id: StringName) -> void: _count("%s hit %s" % [who, id]))
		f.blocked_hit.connect(func (_a) -> void: _count("%s blocked" % who))
		f.technique_used.connect(func (n: String) -> void: _count("%s TECH %s" % [who, n]))
		f.combo_changed.connect(func (h: int) -> void: if h >= 4: _count("%s combo>=4" % who))
		f.clashed.connect(func (_o) -> void: _count("clash"))
		f.died.connect(func () -> void: print("[%d] %s DIED  P hp %.0f  E hp %.0f" % [_frames, who, p.hp, e.hp]))


func _count(k: String) -> void:
	_counts[k] = int(_counts.get(k, 0)) + 1


func _report() -> void:
	var keys := _counts.keys()
	keys.sort()
	for k in keys:
		print("  %-28s %d" % [k, _counts[k]])
