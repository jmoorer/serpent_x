class_name CameraRig
extends Node3D

## Over-the-shoulder fight cam: behind the player, framing the opponent,
## pulling back as the fighters separate. `focus()` orbits one fighter for KO / victory shots.

@export var back: float = 4.4
@export var height: float = 2.2
@export var shoulder: float = 0.9
@export var look_height: float = 1.15

var player: Node3D
var enemy: Node3D
var _focus: Node3D
var _orbit: float = 0.0
@onready var spring: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	spring.spring_length = 0.0
	spring.rotation = Vector3.ZERO
	camera.current = true
	Feedback.bind_camera(camera)


func bind(p: Node3D, e: Node3D) -> void:
	player = p
	enemy = e
	_snap()


func focus(target: Node3D) -> void:
	_focus = target
	_orbit = 0.0


func _snap() -> void:
	var t := _targets()
	global_position = t[0]
	look_at(t[1], Vector3.UP)


func _targets() -> Array:
	if _focus and is_instance_valid(_focus):
		var c := _focus.global_position
		var base_dir := (global_position - c)
		base_dir.y = 0.0
		var ang := atan2(base_dir.x, base_dir.z) + _orbit
		var pos := c + Vector3(sin(ang), 0.0, cos(ang)) * 3.6 + Vector3.UP * 1.6
		return [pos, c + Vector3.UP * 1.1]
	if player == null or enemy == null:
		return [global_position, global_position + Vector3.FORWARD]
	var away := player.global_position - enemy.global_position
	away.y = 0.0
	var dist := away.length()
	away = away / dist if dist > 0.05 else Vector3.BACK
	var right := Vector3.UP.cross(away).normalized()
	var extra := clampf(dist - 3.0, 0.0, 8.0) * 0.4
	var pos := player.global_position + away * (back + extra) + right * shoulder + Vector3.UP * (height + extra * 0.25)
	var look := player.global_position.lerp(enemy.global_position, 0.6) + Vector3.UP * look_height
	return [pos, look]


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.04)
	if _focus:
		_orbit = 0.35 * real
	var t := _targets()
	global_position = global_position.lerp(t[0], 1.0 - exp(-6.0 * real))
	var target_basis := global_transform.looking_at(t[1], Vector3.UP).basis
	global_basis = global_basis.slerp(target_basis, 1.0 - exp(-10.0 * real))
