class_name TrainingDummy
extends Node

## Training-mode opponent behaviour. Feeds a Fighter buffered inputs like AIController;
## CPU mode hands control to a real AIController.

enum Mode { STAND, BLOCK, BLOCK_AFTER_HIT, RANDOM_BLOCK, HOP, JAB, CPU, THROW_TECH, RANDOM_WAKEUP, THROW }

const NAMES := ["Stand", "Block", "Block after first hit", "Random block", "Hop", "Jab", "CPU",
	"Tech throws", "Random wakeup", "Throw"]
## Throw Tech mode presses J this many frames into the grab (inside Fighter.THROW_TECH_WINDOW).
const TECH_DELAY := 4
const WAKEUPS := [{}, {"x": -1.0}, {"x": 1.0}, {"y": -1.0}, {"block_held": true}]
const GUARD_HOLD := 0.9
const HOP_GAP := 0.9
const JAB_GAP := 1.1
const JAB_RANGE := 2.4
## Throw mode walks in to this distance, then throws every THROW_GAP seconds.
const THROW_GAP := 1.4

var fighter: Fighter
var mode: Mode = Mode.STAND
var cpu_profile: Dictionary = {}
var _ai: AIController
var _guard_left: float = 0.0
var _timer: float = 0.0
var _random_guard: bool = false
var _wakeup: Dictionary = {}
var _down: bool = false


func setup(f: Fighter, profile: Dictionary) -> void:
	fighter = f
	cpu_profile = profile
	f.got_hit.connect(_on_struck.unbind(2))
	f.blocked_hit.connect(_on_struck.unbind(1))


func set_mode(m: Mode) -> void:
	mode = m
	_guard_left = 0.0
	_timer = 0.0
	if m == Mode.CPU and _ai == null:
		_ai = AIController.new()
		add_child(_ai)
		_ai.setup(fighter, cpu_profile)
	elif m != Mode.CPU and _ai != null:
		_ai.queue_free()
		_ai = null
	if m != Mode.CPU:
		fighter.set_ai_input({})


func mode_name() -> String:
	return NAMES[mode]


func _on_struck() -> void:
	_guard_left = GUARD_HOLD


func _physics_process(delta: float) -> void:
	if fighter == null or fighter.opponent == null or mode == Mode.CPU:
		return
	if not fighter.is_stunned():
		_guard_left = maxf(_guard_left - delta, 0.0)
	_timer -= delta
	var inp := {}
	# Down: get up in place, except Random Wakeup, which picks a new option every knockdown.
	if fighter.state == Fighter.State.KNOCKDOWN:
		if not _down:
			_down = true
			_wakeup = WAKEUPS.pick_random() if mode == Mode.RANDOM_WAKEUP else {}
		fighter.set_ai_input(_wakeup)
		return
	_down = false
	if mode == Mode.THROW_TECH and fighter.state == Fighter.State.THROWN:
		fighter.set_ai_input({"light": fighter._state_frames == TECH_DELAY})
		return
	match mode:
		Mode.BLOCK:
			inp["block_held"] = true
		Mode.BLOCK_AFTER_HIT:
			if _guard_left > 0.0:
				inp["block_held"] = true
		Mode.RANDOM_BLOCK:
			if _timer <= 0.0:
				_random_guard = randf() < 0.5
				_timer = randf_range(0.25, 0.8)
			if _random_guard:
				inp["block_held"] = true
		Mode.HOP:
			if _timer <= 0.0 and fighter.is_on_floor():
				inp["hop"] = true
				_timer = HOP_GAP
		Mode.THROW:
			if fighter._distance_to_opponent() > Fighter.THROW_RANGE - 0.4:
				inp["y"] = 0.8
			elif _timer <= 0.0 and fighter.state in [Fighter.State.IDLE, Fighter.State.MOVE]:
				inp["block_held"] = true
				inp["light"] = true
				_timer = THROW_GAP
		Mode.JAB:
			if fighter._distance_to_opponent() > JAB_RANGE:
				inp["y"] = 0.8
			elif _timer <= 0.0:
				inp["light"] = true
				_timer = JAB_GAP
	fighter.set_ai_input(inp)
