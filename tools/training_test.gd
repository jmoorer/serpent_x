extends SceneTree

# Training mode checks: dummy modes, immortality, HP refill, CPU handoff, reset, move list.
# godot --headless --path . --fixed-fps 60 --script res://tools/training_test.gd

var _failed: int = 0
var _hits: int = 0
var _blocks: int = 0
var _p
var _e
var _t


func _initialize() -> void:
	_run()


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.training = true
	gs.player_loadout = &"wolf"
	change_scene_to_file("res://scenes/fight/fight.tscn")
	while current_scene == null or current_scene.name != "Fight" or current_scene.get("training") == null:
		await process_frame
	var fight := current_scene
	_t = fight.training
	_p = fight.player
	_e = fight.enemy
	_p.is_player = false
	_e.got_hit.connect(func (_a, _d) -> void: _hits += 1)
	_e.blocked_hit.connect(func (_a) -> void: _blocks += 1)
	await _wait(5)

	_check(fight.ai == null, "no tournament AI in training")
	_check(_p.ki == 100.0, "infinite ki on by default")

	await _setup_mode(1)
	await _press("light")
	await _wait(30)
	_check(_blocks >= 1 and _hits == 0, "Block mode blocks a jab (hits %d, blocks %d)" % [_hits, _blocks])

	await _setup_mode(0)
	for i in 4:
		await _press("light")
		await _wait(12)
	await _wait(30)
	_check(_hits >= 3, "Stand mode takes the J string (hits %d)" % _hits)
	await _wait(120)
	await _setup_mode(0)
	var lethal = load("res://projectiles/hit_payload.gd").new()
	lethal.owner_fighter = _p
	lethal.damage = 9999.0
	lethal.hitstun = 20
	lethal.hit_tier = 1
	_e.take_hit(lethal)
	_check(_hits == 1 and _e.hp == 1.0 and _e.state != _p.get_script().State.DEAD, "dummy survives a lethal hit (hits %d, hp %.1f)" % [_hits, _e.hp])
	await _wait(10)
	await _wait(120)
	_check(_e.hp == _e.max_hp, "dummy HP refills after the combo (hp %.1f)" % _e.hp)

	await _setup_mode(2)
	await _press("light")
	await _wait(30)
	var first_hits := _hits
	await _press("light")
	await _wait(30)
	_check(first_hits == 1 and _blocks >= 1, "Block after first hit (hits %d, blocks %d)" % [first_hits, _blocks])

	var struck := [0]
	_p.got_hit.connect(func (_a, _d) -> void: struck[0] += 1)
	await _setup_mode(5)
	struck[0] = 0
	await _wait(150)
	_check(struck[0] >= 1, "Jab mode hits the idle player (%d)" % struck[0])

	await _setup_mode(6)
	struck[0] = 0
	await _wait(900)
	_check(_t.dummy._ai != null, "CPU mode spawns an AIController")
	_check(struck[0] > 0 and _p.state != _p.get_script().State.DEAD, "CPU dummy attacks, player survives (%d hits)" % struck[0])
	await _setup_mode(0)
	await _wait(2)
	_check(_t.dummy._ai == null, "leaving CPU mode frees the AI")

	_p.global_position = Vector3(5, 0.1, 5)
	_t.reset_positions()
	await _wait(2)
	_check(_p.global_position.distance_to(fight.spawn_p.global_position) < 0.2, "reset puts the player back on spawn")

	var text: String = _t.move_list._text.get_parsed_text()
	for want in ["Rising Dragon", "Knee Crush", "Tornado Heel", "Flying Kick", "Counter Stance", "Spirit Ball", "Wolf Fang Fist", "Counter Hit"]:
		_check(text.contains(want), "move list shows %s" % want)

	print("DONE  failures: %d" % _failed)
	quit(1 if _failed > 0 else 0)


func _setup_mode(m: int) -> void:
	_t.dummy.set_mode(m)
	_p.global_position = Vector3(0, 0.1, 1.0)
	_e.global_position = Vector3(0, 0.1, -0.6)
	await _wait(60)
	_hits = 0
	_blocks = 0


func _press(action: String) -> void:
	await physics_frame
	_p.set_ai_input({action: true})
	await physics_frame
	_p.set_ai_input({})


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failed += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])
