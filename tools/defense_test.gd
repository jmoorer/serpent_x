extends SceneTree

# Defensive triangle checks in training mode with the dummy AI switched off: throws vs block /
# charge / jab, throw tech window, guard crush and regen, each wakeup option's timing and
# invulnerability, and Vanish cost / once-per-combo (exits 1 on failure).
# godot --headless --path . --fixed-fps 60 --script res://tools/defense_test.gd

var _failed: int = 0
var _p
var _e
var _t
var S
var _HP
var _p_in: Dictionary = {}
var _e_in: Dictionary = {}
var _seen: Dictionary = {}
var _teched: int = 0
var _crushes: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.training = true
	gs.player_loadout = &"turtle"
	change_scene_to_file("res://scenes/fight/fight.tscn")
	while current_scene == null or current_scene.name != "Fight" or current_scene.get("training") == null:
		await process_frame
	var fight := current_scene
	_t = fight.training
	_p = fight.player
	_e = fight.enemy
	S = _p.get_script()
	_HP = load("res://projectiles/hit_payload.gd")
	_p.is_player = false
	_t.dummy.set_physics_process(false)
	_t.infinite_ki = false
	_e.throw_teched.connect(func () -> void: _teched += 1)
	_p.throw_teched.connect(func () -> void: _teched += 1)
	_e.guard_crushed.connect(func () -> void: _crushes += 1)
	await _wait(5)

	await _case_throw_beats(S.State.BLOCK, {"block_held": true}, "block")
	await _case_throw_beats(S.State.CHARGE, {"charge_held": true}, "charge")
	await _case_throw_loses_to_jab()
	await _case_throw_whiff()
	await _case_throw_tech(4, true)
	await _case_throw_tech(S.THROW_TECH_WINDOW + 4, false)
	await _case_simultaneous_throws()
	await _case_guard_crush()
	await _case_guard_regen()
	await _case_wakeup(&"getup", {})
	await _case_wakeup(&"delay", {"block_held": true})
	await _case_wakeup(&"roll_left", {"x": -1.0})
	await _case_wakeup(&"roll_right", {"x": 1.0})
	await _case_wakeup(&"roll_back", {"y": -1.0})
	await _case_vanish()
	await _case_dummy_throw_mode()
	print("DONE  failures: %d" % _failed)
	quit(1 if _failed > 0 else 0)


# --- throws ----------------------------------------------------------------

func _case_throw_beats(want_state: int, hold: Dictionary, label: String) -> void:
	await _setup(1.4)
	_e_in = hold
	await _wait(6)
	var held_ok: bool = _e.state == want_state
	var hp0: float = _e.hp
	await _press_p({"block_held": true, "light": true})
	await _wait(70)
	_check(held_ok and _seen.has(S.State.THROWN) and _seen.has(S.State.KNOCKDOWN) and _e.hp < hp0,
		"throw beats %s (held %s, thrown %s, knockdown %s, hp %.0f->%.0f)" % [
			label, held_ok, _seen.has(S.State.THROWN), _seen.has(S.State.KNOCKDOWN), hp0, _e.hp])
	await _wait(130)


func _case_throw_loses_to_jab() -> void:
	await _setup(1.4)
	var p_hp0: float = _p.hp
	_e_in = {"light": true}
	await _press_p({"block_held": true, "light": true})
	_e_in = {}
	await _wait(40)
	_check(not _seen.has(S.State.THROWN) and _p.hp < p_hp0,
		"jab pressed on the same frame beats the throw (thrown %s, P hp %.0f->%.0f)" % [_seen.has(S.State.THROWN), p_hp0, _p.hp])
	await _wait(40)


func _case_throw_whiff() -> void:
	await _setup(3.0)
	await _press_p({"block_held": true, "light": true})
	var th = _p.moves[&"throw"]
	var total: int = th.startup + th.active + th.recovery
	var frames := 1
	while _p.state == S.State.THROW and frames < 120:
		await _wait(1)
		frames += 1
	_check(not _seen.has(S.State.THROWN) and absi(frames - total) <= 2,
		"out-of-range throw whiffs with %d recovery frames (took %d, want ~%d)" % [th.recovery, frames, total])


