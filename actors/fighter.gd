class_name Fighter
extends CharacterBody3D

signal hit_landed(target: Fighter, move_id: StringName)
signal got_hit(attacker: Fighter, damage: float)
signal blocked_hit(attacker: Fighter)
signal clashed(other: Fighter)
signal died
signal ki_changed(value: float)
signal hp_changed(value: float)
signal combo_changed(hits: int)
signal technique_used(display_name: String)

enum State { IDLE, MOVE, ATTACK, BLOCK, HITSTUN, BLOCKSTUN, DASH, TECH, DEAD, KNOCKDOWN, CHARGE }

const WALK_SPEED := 5.5
const STRAFE_SPEED := 5.0
const DASH_SPEED := 15.0
const DASH_FRAMES := 11
const DASH_RECOVERY := 7
const HOP_VELOCITY := 8.0
const MAX_KI := 100.0
const CHARGE_RATE := 30.0
const ARENA_HALF := 10.4
const COMBO_CAP := 12
const BUFFER_FRAMES := 9
const KD_LIE_FRAMES := 48
const KD_GETUP_FRAMES := 66
const AFTERIMAGE_BLINK := 6
const RUSH_DASH_MAX := 18
const POP_VELOCITY := 9.0
const CHASE_VELOCITY := 11.0
const CHASE_MAX_SPEED := 14.0
const JUGGLE_LIFT := 4.0
const JUGGLE_DECAY := 0.08
const JUGGLE_LAND_STUN := 10
const SPIKE_VELOCITY := 18.0
const BOUNCE_VELOCITY := 8.0
const AIR_LAND_LAG := 6
const BUFFERED := ["light", "heavy", "dash", "hop", "tech1", "tech2", "tech3"]
const HIT_COLOR := Color(1.0, 0.85, 0.45)
const BLOCK_COLOR := Color(0.45, 0.7, 1.0)

@export var is_player: bool = false
@export var team: int = 0
@export var max_hp: float = 100.0
@export var display_name: String = "Fighter"

var hp: float = 100.0
var ki: float = 0.0
var state: State = State.IDLE
var facing: Vector3 = Vector3(0, 0, -1)
var opponent: Fighter
var confirm_ready: bool = false
var combo_count: int = 0
var invuln: bool = false
## Training: HP never drops below 1.
var immortal: bool = false
var controllable: bool = false
var style: StringName = &"turtle"
var aura_color: Color = Color(1.0, 0.85, 0.3)
var moves: Dictionary = {}
var speed_mult: float = 1.0
var power: float = 1.0

var _state_frames: int = 0
var _attack_frame: int = 0
var _move: MoveData
var _speed_after_impact: float = 1.0
var _connected: bool = false
var _landed_hit: bool = false
var _hit_active: bool = false
var _stun_total: int = 0
var _airborne_stun: bool = false
var _knock_vel: Vector3 = Vector3.ZERO
var _dash_dir: Vector3 = Vector3.ZERO
var _string_hits: int = 0
var _rush_seg: int = -1
var _rush_frame: int = 0
var _getting_up: bool = false
var _rush_segs: Array = Moveset.RUSH
var _armor_left: int = 0
var _daze_left: int = 0
var _ai_input: Dictionary = {}
var _buffer: Dictionary = {}
var _aura: CPUParticles3D
var _idle_clip: StringName = &"idle_turtle"
## One air string per jump; refilled on the floor.
var _air_moves_left: int = 1
var _juggle_hits: int = 0
var _spiked: bool = false
var _bounced: bool = false
## Spike bounce in progress: hittable while it lasts.
var _bouncing: bool = false

@onready var model: FighterModel = $Model
@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox


func _ready() -> void:
	hp = max_hp
	hurtbox.setup(self)
	if model.body == null:
		setup_look(&"y", style, Color(0.6, 0.6, 0.7), Color(0.3, 0.3, 0.35), aura_color)


func setup_look(body_id: StringName, style_id: StringName, main: Color, accent: Color, aura: Color,
		techs: StringName = &"turtle") -> void:
	style = style_id
	aura_color = aura
	moves = Moveset.build(style, techs)
	_idle_clip = Moveset.idle_clip(style)
	model.build(body_id, main, accent)
	if _aura:
		_aura.queue_free()
	_aura = Fx.make_aura(self, aura)
	model.play(_idle_clip, 0.0)


func set_ai_input(inp: Dictionary) -> void:
	_ai_input = inp


# --- main loop -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_tick_buffer()
	_tick_armor()
	_daze_left = maxi(_daze_left - 1, 0)
	if is_on_floor() and velocity.y <= 0.0:
		_air_moves_left = 1
	if state != State.DEAD and state != State.KNOCKDOWN:
		_face_opponent()
	_apply_gravity(delta)
	_tick_state(delta)
	move_and_slide()
	_clamp_arena()
	_update_locomotion_anim()


func _face_opponent() -> void:
	if opponent == null or not is_instance_valid(opponent):
		return
	var to := opponent.global_position - global_position
	to.y = 0.0
	if to.length() > 0.05:
		facing = to.normalized()
		look_at(global_position + facing, Vector3.UP)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0


