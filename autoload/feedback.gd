extends Node

## Hitstop, camera trauma, FOV punch and slow-mo. Timers run on real time so
## they keep counting while Engine.time_scale is low.

const BASE_FOV := 55.0

var trauma: float = 0.0
var _hitstop_left: float = 0.0
var _slowmo_left: float = 0.0
var _slowmo_scale: float = 1.0
var _zoom: float = 0.0
var _camera: Camera3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind_camera(cam: Camera3D) -> void:
	_camera = cam
	reset()


func reset() -> void:
	trauma = 0.0
	_hitstop_left = 0.0
	_slowmo_left = 0.0
	_zoom = 0.0
	Engine.time_scale = 1.0


## tier 0 = block, 1 = light, 2 = heavy, 3 = technique finisher
func pulse(tier: int, _world_pos: Vector3 = Vector3.ZERO) -> void:
	match tier:
		0:
			_add_trauma(0.08)
			_hitstop(0.03)
		1:
			_add_trauma(0.14)
			_hitstop(0.045)
		2:
			_add_trauma(0.28)
			_hitstop(0.075)
			zoom_punch(0.35)
		_:
			_add_trauma(0.45)
			_hitstop(0.12)
			zoom_punch(0.8)


func zoom_punch(amount: float) -> void:
	_zoom = maxf(_zoom, amount)


func slowmo(scale: float, seconds: float) -> void:
	_slowmo_scale = scale
	_slowmo_left = seconds
	_apply_time_scale()


func _add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _hitstop(seconds: float) -> void:
	_hitstop_left = maxf(_hitstop_left, seconds)
	_apply_time_scale()


func _apply_time_scale() -> void:
	if _hitstop_left > 0.0:
		Engine.time_scale = 0.04
	elif _slowmo_left > 0.0:
		Engine.time_scale = _slowmo_scale
	else:
		Engine.time_scale = 1.0


func _process(delta: float) -> void:
	var real_delta := minf(delta / maxf(Engine.time_scale, 0.001), 0.1)
	if _hitstop_left > 0.0:
		_hitstop_left -= real_delta
		if _hitstop_left <= 0.0:
			_apply_time_scale()
	if _slowmo_left > 0.0:
		_slowmo_left -= real_delta
		if _slowmo_left <= 0.0:
			_apply_time_scale()
	trauma = maxf(trauma - real_delta * 1.8, 0.0)
	_zoom = maxf(_zoom - real_delta * 3.0, 0.0)
	if _camera == null or not is_instance_valid(_camera):
		return
	var shake := trauma * trauma
	_camera.h_offset = randf_range(-1.0, 1.0) * shake * 0.3
	_camera.v_offset = randf_range(-1.0, 1.0) * shake * 0.3
	_camera.fov = BASE_FOV - 7.0 * _zoom