func _case_throw_tech(press_at: int, want_tech: bool) -> void:
	await _setup(1.4)
	_e_in = {"block_held": true}
	await _wait(4)
	var hp0: float = _e.hp
	await _press_p({"block_held": true, "light": true})
	var f := 0
	while _e.state != S.State.THROWN and f < 20:
		await _wait(1)
		f += 1
	var grabbed: bool = _e.state == S.State.THROWN
	for i in 40:
		_e_in = {"light": _e.state == S.State.THROWN and _e._state_frames == press_at - 1}
		await _wait(1)
	_e_in = {}
	await _wait(30)
	var teched := _teched > 0
	var ok: bool = grabbed and teched == want_tech and (_e.hp == hp0) == want_tech
	_check(ok, "J %d frames into the grab %s (grabbed %s, teched %s, hp %.0f->%.0f)" % [
		press_at, "techs the throw" if want_tech else "is too late to tech", grabbed, teched, hp0, _e.hp])
	await _wait(150)


func _case_simultaneous_throws() -> void:
	await _setup(1.4)
	_e_in = {"block_held": true, "light": true}
	await _press_p({"block_held": true, "light": true})
	_e_in = {}
	await _wait(40)
	_check(_teched > 0 and not _seen.has(S.State.THROWN) and not _p_was_thrown,
		"simultaneous throws auto-tech (teched %d)" % _teched)


# --- guard -----------------------------------------------------------------

func _case_guard_crush() -> void:
	await _setup(1.4)
	_e_in = {"block_held": true}
	await _wait(4)
	var h0 = _p.moves[&"H0"]
	var cost: float = S.GUARD_BASE_COST + h0.damage * S.GUARD_DAMAGE_COST
	var need := ceili(S.MAX_GUARD / cost)
	var crushed_on := -1
	for i in need + 1:
		_p.global_position = _e.global_position + _e.facing * 1.4
		await _wait(2)
		await _press_p({"heavy": true})
		await _wait(h0.startup + h0.active + h0.recovery + 4)
		if _crushes > 0:
			crushed_on = i + 1
			break
	var crush_state := _seen.has(S.State.GUARD_CRUSH)
	# Crushed: still holding block, but the next jab lands clean.
	var hits := [0]
	var count := func (_a, _d) -> void: hits[0] += 1
	_e.got_hit.connect(count)
	if _e.state == S.State.GUARD_CRUSH:
		_p.global_position = _e.global_position + _e.facing * 1.3
		await _press_p({"light": true})
		await _wait(12)
	_e.got_hit.disconnect(count)
	_check(crushed_on == need and crush_state and hits[0] == 1,
		"guard crush on blocked heavy #%d (want #%d, state %s, follow-up jab lands %d)" % [crushed_on, need, crush_state, hits[0]])
	_e_in = {}
	await _wait(80)


func _case_guard_regen() -> void:
	await _setup(1.4)
	_e_in = {"block_held": true}
	await _wait(4)
	await _press_p({"heavy": true})
	await _wait(40)
	var drained: float = _e.guard
	await _wait(60)
	var still_blocking: float = _e.guard
	_e_in = {}
	await _wait(S.GUARD_REGEN_DELAY - 5)
	var paused: float = _e.guard
	await _wait(240)
	_check(drained < S.MAX_GUARD and still_blocking == drained and paused == drained and _e.guard == S.MAX_GUARD,
		"guard holds while blocking, refills after the pause (%.0f, %.0f, %.0f -> %.0f)" % [drained, still_blocking, paused, _e.guard])


# --- wakeup ----------------------------------------------------------------