func _tick_state(delta: float) -> void:
	_state_frames += 1
	match state:
		State.IDLE, State.MOVE, State.BLOCK:
			_handle_actionable()
		State.CHARGE:
			_tick_charge(delta)
		State.DASH:
			_tick_dash()
		State.ATTACK:
			_tick_attack()
		State.TECH:
			_tick_tech()
		State.HITSTUN:
			_tick_hitstun()
		State.BLOCKSTUN:
			_decay_knock(25.0)
			if _state_frames >= _stun_total:
				_enter(State.IDLE)
		State.KNOCKDOWN:
			_tick_knockdown()
		State.DEAD:
			_decay_knock(14.0)


func _enter(s: State) -> void:
	state = s
	_state_frames = 0
	_spiked = false
	_bouncing = false


# --- input -----------------------------------------------------------------

func _tick_buffer() -> void:
	for a: String in BUFFERED:
		if _pressed_raw(a):
			_buffer[a] = 0
		elif _buffer.has(a):
			_buffer[a] += 1
			if _buffer[a] > BUFFER_FRAMES:
				_buffer.erase(a)


func _take(action: String) -> bool:
	if not controllable or not _buffer.has(action):
		return false
	_buffer.erase(action)
	return true


func _peek(action: String) -> bool:
	return controllable and _buffer.has(action)


func _pressed_raw(action: String) -> bool:
	if is_player:
		return Input.is_action_just_pressed(action)
	return bool(_ai_input.get(action, false))


func _held(action: String) -> bool:
	if not controllable:
		return false
	if is_player:
		return Input.is_action_pressed(action)
	return bool(_ai_input.get(action + "_held", false))


## Forward = toward the opponent, right = strafe around them.
func _move_dir() -> Vector3:
	var v := Vector2.ZERO
	if not controllable:
		return Vector3.ZERO
	if is_player:
		v.x = Input.get_axis("move_left", "move_right")
		v.y = Input.get_axis("move_back", "move_forward")
	else:
		v.x = float(_ai_input.get("x", 0.0))
		v.y = float(_ai_input.get("y", 0.0))
	if v.length() > 1.0:
		v = v.normalized()
	var right := facing.cross(Vector3.UP)
	return facing * v.y + right * v.x


# --- neutral ---------------------------------------------------------------

func _handle_actionable() -> void:
	if not controllable:
		_stop_xz(WALK_SPEED)
		return
	if _held("charge") and is_on_floor() and ki < MAX_KI:
		_enter(State.CHARGE)
		_stop_xz(100.0)
		model.play(&"charge", 0.15)
		_aura.emitting = true
		if is_player:
			Sfx.set_charging(true)
		return
	if _held("block") and is_on_floor():
		if state != State.BLOCK:
			_enter(State.BLOCK)
			model.play(&"block", 0.08, 1.0, false)
		_stop_xz(100.0)
		if _peek("tech1") and try_technique(&"tech1"):
			_take("tech1")
		return
	if state == State.BLOCK:
		_enter(State.IDLE)

	if is_on_floor() and _take("hop"):
		velocity.y = HOP_VELOCITY
		model.play(&"air", 0.12)
	if is_on_floor() and _take("dash"):
		_start_dash()
		return
	for t: String in ["tech3", "tech2", "tech1"]:
		if _peek(t):
			_take(t)
			if try_technique(StringName(t)):
				return
	if _is_airborne():
		if _air_moves_left > 0:
			if _take("heavy"):
				_start_air_move(moves[&"AH"])
				return
			if _take("light"):
				_start_air_move(moves[&"AL1"])
				return
	elif _take("heavy"):
		_start_move(moves[&"H0"])
		return
	elif _take("light"):
		_start_move(moves[&"L1"])
		return

	var dir := _move_dir()
	if dir.length() > 0.1:
		if state != State.MOVE:
			_enter(State.MOVE)
		var fwd := dir.dot(facing)
		var speed := (WALK_SPEED if absf(fwd) >= 0.7 else STRAFE_SPEED) * speed_mult
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		if is_on_floor():
			_stop_xz(WALK_SPEED * 0.5)
		if state != State.IDLE:
			_enter(State.IDLE)


func _stop_xz(rate: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, rate)
	velocity.z = move_toward(velocity.z, 0.0, rate)


func _update_locomotion_anim() -> void:
	if state != State.IDLE and state != State.MOVE:
		return
	if not is_on_floor():
		model.play(&"air", 0.15, 1.0, false)
		return
	var right := facing.cross(Vector3.UP)
	var local := Vector2(velocity.dot(right), velocity.dot(facing))
	if local.length() < 0.6:
		model.play(_idle_clip, 0.2, 1.0, false)
		return
	var clip: StringName
	if absf(local.y) >= absf(local.x):
		clip = &"walk_f" if local.y > 0.0 else &"walk_b"
	else:
		clip = &"walk_r" if local.x > 0.0 else &"walk_l"
	model.play(clip, 0.15, clampf(local.length() / 3.2, 0.8, 1.9), false)


func _tick_charge(delta: float) -> void:
	_stop_xz(100.0)
	if not _held("charge") or ki >= MAX_KI:
		_stop_charge()
		_enter(State.IDLE)
		return
	ki = minf(ki + CHARGE_RATE * delta, MAX_KI)
	ki_changed.emit(ki)
	if _state_frames % 20 == 0:
		Fx.shockwave(global_position + Vector3.UP * 0.05, aura_color, 1.6, 0.5)


