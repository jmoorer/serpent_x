extends Node

## Code-built hit VFX: glow sparks, ground shockwave rings, flashes, ki aura.

var _glow: GradientTexture2D
var _quad := QuadMesh.new()
var _ring := TorusMesh.new()
var _sphere := SphereMesh.new()


func _ready() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 0.85))
	_glow = GradientTexture2D.new()
	_glow.gradient = g
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	_glow.width = 128
	_glow.height = 128
	_ring.inner_radius = 0.9
	_ring.outer_radius = 1.0
	_ring.rings = 48
	_sphere.radius = 0.5
	_sphere.height = 1.0


func _mat(color: Color, billboard: bool, textured: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.albedo_color = color
	if textured:
		m.albedo_texture = _glow
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	return m


func _spawn(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var scene := get_tree().current_scene
	if scene == null:
		return mi
	scene.add_child(mi)
	mi.global_position = pos
	return mi


func _fade_out(mi: MeshInstance3D, mat: StandardMaterial3D, dur: float, end_scale: Vector3) -> void:
	var tw := get_tree().create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", end_scale, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


## Impact spark: core flash + two crossed streaks. tier 1..3 scales it.
func spark(pos: Vector3, color: Color, tier: int = 1) -> void:
	var s := 0.55 + 0.35 * tier
	var core_mat := _mat(Color(1, 1, 1, 1), true)
	var core := _spawn(_quad, core_mat, pos)
	core.scale = Vector3.ONE * s * 0.4
	_fade_out(core, core_mat, 0.12 + 0.03 * tier, Vector3.ONE * s * 1.2)
	var halo_mat := _mat(Color(color, 0.9), true)
	var halo := _spawn(_quad, halo_mat, pos)
	halo.scale = Vector3.ONE * s * 0.6
	_fade_out(halo, halo_mat, 0.2 + 0.05 * tier, Vector3.ONE * s * 2.2)
	for k in 2 + tier:
		var streak_mat := _mat(Color(color.lightened(0.4), 1.0), true)
		var streak := _spawn(_quad, streak_mat, pos)
		streak.rotation.z = randf() * TAU
		streak.scale = Vector3(s * 0.15, s * 0.15, 1)
		_fade_out(streak, streak_mat, 0.14, Vector3(s * 2.6, s * 0.12, 1))


## Expanding ring. vertical=true faces the camera-ish (along dir), else lies on the ground.
func shockwave(pos: Vector3, color: Color, radius: float = 2.5, dur: float = 0.35, vertical_dir: Vector3 = Vector3.ZERO) -> void:
	var mat := _mat(Color(color, 0.9), false, false)
	var ring := _spawn(_ring, mat, pos)
	if vertical_dir != Vector3.ZERO:
		ring.look_at(pos + vertical_dir, Vector3.UP)
		ring.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	ring.scale = Vector3(0.2, 0.6, 0.2)
	_fade_out(ring, mat, dur, Vector3(radius, 0.25, radius))


func flash_sphere(pos: Vector3, color: Color, size: float = 1.5, dur: float = 0.18) -> void:
	var mat := _mat(Color(color, 0.7), false, false)
	var s := _spawn(_sphere, mat, pos)
	s.scale = Vector3.ONE * size * 0.3
	_fade_out(s, mat, dur, Vector3.ONE * size)


## Rising ki particles + glow shell; returns the node so the caller can toggle `emitting`.
func make_aura(parent: Node3D, color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 48
	p.lifetime = 0.6
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.55
	p.emission_ring_inner_radius = 0.2
	p.emission_ring_height = 0.2
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 5.5, 0)
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.9)
	var qm := _mat(Color(color, 0.8), true)
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = qm
	p.mesh = q
	p.position = Vector3(0, 0.1, 0)
	parent.add_child(p)
	return p