func _case_wakeup(want: StringName, hold: Dictionary) -> void:
	await _setup(1.4)
	_e_in = hold
	var kd = _HP.new()
	kd.owner_fighter = _p
	kd.damage = 5.0
	kd.hitstun = 20
	kd.knockback = 4.0
	kd.hit_tier = 2
	kd.effect = &"knockdown"
	_e.take_hit(kd)
	var start: Vector3 = _e.global_position
	var frames := 0
	var lie_end := -1
	var roll_start := -1
	var roll_pos := Vector3.ZERO
	var roll_right := Vector3.ZERO
	var roll_back := Vector3.ZERO
	var vuln_early := false
	var vuln_frames: Array[int] = []
	while _e.state != S.State.IDLE and frames < 260:
		await _wait(1)
		frames += 1
		if _e.state == S.State.KNOCKDOWN and not _e.invuln:
			vuln_early = true
		if _e.state == S.State.ROLL:
			if roll_start < 0:
				roll_start = frames
				roll_pos = _e.global_position
				roll_right = _e.facing.cross(Vector3.UP)
				roll_back = -_e.facing
			if not _e.invuln:
				vuln_frames.append(_e._state_frames)
	_e_in = {}
	var ok: bool = _e._wakeup == want and not vuln_early
	var detail := ""
	if String(want).begins_with("roll"):
		var moved: Vector3 = _e.global_position - roll_pos
		moved.y = 0.0
		var axis: Vector3 = {&"roll_left": -roll_right, &"roll_right": roll_right, &"roll_back": roll_back}[want]
		var first_vuln: int = vuln_frames[0] if not vuln_frames.is_empty() else -1
		ok = ok and roll_start > 0 and moved.dot(axis) > 1.5 and first_vuln == S.ROLL_INVULN \
			and vuln_frames.size() == S.ROLL_FRAMES - S.ROLL_INVULN
		detail = "moved %.2fm, vulnerable from roll frame %d (%d frames)" % [moved.dot(axis), first_vuln, vuln_frames.size()]
	else:
		var want_frames: int = S.KD_LIE_FRAMES + S.KD_GETUP_FRAMES + (S.WAKEUP_DELAY if want == &"delay" else 0)
		ok = ok and roll_start < 0 and absi(frames - want_frames) <= 8
		detail = "up after %d frames (want ~%d)" % [frames, want_frames]
	_check(ok, "wakeup %s: chose %s, invulnerable while down %s, %s" % [want, _e._wakeup, not vuln_early, detail])
	await _wait(20)
	if want == &"roll_back":
		await _case_roll_tail_punishable()


## Hits during a roll: whiff in the invulnerable part, land in the tail.
func _case_roll_tail_punishable() -> void:
	await _setup(1.4)
	_e_in = {"x": 1.0}
	var kd = _HP.new()
	kd.owner_fighter = _p
	kd.damage = 5.0
	kd.knockback = 4.0
	kd.hit_tier = 2
	kd.effect = &"knockdown"
	_e.take_hit(kd)
	var f := 0
	while _e.state != S.State.ROLL and f < 150:
		await _wait(1)
		f += 1
	var probe = _HP.new()
	probe.owner_fighter = _p
	probe.damage = 3.0
	probe.hitstun = 12
	probe.hit_tier = 1
	await _wait(4)
	var hp0: float = _e.hp
	_e.take_hit(probe)
	var early_whiff: bool = _e.hp == hp0 and _e.state == S.State.ROLL
	while _e.state == S.State.ROLL and _e._state_frames < S.ROLL_INVULN + 2:
		await _wait(1)
	var in_tail: bool = _e.state == S.State.ROLL
	_e.take_hit(probe)
	_e_in = {}
	_check(early_whiff and in_tail and _e.hp < hp0 and _e.state == S.State.HITSTUN,
		"roll is invulnerable early (whiffed %s) and punishable in the tail (hit %s)" % [early_whiff, _e.state == S.State.HITSTUN])
	await _wait(40)


# --- vanish ----------------------------------------------------------------