func _stop_charge() -> void:
	_aura.emitting = false
	if is_player:
		Sfx.set_charging(false)


# --- dash ------------------------------------------------------------------

func _start_dash() -> void:
	var dir := _move_dir()
	if dir.length() < 0.1:
		dir = facing
	_dash_dir = dir.normalized()
	var right := facing.cross(Vector3.UP)
	var f := _dash_dir.dot(facing)
	var r := _dash_dir.dot(right)
	var clip := &"dash_f"
	if absf(r) > absf(f):
		clip = &"dash_r" if r > 0.0 else &"dash_l"
	elif f < 0.0:
		clip = &"dash_b"
	model.play(clip, 0.05, 1.7)
	model.spawn_ghost(aura_color, 0.3)
	Sfx.play(&"whoosh", -6.0)
	_enter(State.DASH)


func _tick_dash() -> void:
	if _state_frames <= DASH_FRAMES:
		var k := 1.0 - 0.4 * float(_state_frames) / DASH_FRAMES
		velocity.x = _dash_dir.x * DASH_SPEED * speed_mult * k
		velocity.z = _dash_dir.z * DASH_SPEED * speed_mult * k
		if _state_frames == DASH_FRAMES / 2:
			model.spawn_ghost(aura_color, 0.25)
		if _take("light"):
			_start_move(moves[&"DL"])
			return
		if _take("heavy"):
			_start_move(moves[&"H0"])
			return
	elif _state_frames <= DASH_FRAMES + DASH_RECOVERY:
		_stop_xz(3.0)
	else:
		_enter(State.IDLE)


# --- attacks ---------------------------------------------------------------

func _start_move(m: MoveData, state_override: State = State.ATTACK) -> void:
	_move = m
	_attack_frame = 0
	_connected = false
	_landed_hit = false
	_hit_active = false
	hitbox.disarm()
	_enter(state_override)
	_play_timed(m.clip, m.startup, m.active + m.recovery)
	Sfx.play(&"whoosh_big" if m.tier >= 2 else &"whoosh", -9.0)
	if m.callout != "":
		technique_used.emit(m.callout)
	velocity.x *= 0.2
	velocity.z *= 0.2


## Time-warps a clip so its impact lands on `startup` frames, then plays the follow-through
## over the remaining frames (or blends out early).
func _play_timed(clip: StringName, startup_frames: int, after_frames: int) -> void:
	var impact := model.clip_impact(clip)
	var length := model.clip_length(clip)
	var pre := clampf(impact / maxf(startup_frames / 60.0, 0.016), 0.6, 3.2)
	_speed_after_impact = clampf((length - impact) / maxf(after_frames / 60.0, 0.05), 0.9, 2.0)
	model.play(clip, 0.05, pre)


func _tick_attack() -> void:
	_attack_frame += 1
	var m := _move
	if m.air:
		if is_on_floor() and velocity.y <= 0.0 and _attack_frame > 3:
			_enter_recovery(AIR_LAND_LAG)
			model.play(_idle_clip, 0.1)
			return
		_air_track(m)
	_apply_lunge(m)
	if _attack_frame == m.startup:
		model.set_speed(_speed_after_impact)
		if m.kind != &"blast":
			hitbox.arm(self, m)
			_hit_active = true
	if _attack_frame == m.startup + m.active:
		hitbox.disarm()
		_hit_active = false
	if _try_cancels():
		return
	if _attack_frame >= m.startup + m.active + m.recovery:
		_end_action()


func _apply_lunge(m: MoveData) -> void:
	if m.lunge > 0.0 and _attack_frame <= m.startup + m.active and _distance_to_opponent() > 1.2:
		velocity.x = facing.x * m.lunge
		velocity.z = facing.z * m.lunge
	else:
		_stop_xz(1.5)


func _try_cancels() -> bool:
	var m := _move
	var chain_ok := (_connected and _attack_frame >= m.startup) or _attack_frame >= m.startup + m.active + 3
	if not chain_ok:
		return false
	if m.effect == &"pop" and _landed_hit and _take("hop"):
		_chase_jump()
		return true
	if m.chain_light != &"" and _take("light"):
		_start_move(moves[m.chain_light])
		return true
	if m.chain_heavy != &"" and _take("heavy"):
		_start_move(moves[m.chain_heavy])
		return true
	if _connected:
		for t: String in m.cancel_tech:
			if _peek(t) and try_technique(StringName(t)):
				_take(t)
				return true
	return false


func _end_action() -> void:
	invuln = false
	hitbox.disarm()
	_hit_active = false
	model.set_visible_body(true)
	_stop_xz(100.0)
	_enter(State.IDLE)
	model.play(_idle_clip, 0.15)


## Recovery-only move handled by the generic attack tick (rush tail, air landing lag).
func _enter_recovery(frames: int) -> void:
	hitbox.disarm()
	_hit_active = false
	var rec := MoveData.new()
	rec.startup = 0
	rec.active = 0
	rec.recovery = frames
	_move = rec
	_attack_frame = 0
	_connected = false
	_enter(State.ATTACK)


# --- air -------------------------------------------------------------------

func _is_airborne() -> bool:
	return not is_on_floor() or velocity.y > 0.5


