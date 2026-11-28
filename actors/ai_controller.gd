class_name AIController
extends Node

## Feeds a Fighter the same buffered inputs a player would press.
## Offense is planned as a short button sequence (a string + optional ender).

const PRESS_GAP := 7

var fighter: Fighter
var profile: Dictionary = {}
var _plan: Array[String] = []
var _press_cd: int = 0
var _think: float = 0.0
var _block_left: float = 0.0
var _charge_left: float = 0.0
var _beam_hold: float = 0.0
var _strafe: float = 0.0
var _strafe_t: float = 0.0
## Decided once per knockdown / grab / hitstun entry.
var _wakeup_input: Dictionary = {}
var _kd_seen: bool = false
var _tech_at: int = -1
var _grab_seen: bool = false


func setup(f: Fighter, p: Dictionary) -> void:
	fighter = f
	profile = p


func _physics_process(delta: float) -> void:
	if fighter == null or fighter.opponent == null:
		return
	var inp := {}
	if not fighter.controllable or fighter.state == Fighter.State.DEAD:
		fighter.set_ai_input(inp)
		return

	_think -= delta
	_block_left = maxf(_block_left - delta, 0.0)
	_charge_left = maxf(_charge_left - delta, 0.0)
	_beam_hold = maxf(_beam_hold - delta, 0.0)
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe = [-1.0, 0.0, 0.0, 1.0].pick_random()
		_strafe_t = randf_range(0.6, 1.4)

	var opp := fighter.opponent
	var dist := fighter._distance_to_opponent()
	var st := fighter.state
	if fighter.is_stunned():
		_plan.clear()
		_charge_left = 0.0
		_beam_hold = 0.0

	if st == Fighter.State.KNOCKDOWN:
		if not _kd_seen:
			_kd_seen = true
			_wakeup_input = _pick_wakeup()
		fighter.set_ai_input(_wakeup_input)
		return
	_kd_seen = false

	if st == Fighter.State.THROWN:
		if not _grab_seen:
			_grab_seen = true
			var tech_skill: float = profile.get("tech_skill", float(profile.get("block_skill", 0.3)) * 1.1)
			_tech_at = randi_range(2, 9) if randf() < tech_skill else -1
		if fighter._state_frames == _tech_at:
			inp["light"] = true
		fighter.set_ai_input(inp)
		return
	_grab_seen = false

	if st == Fighter.State.HITSTUN and fighter._state_frames == 2 and fighter.can_vanish() and opp.combo_count >= 2:
		var vanish_chance: float = profile.get("vanish_chance", float(profile.get("block_skill", 0.3)) * 0.25)
		if randf() < vanish_chance:
			inp["dash"] = true
			fighter.set_ai_input(inp)
			return

	if _beam_hold > 0.0:
		inp["tech2_held"] = true
		if st == Fighter.State.TECH:
			fighter.set_ai_input(inp)
			return

	if not _plan.is_empty():
		_press_cd -= 1
		if _press_cd <= 0:
			var a: String = _plan.pop_front()
			if a == "heavy" and opp.state in [Fighter.State.BLOCK, Fighter.State.BLOCKSTUN]:
				if dist < Fighter.THROW_RANGE - 0.1 and randf() < _throw_chance():
					_press_throw(inp)
				elif randf() < 0.6:
					_plan.clear()
				else:
					inp[a] = true
			elif a == "throw":
				_press_throw(inp)
			else:
				inp[a] = true
			_press_cd = PRESS_GAP
		fighter.set_ai_input(inp)
		return

	var threat := opp.state in [Fighter.State.ATTACK, Fighter.State.TECH] and dist < 3.6
	var block_odds := float(profile.get("block_skill", 0.3)) * 0.35
	if fighter.guard < Fighter.MAX_GUARD * 0.35:
		block_odds *= 0.5
	if threat and _block_left <= 0.0 and randf() < block_odds:
		_block_left = randf_range(0.3, 0.55)
	if _block_left > 0.0:
		inp["block_held"] = true
		fighter.set_ai_input(inp)
		return

	if _charge_left > 0.0:
		if dist < 5.0:
			_charge_left = 0.0
		else:
			inp["charge_held"] = true
			fighter.set_ai_input(inp)
			return

	if _opponent_whiffed() and dist < 2.6:
		_plan = ["light", "light", "heavy"]
		_press_cd = 0
		fighter.set_ai_input(inp)
		return

	var aggression: float = profile.get("aggression", 0.5)
	if dist > 6.5:
		inp["y"] = 1.0
		inp["x"] = _strafe * 0.4
		if _think <= 0.0:
			_think = 0.5
			if profile.get("uses_charge", false) and fighter.ki < 45.0 and randf() < 0.35:
				_charge_left = randf_range(0.8, 1.5)
			elif profile.get("uses_tech2", false) and fighter.ki >= 25.0 and randf() < float(profile.get("tech_chance", 0.2)):
				inp["tech2"] = true
				if randf() < float(profile.get("beam_charge", 0.5)):
					_beam_hold = randf_range(0.4, 1.3)
			elif randf() < aggression * 0.5:
				inp["dash"] = true
	elif dist > 2.0:
		inp["y"] = 0.7
		inp["x"] = _strafe * 0.6
		if _think <= 0.0:
			_think = 0.35
			if profile.get("uses_tech2", false) and fighter.ki >= 25.0 and dist > 4.0 and randf() < float(profile.get("tech_chance", 0.2)) * 0.5:
				inp["tech2"] = true
			elif randf() < aggression * 0.35:
				_plan = ["dash", "light", "light"]
				_press_cd = 0
	else:
		inp["x"] = _strafe * 0.5
		var turtling := opp.state in [Fighter.State.BLOCK, Fighter.State.CHARGE]
		if turtling and dist > Fighter.THROW_RANGE - 0.2:
			inp["y"] = 0.8
		if _think <= 0.0:
			_think = randf_range(0.2, 0.45)
			if turtling and dist < Fighter.THROW_RANGE - 0.1 and randf() < _throw_chance():
				_plan.assign(["throw"])
				_press_cd = 0
			elif randf() < aggression:
				_plan = _make_string()
				_press_cd = 0
			elif randf() < 0.3:
				inp["y"] = -1.0
	fighter.set_ai_input(inp)