func _case_vanish() -> void:
	await _setup(1.4)
	_e.ki = 100.0
	_p_facing0 = _p.facing
	_hit_e(30)
	await _wait(3)
	_e_in = {"dash": true}
	await _wait(1)
	_e_in = {}
	var vanished: bool = _e.state == S.State.TECH and _e._move.id == &"vanish"
	var ki_after: float = _e.ki
	await _wait(10)
	var to_e: Vector3 = _e.global_position - _p.global_position
	to_e.y = 0.0
	var behind: bool = to_e.dot(_p_facing0) < 0.0
	await _wait(14)
	_check(vanished and ki_after == 50.0 and behind and _p.combo_count == 0,
		"Vanish in hitstun costs 50 ki and blinks behind (vanished %s, ki %.0f, behind %s)" % [vanished, ki_after, behind])

	# Same combo: hit again right away, a second Vanish is refused even with ki.
	_e.ki = 100.0
	_hit_e(30)
	await _wait(3)
	_e_in = {"dash": true}
	await _wait(1)
	_e_in = {}
	_check(_e.state == S.State.HITSTUN and _e.ki == 100.0, "second Vanish in the same combo is refused (state %d, ki %.0f)" % [_e.state, _e.ki])
	await _wait(40)

	# Not enough ki.
	await _wait(S.VANISH_LOCKOUT + 10)
	_e.ki = 40.0
	_hit_e(30)
	await _wait(3)
	_e_in = {"dash": true}
	await _wait(1)
	_e_in = {}
	_check(_e.state == S.State.HITSTUN and _e.ki == 40.0, "Vanish needs 50 ki (state %d, ki %.0f)" % [_e.state, _e.ki])
	await _wait(40)

	# A dash pressed just before the hit is not spent on a Vanish; after the lockout it works again.
	_e.ki = 100.0
	_e._buffer["dash"] = 0
	_hit_e(30)
	await _wait(3)
	var no_auto: bool = _e.state == S.State.HITSTUN and _e.ki == 100.0
	_e_in = {"dash": true}
	await _wait(1)
	_e_in = {}
	_check(no_auto and _e.state == S.State.TECH and _e.ki == 50.0,
		"pre-hit dash isn't spent; Vanish rearms after the lockout (no auto %s, state %d)" % [no_auto, _e.state])
	await _wait(40)


## Training dummy Throw mode walks in and grabs the idle player; the player can tech it.
func _case_dummy_throw_mode() -> void:
	await _setup(3.0)
	_t.dummy.set_physics_process(true)
	_t.dummy.set_mode(9)
	_dummy_drives = true
	var grabbed := false
	var teched_by_p := [0]
	var on_tech := func () -> void: teched_by_p[0] += 1
	_p.throw_teched.connect(on_tech)
	var f := 0
	while f < 200:
		_p_in = {"light": _p.state == S.State.THROWN and _p._state_frames == 3}
		await _wait(1)
		f += 1
		if _p.state == S.State.THROWN:
			grabbed = true
	_p.throw_teched.disconnect(on_tech)
	_t.dummy.set_mode(0)
	_t.dummy.set_physics_process(false)
	_dummy_drives = false
	_e.set_ai_input({})
	_check(grabbed and teched_by_p[0] >= 1,
		"dummy Throw mode walks in and grabs; player techs it (grabbed %s, techs %d)" % [grabbed, teched_by_p[0]])
	await _wait(30)


var _dummy_drives := false
var _p_facing0 := Vector3.ZERO
var _p_was_thrown := false


func _hit_e(hitstun: int) -> void:
	var h = _HP.new()
	h.owner_fighter = _p
	h.damage = 4.0
	h.hitstun = hitstun
	h.knockback = 1.0
	h.hit_tier = 1
	h.ki_gain = 0.0
	_e.take_hit(h)


# --- harness ---------------------------------------------------------------

func _setup(dist: float) -> void:
	_p_in = {}
	_e_in = {}
	_p.reset_to(Vector3(0, 0.1, 1.0))
	_e.reset_to(Vector3(0, 0.1, 1.0 - dist))
	await _wait(30)
	_seen.clear()
	_teched = 0
	_crushes = 0
	_p_was_thrown = false


func _press_p(inp: Dictionary) -> void:
	_p_in = inp
	await _wait(1)
	_p_in = {}


func _wait(frames: int) -> void:
	for i in frames:
		_p.set_ai_input(_p_in)
		if not _dummy_drives:
			_e.set_ai_input(_e_in)
		await physics_frame
		_seen[_e.state] = true
		if _p.state == S.State.THROWN:
			_p_was_thrown = true


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failed += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])