## Can be chased in the air: airborne hitstun or a spike bounce.
func is_juggled() -> bool:
	return (state == State.HITSTUN and _airborne_stun) or _bouncing


func _start_air_move(m: MoveData) -> void:
	_air_moves_left -= 1
	_start_move(m)


## Holds the attacker level with a juggled target through the swing, and keeps floating with
## them after a connect (except off a spike, so the attacker drops for the bounce).
func _air_track(m: MoveData) -> void:
	if opponent == null or not opponent.is_juggled():
		return
	var swinging := _attack_frame <= m.startup + m.active
	if not swinging and not (_connected and m.effect != &"spike"):
		return
	var dy := opponent.global_position.y - 0.15 - global_position.y
	velocity.y = clampf(opponent.velocity.y + dy * 10.0, -10.0, 12.0)


## Hop-cancel off a landed launcher: leap toward the target with one air string ready.
func _chase_jump() -> void:
	hitbox.disarm()
	_hit_active = false
	_enter(State.IDLE)
	_air_moves_left = 1
	var to := facing
	if opponent:
		to = opponent.global_position - global_position
		to.y = 0.0
	var gap := maxf(to.length() - 1.1, 0.0)
	var dir := to.normalized() if to.length() > 0.01 else facing
	var speed := minf(gap / 0.3, CHASE_MAX_SPEED)
	velocity = Vector3(dir.x * speed, CHASE_VELOCITY, dir.z * speed)
	model.play(&"air", 0.08)
	model.spawn_ghost(aura_color, 0.35)
	Fx.shockwave(global_position + Vector3.UP * 0.05, aura_color, 1.8, 0.3)
	Sfx.play(&"whoosh_big", -6.0)


# --- techniques ------------------------------------------------------------

func try_technique(id: StringName) -> bool:
	var t: MoveData = moves.get(id)
	if t == null or ki < t.ki_cost:
		return false
	if t.requires_confirm and not confirm_ready:
		return false
	if state in [State.HITSTUN, State.BLOCKSTUN, State.DEAD, State.KNOCKDOWN]:
		return false
	if state == State.CHARGE:
		_stop_charge()
	ki = maxf(ki - t.ki_cost, 0.0)
	ki_changed.emit(ki)
	technique_used.emit(t.display_name)
	_move = t
	_attack_frame = 0
	_connected = false
	_landed_hit = false
	_hit_active = false
	hitbox.disarm()
	_enter(State.TECH)
	_aura.restart()
	_aura.emitting = true
	get_tree().create_timer(0.35).timeout.connect(_end_aura_burst)
	match t.kind:
		&"afterimage":
			model.spawn_ghost(aura_color, 0.7)
			model.set_visible_body(false)
			invuln = true
			Sfx.play(&"teleport")
			Fx.flash_sphere(global_position + Vector3.UP, aura_color, 1.6, 0.2)
		&"blast":
			_play_timed(t.clip, t.startup, t.active + t.recovery)
			model.flash(t.proj_color, 0.25, 1.2)
			Sfx.play(&"kiai", -4.0)
		&"flare":
			model.play(t.clip, 0.08, 1.6)
			model.flash(Color.WHITE, 0.3, 1.5)
			Sfx.play(&"whoosh_big", -8.0)
		&"counter":
			model.play(t.clip, 0.05, 1.4)
			model.flash(aura_color, 0.15, 1.2)
			Sfx.play(&"whoosh", -8.0)
		&"armor":
			model.play(t.clip, 0.08, 1.4)
			Sfx.play(&"kiai", -2.0)
		&"quake":
			_play_timed(t.clip, t.startup, t.active + t.recovery)
			model.flash(aura_color, 0.3, 1.2)
			Sfx.play(&"kiai", -4.0)
		&"rush":
			confirm_ready = false
			_rush_seg = -1
			_rush_frame = 0
			_rush_segs = t.segments if not t.segments.is_empty() else Moveset.RUSH
			invuln = true
			model.play(&"dash_f", 0.04, 2.0)
			model.flash(aura_color, 0.3, 1.5)
			Sfx.play(&"kiai")
			Sfx.play(&"whoosh_big")
			Feedback.zoom_punch(0.6)
	return true


func _end_aura_burst() -> void:
	if state != State.CHARGE:
		_aura.emitting = false


func _tick_tech() -> void:
	var t := _move
	match t.kind:
		&"afterimage":
			_attack_frame += 1
			if _attack_frame == AFTERIMAGE_BLINK:
				_blink_behind_opponent()
				_play_timed(t.clip, t.startup - AFTERIMAGE_BLINK, t.active + t.recovery)
			if _attack_frame == t.startup:
				invuln = false
			if _attack_frame < AFTERIMAGE_BLINK:
				_stop_xz(100.0)
				return
			_attack_frame -= 1
			_tick_attack()
		&"blast":
			_attack_frame += 1
			_stop_xz(100.0)
			if _attack_frame == t.startup:
				model.set_speed(_speed_after_impact)
				_spawn_ki_blast(t)
			if _attack_frame >= t.startup + t.active + t.recovery:
				_end_action()
		&"rush":
			_tick_rush()
		&"flare", &"counter", &"armor", &"quake":
			_attack_frame += 1
			_stop_xz(100.0)
			if _attack_frame == t.startup:
				match t.kind:
					&"flare":
						_solar_flare(t)
					&"counter":
						model.flash(Color.WHITE, 0.06, 2.5)
					&"armor":
						_start_armor(t)
					&"quake":
						model.set_speed(_speed_after_impact)
						_earth_splitter(t)
			if _attack_frame >= t.startup + t.active + t.recovery:
				_end_action()