func _make_string() -> Array[String]:
	var plan: Array[String] = []
	var tech_chance: float = profile.get("tech_chance", 0.2)
	var can_blast: bool = profile.get("uses_tech2", false) and fighter.ki >= 25.0
	if randf() < float(profile.get("air_chance", 0.0)):
		plan.assign(["light", "heavy", "hop", "light", "light", ["light", "heavy"].pick_random()])
		return plan
	if randf() < 0.18:
		plan.append("heavy")
		if can_blast and randf() < tech_chance * 2.0:
			plan.append("tech2")
		return plan
	var n := randi_range(1, int(profile.get("string_len", 2)))
	if can_blast and randf() < tech_chance:
		n = 1
	for i in n:
		plan.append("light")
	if profile.get("uses_afterimage", false) and fighter.ki >= 20.0 and randf() < tech_chance:
		plan.append("tech1")
		plan.append("light")
		plan.append("light")
	elif randf() < 0.5:
		plan.append("heavy")
	if profile.get("uses_rush", false) and fighter.ki >= 45.0 and randf() < tech_chance:
		plan.append("tech3")
	elif can_blast and n == 1 and plan.back() == "heavy":
		plan.append("tech2")
	return plan


func _throw_chance() -> float:
	return profile.get("throw_chance", float(profile.get("aggression", 0.5)) * 0.6)


func _press_throw(inp: Dictionary) -> void:
	inp["block_held"] = true
	inp["light"] = true


func _pick_wakeup() -> Dictionary:
	match randi() % 5:
		0:
			return {"x": -1.0}
		1:
			return {"x": 1.0}
		2:
			return {"y": -1.0}
		3:
			return {"block_held": true}
	return {}


func _opponent_whiffed() -> bool:
	var o := fighter.opponent
	if o.state != Fighter.State.ATTACK or o._move == null:
		return false
	return not o._connected and o._attack_frame > o._move.startup + o._move.active + 2
