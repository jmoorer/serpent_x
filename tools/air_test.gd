extends SceneTree

# Air combo checks in training mode vs a standing dummy: launcher chase strings, spike bounce
# follow-up, jump-in, one air string per jump. Runs every animation style (exits 1 on failure).
# godot --headless --path . --fixed-fps 60 --script res://tools/air_test.gd

const LOADOUTS := [&"turtle", &"crane", &"wolf", &"mountain"]
const GAP := 7

var _failed: int = 0
var _p
var _e
var _t
var _hits: int = 0
var _air_hits: int = 0
var _bounce_hits: int = 0
var _knockdown: bool = false
var _bounced: bool = false
var _max_y: float = 0.0
var _air_starts: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.training = true
	for loadout: StringName in LOADOUTS:
		gs.player_loadout = loadout
		change_scene_to_file("res://scenes/fight/fight.tscn")
		await process_frame
		while current_scene == null or current_scene.name != "Fight" or current_scene.get("training") == null:
			await process_frame
		var fight := current_scene
		_t = fight.training
		_p = fight.player
		_e = fight.enemy
		_p.is_player = false
		_e.got_hit.connect(_on_enemy_hit)
		print("-- %s" % loadout)
		await _wait(5)
		await _case_chase_string()
		await _case_spike_bounce()
		await _case_full_route()
		await _case_jump_in()
		await _case_one_string_per_jump()
	print("DONE  failures: %d" % _failed)
	quit(1 if _failed > 0 else 0)


func _case_chase_string() -> void:
	await _setup()
	await _sequence(["light", "heavy", "hop", "light", "light", "light"])
	await _wait(90)
	_check(_hits >= 5 and _air_hits >= 3 and _knockdown,
		"J K › Space › J J J juggles into Heaven Kick (hits %d, air %d, knockdown %s, peak %.1fm)" % [_hits, _air_hits, _knockdown, _max_y])


func _case_spike_bounce() -> void:
	await _setup()
	await _sequence(["light", "heavy", "hop", "light", "heavy"])
	var f := 0
	while not _e._bouncing and f < 90:
		await _wait(1)
		f += 1
	while not (_p.state == 0 and _p.is_on_floor()) and f < 150:
		await _wait(1)
		f += 1
	await _sequence(["light", "heavy"])
	await _wait(60)
	_check(_bounced and _bounce_hits >= 1,
		"Meteor Smash bounces and J K relaunches off the bounce (bounced %s, bounce hits %d, total %d)" % [_bounced, _bounce_hits, _hits])


func _case_full_route() -> void:
	await _setup()
	await _sequence(["light", "heavy", "hop", "light", "light", "heavy"])
	var f := 0
	while not _e._bouncing and f < 90:
		await _wait(1)
		f += 1
	while not (_p.state == 0 and _p.is_on_floor()) and f < 150:
		await _wait(1)
		f += 1
	await _sequence(["light", "heavy", "hop", "light", "light", "light"])
	await _wait(90)
	_check(_hits >= 10 and _knockdown, "full route J K › Space › J J K › bounce J K › Space › J J J (hits %d)" % _hits)


func _case_jump_in() -> void:
	await _setup()
	await _sequence(["hop"])
	await _wait(28)
	await _sequence(["heavy"])
	await _wait(30)
	_check(_hits == 1 and _air_hits == 0 and not _knockdown,
		"jump-in air K hits a standing opponent without knocking down (hits %d, air %d, knockdown %s)" % [_hits, _air_hits, _knockdown])
	await _wait(60)


func _case_one_string_per_jump() -> void:
	await _setup()
	_e.reset_to(Vector3(0, 0.1, -6.0))
	await _wait(5)
	_air_starts = 0
	await _sequence(["hop"])
	for i in 8:
		await _sequence(["light"])
	_check(_air_starts == 1 and _hits == 0, "one air string per jump (air strings started %d)" % _air_starts)


func _on_enemy_hit(_a, _d) -> void:
	_hits += 1
	if not _e.is_on_floor():
		_air_hits += 1
		if DisplayServer.get_name() != "headless":
			root.get_texture().get_image().save_png("/tmp/sx_air_%s_%d.png" % [_p.style, _hits])
	if _e._bouncing:
		_bounce_hits += 1


func _setup() -> void:
	_t.dummy.set_mode(0)
	_p.reset_to(Vector3(0, 0.1, 1.0))
	_e.reset_to(Vector3(0, 0.1, -0.6))
	await _wait(40)
	_hits = 0
	_air_hits = 0
	_bounce_hits = 0
	_knockdown = false
	_bounced = false
	_max_y = 0.0


func _sequence(actions: Array) -> void:
	for a: String in actions:
		_p.set_ai_input({a: true})
		await _tick()
		_p.set_ai_input({})
		for i in GAP - 1:
			await _tick()


func _wait(frames: int) -> void:
	for i in frames:
		await _tick()


func _tick() -> void:
	await physics_frame
	if _e == null:
		return
	_max_y = maxf(_max_y, _e.global_position.y)
	if _e.state == 9:
		_knockdown = true
	if _e._bouncing:
		_bounced = true
	if _p.state == 2 and _p._attack_frame == 1 and _p._move.id in [&"AL1", &"AH"]:
		_air_starts += 1


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failed += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])