func _solar_flare(t: MoveData) -> void:
	var head := global_position + Vector3.UP * 1.6 + facing * 0.3
	Fx.flash_sphere(head, Color(1, 1, 0.92), 4.0, 0.3)
	Fx.flash_sphere(head, Color.WHITE, 2.5, 0.2)
	Fx.shockwave(head, Color(1, 1, 0.85), 4.0, 0.3, facing)
	Sfx.play(&"teleport", 2.0, 0.0)
	Sfx.play(&"shock_small", -4.0)
	Feedback.zoom_punch(0.5)
	if opponent == null or opponent.invuln or opponent.state in [State.DEAD, State.KNOCKDOWN]:
		return
	var to_me := global_position - opponent.global_position
	to_me.y = 0.0
	if to_me.length() > t.reach or opponent.facing.dot(to_me.normalized()) < 0.3:
		return
	opponent.apply_daze(self, t.duration)


## Blinded: unblockable stun that keeps lasting through follow-up hits.
func apply_daze(attacker: Fighter, frames: int) -> void:
	if state == State.CHARGE:
		_stop_charge()
	hitbox.disarm()
	_hit_active = false
	invuln = false
	model.set_visible_body(true)
	_daze_left = frames
	_stun_total = frames
	_knock_vel = Vector3.ZERO
	_airborne_stun = false
	_enter(State.HITSTUN)
	model.play(&"dizzy", 0.1, 1.2)
	model.flash(Color.WHITE, 0.35, 4.0)
	technique_used.emit("Blinded")
	if attacker:
		attacker.confirm_ready = true


func _start_armor(t: MoveData) -> void:
	_armor_left = t.duration
	model.flash(Color(1.0, 0.8, 0.35), 0.25, 2.5)
	Fx.shockwave(global_position + Vector3.UP * 0.05, aura_color, 3.0, 0.4)
	Fx.flash_sphere(global_position + Vector3.UP, aura_color, 2.2, 0.25)
	Sfx.play(&"shock_small", -3.0)


func _tick_armor() -> void:
	if _armor_left <= 0:
		return
	_armor_left -= 1
	_aura.emitting = _armor_left > 0 or state == State.CHARGE
	if _armor_left % 24 == 0:
		model.flash(Color(1.0, 0.75, 0.3), 0.08, 1.2)


func _earth_splitter(t: MoveData) -> void:
	var ground := global_position + Vector3.UP * 0.05
	Fx.shockwave(ground, aura_color, t.reach, 0.45)
	Fx.shockwave(ground, Color(0.85, 0.65, 0.4), t.reach * 0.6, 0.3)
	for k in 10:
		var a := TAU * k / 10.0
		Fx.spark(ground + Vector3(cos(a), 0.2, sin(a)) * t.reach * 0.55, Color(0.8, 0.6, 0.35), 1)
	Sfx.play(&"shock_big", -2.0)
	Feedback.pulse(2)
	if opponent == null or not opponent.is_on_floor() or _distance_to_opponent() > t.reach:
		return
	var p := HitPayload.new()
	p.owner_fighter = self
	p.move_id = t.id
	p.damage = t.damage
	p.hitstun = 30
	p.blockstun = 12
	p.knockback = t.knockback
	p.ki_gain = t.ki_gain
	p.hit_tier = t.tier
	p.effect = t.effect
	p.unblockable = t.unblockable
	opponent.take_hit(p)


func _in_counter_window() -> bool:
	return state == State.TECH and _move != null and _move.kind == &"counter" \
		and _attack_frame >= _move.startup and _attack_frame < _move.startup + _move.active


func _do_counter(attacker: Fighter) -> void:
	var mid := global_position + Vector3.UP * 1.3 + facing * 0.5
	Fx.flash_sphere(mid, Color.WHITE, 2.0, 0.15)
	Fx.shockwave(mid, aura_color, 2.5, 0.3, facing)
	Sfx.play(&"clash")
	Feedback.pulse(2)
	technique_used.emit("Counter")
	if attacker == null or _distance_to_opponent() > 3.5:
		_end_action()
		return
	attacker.hitbox.disarm()
	attacker._hit_active = false
	attacker.invuln = false
	attacker.model.set_visible_body(true)
	attacker._stun_total = 24
	attacker._knock_vel = Vector3.ZERO
	attacker._enter(State.HITSTUN)
	attacker.model.play(&"hit_light", 0.04, 1.2)
	_start_move(moves[&"counter_hit"])


func _blink_behind_opponent() -> void:
	if opponent == null:
		return
	var through := opponent.global_position - global_position
	through.y = 0.0
	var dir := through.normalized() if through.length() > 0.1 else facing
	var target := opponent.global_position + dir * 1.25
	if absf(target.x) > ARENA_HALF or absf(target.z) > ARENA_HALF:
		target = opponent.global_position - dir * 1.25
	target.y = global_position.y
	global_position = target
	_face_opponent()
	model.set_visible_body(true)
	Fx.flash_sphere(global_position + Vector3.UP, aura_color, 1.8, 0.2)
	Sfx.play(&"teleport", -3.0)


