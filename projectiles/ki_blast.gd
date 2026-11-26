class_name KiBlast
extends Area3D

const COLOR := Color(0.45, 0.8, 1.0)

var owner_fighter: Fighter
var direction: Vector3 = Vector3.FORWARD
var speed: float = 24.0
var move: MoveData
var life: float = 1.1
var color: Color = COLOR
var homing: float = 0.0
var _hit: bool = false

@onready var core: MeshInstance3D = $Core
@onready var halo: MeshInstance3D = $Halo
@onready var trail: CPUParticles3D = $Trail
@onready var light: OmniLight3D = $Light


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	area_entered.connect(_on_area_entered)
	var tw := create_tween().set_loops()
	tw.tween_property(halo, "scale", Vector3.ONE * 1.25, 0.06)
	tw.tween_property(halo, "scale", Vector3.ONE * 0.95, 0.06)


func setup(fighter: Fighter, dir: Vector3, m: MoveData) -> void:
	owner_fighter = fighter
	direction = dir.normalized()
	move = m
	speed = m.proj_speed
	life = m.proj_life
	color = m.proj_color
	homing = m.proj_homing
	scale = Vector3.ONE * m.proj_scale
	if m.proj_scale < 0.8:
		# thin beam: stretch along travel
		core.scale = Vector3(1, 1, 3.5)
		halo.scale = Vector3(1, 1, 2.5)
	_tint(halo, Color(color, 0.55))
	_tint(core, color.lightened(0.7))
	var pm := trail.mesh.duplicate() as PrimitiveMesh
	var tm := (pm.material as StandardMaterial3D).duplicate() as StandardMaterial3D
	tm.albedo_color = Color(color, 0.6)
	pm.material = tm
	trail.mesh = pm
	light.light_color = color
	look_at(global_position + direction, Vector3.UP)


func _tint(mi: MeshInstance3D, c: Color) -> void:
	var mat := (mi.get_surface_override_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.albedo_color = c
	mi.set_surface_override_material(0, mat)


func _physics_process(delta: float) -> void:
	if homing > 0.0 and owner_fighter and is_instance_valid(owner_fighter.opponent):
		var target := owner_fighter.opponent.global_position + Vector3.UP * 1.2
		var want := (target - global_position).normalized()
		var angle := direction.angle_to(want)
		if angle > 0.001:
			direction = direction.slerp(want, minf(1.0, homing * delta / angle)).normalized()
			look_at(global_position + direction, Vector3.UP)
	global_position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		_burst(0.7)
		queue_free()


func _on_area_entered(area: Area3D) -> void:
	if _hit or not (area is Hurtbox):
		return
	var hurt := area as Hurtbox
	if hurt.owner_fighter == null or hurt.owner_fighter == owner_fighter:
		return
	_hit = true
	var p := HitPayload.new()
	p.owner_fighter = owner_fighter
	p.move_id = move.id
	p.damage = move.damage
	p.hitstun = move.hitstun
	p.blockstun = move.blockstun
	p.knockback = move.knockback
	p.ki_gain = 6.0
	p.hit_tier = move.tier
	p.effect = move.effect
	hurt.receive_hit(p)
	_burst(1.4)
	queue_free()


func _burst(size: float) -> void:
	var s := size * maxf(scale.x, 0.6)
	Fx.flash_sphere(global_position, color, s * 1.6, 0.22)
	Fx.shockwave(global_position, color, s * 1.8, 0.3, direction)
