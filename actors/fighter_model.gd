class_name FighterModel
extends Node3D

## Mixamo X/Y Bot mannequin with the shared fighter AnimationLibrary.

const LIB := preload("res://assets/anims/fighter_anims.res")
const BODIES := {
	&"x": preload("res://assets/third_party/mixamo/x-bot/X Bot.fbx"),
	&"y": preload("res://assets/third_party/mixamo/y-bot/Y Bot.fbx"),
}
## X Bot's hips rest higher than the Y Bot the clips were authored on.
const BODY_LIFT := {&"x": 0.045, &"y": 0.0}

var anim: AnimationPlayer
var skeleton: Skeleton3D
var body: Node3D
var _mats: Array[StandardMaterial3D] = []
var _shake_until := 0
var _shake_amount := 0.0
var _flash_token := 0


func build(body_id: StringName, main: Color, accent: Color) -> void:
	if body:
		body.free()
	_mats.clear()
	body = (BODIES[body_id] as PackedScene).instantiate() as Node3D
	var imported := body.get_node_or_null("AnimationPlayer")
	if imported:
		imported.free()
	add_child(body)
	body.rotation.y = PI
	body.position.y = BODY_LIFT[body_id]
	skeleton = body.get_node("Skeleton3D") as Skeleton3D
	for child in skeleton.get_children():
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		var joints := String(mi.name).contains("Joints")
		var m := StandardMaterial3D.new()
		m.albedo_color = accent if joints else main
		m.roughness = 0.35 if joints else 0.5
		m.metallic = 0.3 if joints else 0.05
		m.rim_enabled = true
		m.rim = 0.35
		m.rim_tint = 0.6
		mi.material_override = m
		_mats.append(m)
	anim = AnimationPlayer.new()
	anim.name = &"Anim"
	body.add_child(anim)
	anim.add_animation_library(&"", LIB)


func clip_length(clip: StringName) -> float:
	return LIB.get_animation(clip).length if LIB.has_animation(clip) else 0.0


func clip_impact(clip: StringName) -> float:
	if not LIB.has_animation(clip):
		return 0.0
	var a := LIB.get_animation(clip)
	return float(a.get_meta(&"impact", a.length * 0.4))


## restart=false keeps a looping clip running if it is already current.
func play(clip: StringName, blend: float = 0.1, speed: float = 1.0, restart: bool = true) -> void:
	if anim == null or not LIB.has_animation(clip):
		return
	anim.speed_scale = speed
	if anim.current_animation == String(clip):
		if restart:
			anim.seek(0.0, true)
		return
	anim.play(clip, blend)


func set_speed(speed: float) -> void:
	if anim:
		anim.speed_scale = speed


func flash(color: Color = Color.WHITE, duration: float = 0.08, energy: float = 2.5) -> void:
	_flash_token += 1
	var token := _flash_token
	for m in _mats:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
	get_tree().create_timer(duration, true, false, true).timeout.connect(_clear_flash.bind(token))


func _clear_flash(token: int) -> void:
	if token != _flash_token:
		return
	for m in _mats:
		m.emission_enabled = false


## Jitter the mesh in real time (survives hitstop slow-mo).
func shake(amount: float, duration: float) -> void:
	_shake_amount = amount
	_shake_until = Time.get_ticks_msec() + int(duration * 1000.0)


func set_visible_body(v: bool) -> void:
	if body:
		body.visible = v


## Frozen translucent copy of the current pose, fading out in place.
func spawn_ghost(color: Color, life: float = 0.5) -> void:
	if body == null or get_tree().current_scene == null:
		return
	var ghost := body.duplicate() as Node3D
	var ghost_anim := ghost.get_node_or_null("Anim")
	if ghost_anim:
		ghost_anim.free()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color, 0.55)
	for child in ghost.get_node("Skeleton3D").get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = m
	get_tree().current_scene.add_child(ghost)
	ghost.global_transform = body.global_transform
	var tw := get_tree().create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(ghost.queue_free)


func _process(_delta: float) -> void:
	if body == null:
		return
	if Time.get_ticks_msec() < _shake_until:
		body.position.x = randf_range(-1.0, 1.0) * _shake_amount
		body.position.z = randf_range(-1.0, 1.0) * _shake_amount
	elif body.position.x != 0.0 or body.position.z != 0.0:
		body.position.x = 0.0
		body.position.z = 0.0