func _spawn_ki_blast(t: MoveData) -> void:
	var blast := preload("res://projectiles/ki_blast.tscn").instantiate() as KiBlast
	get_parent().add_child(blast)
	blast.global_position = global_position + Vector3(0, 1.25, 0) + facing * 0.9
	blast.setup(self, facing, t)
	Sfx.play(&"blast", 0.0 if t.proj_scale >= 1.0 else -3.0)
	Fx.flash_sphere(blast.global_position, t.proj_color, 1.4 * maxf(t.proj_scale, 0.6), 0.15)
	Feedback.pulse(1)


func _tick_rush() -> void:
	_rush_frame += 1
	if _rush_seg < 0:
		var d := _distance_to_opponent()
		if d > 1.3 and _rush_frame < RUSH_DASH_MAX:
			velocity.x = facing.x * 24.0
			velocity.z = facing.z * 24.0
			if _rush_frame % 3 == 0:
				model.spawn_ghost(aura_color, 0.3)
			return
		invuln = false
		_next_rush_segment()
		return
	_stop_xz(100.0)
	var seg: Array = _rush_segs[_rush_seg]
	var frames: int = seg[1]
	var strike := int(frames * 0.55)
	if _rush_frame == strike:
		model.set_speed(_speed_after_impact)
		var finisher := _rush_seg == _rush_segs.size() - 1
		hitbox.arm_custom(self, &"tech3", seg[2], 40 if not finisher else 30, 12, 0.6 if not finisher else 12.0, 3.0,
			Vector3(1.1, 1.2, 1.3), Vector3(0, 1.2, -0.9), 3 if finisher else 2, seg[3])
		_hit_active = true
	if _rush_frame == strike + 2:
		hitbox.disarm()
		_hit_active = false
	if _rush_frame >= frames:
		if _rush_seg == 0 and not _landed_hit:
			_finish_rush()
			return
		if _rush_seg >= _rush_segs.size() - 1:
			_finish_rush()
			return
		_next_rush_segment()


func _next_rush_segment() -> void:
	_rush_seg += 1
	_rush_frame = 0
	var seg: Array = _rush_segs[_rush_seg]
	var frames: int = seg[1]
	_play_timed(seg[0], int(frames * 0.55), frames - int(frames * 0.55) + 6)
	Sfx.play(&"whoosh", -8.0)


func _finish_rush() -> void:
	_rush_seg = -1
	_enter_recovery(moves[&"tech3"].recovery)


# --- getting hit -----------------------------------------------------------

func take_hit(src: Object) -> void:
	if state == State.DEAD or invuln:
		return
	var attacker: Fighter = src.get("owner_fighter") as Fighter
	var damage: float = float(src.get("damage"))
	var hitstun: int = int(src.get("hitstun"))
	var blockstun: int = int(src.get("blockstun"))
	var knockback: float = float(src.get("knockback"))
	var tier: int = int(src.get("hit_tier"))
	var effect: StringName = src.get("effect") as StringName
	var move_id: StringName = src.get("move_id") as StringName
	var ki_gain: float = float(src.get("ki_gain"))
	var away := -facing
	var hit_pos := global_position + Vector3.UP * 1.25
	if attacker:
		away = global_position - attacker.global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else -facing
		hit_pos = global_position + Vector3.UP * 1.25 - away * 0.35

	if _in_counter_window():
		_do_counter(attacker)
		return

	if src is Hitbox and attacker and attacker._hit_active and _hit_active and state == State.ATTACK:
		_do_clash(attacker)
		return

	var unblockable := bool(src.get("unblockable"))
	if (state == State.BLOCK or state == State.BLOCKSTUN) and not unblockable:
		_take_blocked(attacker, damage, blockstun, knockback, away, hit_pos)
		return

	if attacker:
		damage *= attacker.power
	if _armor_left > 0:
		_take_armored(attacker, damage, hit_pos)
		return

	if state == State.CHARGE:
		_stop_charge()
	if _daze_left > 0 and effect != &"knockdown":
		hitstun = maxi(hitstun, _daze_left)
	var scale := 1.0
	if attacker:
		scale = maxf(0.35, 1.0 - 0.08 * attacker.combo_count)
	var dealt := damage * scale
	_lose_hp(dealt)
	invuln = false
	hitbox.disarm()
	_hit_active = false
	model.set_visible_body(true)
	got_hit.emit(attacker, dealt)

	model.flash(Color.WHITE, 0.07, 3.0)
	model.shake(0.05 + 0.03 * tier, 0.1 + 0.03 * tier)
	var col := HIT_COLOR
	if move_id == &"tech2" and attacker and attacker.moves.has(&"tech2"):
		col = (attacker.moves[&"tech2"] as MoveData).proj_color
	Fx.spark(hit_pos, col, tier)
	if tier >= 2:
		Fx.shockwave(hit_pos, col, 0.9 + 0.5 * tier, 0.25, away)
	Sfx.play(&"hit_heavy" if tier >= 2 else &"hit_light", 0.0 if tier >= 2 else -2.0)
	if tier >= 3:
		Sfx.play(&"shock_mid", -4.0)
	Feedback.pulse(tier)

	if attacker:
		attacker._register_hit_success(self, move_id, ki_gain)
		if attacker.combo_count >= COMBO_CAP and effect != &"knockdown":
			effect = &"knockdown"
			knockback = maxf(knockback, 8.0)

	if hp <= 0.0:
		_knock_vel = away * maxf(knockback, 7.0)
		_die()
		return

	var airborne := not is_on_floor() or _bouncing
	if effect == &"spike":
		if airborne:
			_enter_spike(away * knockback)
			return
		effect = &""
	match effect:
		&"knockdown":
			_enter_knockdown(away * knockback)
			if tier >= 3:
				Fx.shockwave(global_position + Vector3.UP * 0.05, HIT_COLOR, 4.0, 0.45)
				Sfx.play(&"shock_big", -2.0)
			return
		&"pop":
			velocity.y = POP_VELOCITY * _juggle_decay()
			_airborne_stun = true
			_juggle_hits += 1
		&"crumple":
			_airborne_stun = false
	if airborne and effect != &"pop":
		var lift := float(src.get("lift"))
		velocity.y = maxf(velocity.y, (lift if lift > 0.0 else JUGGLE_LIFT) * _juggle_decay())
		_airborne_stun = true
		_juggle_hits += 1

	_stun_total = hitstun
	_knock_vel = away * knockback
	_enter(State.HITSTUN)
	if effect == &"crumple":
		model.play(&"dizzy", 0.1, 1.4)
	elif effect == &"pop" or not is_on_floor():
		model.play(&"hit_heavy", 0.04, 1.6)
	else:
		var clip := &"hit_heavy" if tier >= 2 else &"hit_light"
		var length := model.clip_length(clip)
		model.play(clip, 0.03, clampf(length * 0.75 / (hitstun / 60.0), 1.0, 3.2))


## Iron Body: reduced damage, no stun, attacker still gets ki and can keep chaining.
func _take_armored(attacker: Fighter, damage: float, hit_pos: Vector3) -> void:
	_lose_hp(damage * 0.6)
	model.flash(Color(1.0, 0.8, 0.35), 0.08, 3.0)
	model.shake(0.03, 0.08)
	Fx.spark(hit_pos, Color(1.0, 0.75, 0.3), 2)
	Sfx.play(&"block", 0.0, 0.15)
	Sfx.play(&"hit_light", -6.0)
	Feedback.pulse(1)
	if attacker:
		attacker._connected = true
		attacker.ki = minf(attacker.ki + 3.0, MAX_KI)
		attacker.ki_changed.emit(attacker.ki)
	if hp <= 0.0:
		_armor_left = 0
		_die()


func _take_blocked(attacker: Fighter, damage: float, blockstun: int, knockback: float, away: Vector3, hit_pos: Vector3) -> void:
	_lose_hp(damage * 0.15)
	ki = minf(ki + 4.0, MAX_KI)
	ki_changed.emit(ki)
	_stun_total = blockstun
	_knock_vel = away * (knockback * 0.35 + 1.2)
	_enter(State.BLOCKSTUN)
	model.play(&"block_hit", 0.03, clampf(model.clip_length(&"block_hit") * 0.5 / (blockstun / 60.0), 1.0, 3.0))
	model.flash(BLOCK_COLOR, 0.05, 1.5)
	model.shake(0.03, 0.08)
	Fx.spark(hit_pos, BLOCK_COLOR, 1)
	Sfx.play(&"block", -3.0)
	Feedback.pulse(0)
	blocked_hit.emit(attacker)
	if attacker:
		attacker._connected = true
	if hp <= 0.0:
		_die()


func _lose_hp(amount: float) -> void:
	hp = maxf(hp - amount, 1.0 if immortal else 0.0)
	hp_changed.emit(hp)


func _register_hit_success(target: Fighter, move_id: StringName, ki_gain: float) -> void:
	_connected = true
	_landed_hit = true
	combo_count += 1
	_string_hits += 1
	ki = minf(ki + ki_gain, MAX_KI)
	ki_changed.emit(ki)
	combo_changed.emit(combo_count)
	hit_landed.emit(target, move_id)
	if _string_hits >= 3 or move_id in [&"tech1", &"H2", &"counter_hit"]:
		confirm_ready = true


func _reset_combo() -> void:
	if combo_count == 0 and not confirm_ready:
		return
	combo_count = 0
	_string_hits = 0
	confirm_ready = false
	combo_changed.emit(0)


func _tick_hitstun() -> void:
	_decay_knock(18.0)
	if _airborne_stun:
		if is_on_floor() and _state_frames > 8:
			_airborne_stun = false
			_juggle_hits = 0
			_stun_total = maxi(_stun_total, _state_frames + JUGGLE_LAND_STUN)
		return
	if _state_frames >= _stun_total:
		_recover()


func _juggle_decay() -> float:
	return maxf(0.35, 1.0 - JUGGLE_DECAY * _juggle_hits)


func _recover() -> void:
	_juggle_hits = 0
	_bounced = false
	_enter(State.IDLE)
	model.play(_idle_clip, 0.2)
	if opponent:
		opponent._reset_combo()


func _enter_knockdown(push: Vector3) -> void:
	_enter(State.KNOCKDOWN)
	_daze_left = 0
	_knock_vel = push
	velocity.y = 4.0
	_getting_up = false
	invuln = true
	hitbox.disarm()
	_hit_active = false
	model.play(&"fall", 0.05, 1.5)


## Meteor Smash: driven into the floor, bouncing back up once per combo for a follow-up.
func _enter_spike(push: Vector3) -> void:
	_enter_knockdown(push)
	velocity.y = -SPIKE_VELOCITY
	_spiked = true
	model.play(&"fall", 0.04, 2.0)


func _tick_knockdown() -> void:
	_decay_knock(10.0)
	if _spiked and is_on_floor():
		_spiked = false
		_spike_impact()
		return
	if _bouncing and is_on_floor() and velocity.y <= 0.0 and _state_frames > 4:
		_bouncing = false
		invuln = true
		_state_frames = 0
	if _bouncing:
		return
	if not _getting_up and _state_frames >= KD_LIE_FRAMES and is_on_floor():
		_getting_up = true
		_juggle_hits = 0
		_bounced = false
		model.play(&"getup", 0.25, model.clip_length(&"getup") / (KD_GETUP_FRAMES / 60.0))
		if opponent:
			opponent._reset_combo()
	if _getting_up and _state_frames >= KD_LIE_FRAMES + KD_GETUP_FRAMES:
		invuln = false
		_recover()


func _spike_impact() -> void:
	var ground := global_position + Vector3.UP * 0.05
	Fx.shockwave(ground, HIT_COLOR, 4.0, 0.4)
	Fx.spark(ground + Vector3.UP * 0.3, HIT_COLOR, 3)
	Sfx.play(&"shock_big", -3.0)
	Feedback.pulse(3)
	_state_frames = 0
	if _bounced:
		return
	_bounced = true
	_bouncing = true
	invuln = false
	velocity.y = BOUNCE_VELOCITY
	_knock_vel *= 0.4


func _decay_knock(rate: float) -> void:
	_knock_vel = _knock_vel.move_toward(Vector3.ZERO, rate * get_physics_process_delta_time())
	velocity.x = _knock_vel.x
	velocity.z = _knock_vel.z


func _do_clash(other: Fighter) -> void:
	for f: Fighter in [self, other]:
		f.hitbox.disarm()
		f._hit_active = false
		f._knock_vel = -f.facing * 6.0
		f._stun_total = 14
		f._enter(State.HITSTUN)
		f.ki = minf(f.ki + 6.0, MAX_KI)
		f.ki_changed.emit(f.ki)
		f.model.play(&"hit_heavy", 0.04, 2.0)
		f.model.flash(Color(1.0, 0.95, 0.5), 0.1)
	var mid := (global_position + other.global_position) * 0.5 + Vector3.UP * 1.3
	Fx.spark(mid, Color(1, 1, 1), 3)
	Fx.shockwave(mid, Color(1, 0.95, 0.7), 3.0, 0.35, facing)
	Sfx.play(&"clash")
	Feedback.pulse(2)
	clashed.emit(other)
	other.clashed.emit(self)


func _die() -> void:
	_enter(State.DEAD)
	_stop_charge()
	hitbox.disarm()
	_hit_active = false
	invuln = true
	velocity.y = 4.5
	model.play(&"fall", 0.05, 1.1)
	Sfx.play(&"ko")
	Fx.shockwave(global_position + Vector3.UP * 0.05, HIT_COLOR, 5.0, 0.6)
	died.emit()


# --- round flow helpers ----------------------------------------------------

func refill() -> void:
	hp = max_hp
	ki = 0.0
	combo_count = 0
	_string_hits = 0
	confirm_ready = false
	invuln = false
	_armor_left = 0
	_daze_left = 0
	_juggle_hits = 0
	_bounced = false
	_enter(State.IDLE)
	hp_changed.emit(hp)
	ki_changed.emit(ki)


func is_stunned() -> bool:
	return state in [State.HITSTUN, State.BLOCKSTUN, State.KNOCKDOWN, State.DEAD]


## Training reset: snap to a spot in neutral with full HP and no ki.
func reset_to(pos: Vector3) -> void:
	_stop_charge()
	hitbox.disarm()
	_hit_active = false
	_knock_vel = Vector3.ZERO
	_rush_seg = -1
	_getting_up = false
	_buffer.clear()
	velocity = Vector3.ZERO
	global_position = pos
	model.set_visible_body(true)
	refill()
	if opponent:
		opponent._reset_combo()
	model.play(_idle_clip, 0.1)


func taunt() -> void:
	model.play(&"taunt", 0.2, 1.3)


func celebrate() -> void:
	controllable = false
	_stop_charge()
	model.play(&"victory", 0.3)


func _distance_to_opponent() -> float:
	if opponent == null:
		return INF
	var d := opponent.global_position - global_position
	d.y = 0.0
	return d.length()


func _clamp_arena() -> void:
	var p := global_position
	if absf(p.x) > ARENA_HALF or absf(p.z) > ARENA_HALF:
		global_position = Vector3(clampf(p.x, -ARENA_HALF, ARENA_HALF), p.y, clampf(p.z, -ARENA_HALF, ARENA_HALF))
