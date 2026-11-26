class_name Hitbox
extends Area3D

signal landed(hurtbox: Hurtbox)

var owner_fighter: Fighter
var move_id: StringName = &""
var damage: float = 0.0
var hitstun: int = 0
var blockstun: int = 0
var knockback: float = 0.0
var ki_gain: float = 0.0
var hit_tier: int = 1
var effect: StringName = &""
var unblockable: bool = false
var active: bool = false
var _hit_this_move: Dictionary = {}


func _ready() -> void:
	monitoring = false
	monitorable = false
	collision_layer = 4  # hitbox
	collision_mask = 2   # hurtbox
	area_entered.connect(_on_area_entered)


func arm(fighter: Fighter, move: MoveData) -> void:
	arm_custom(fighter, move.id, move.damage, move.hitstun, move.blockstun, move.knockback, move.ki_gain,
		move.hitbox_size, move.hitbox_offset, move.tier, move.effect)


func arm_custom(fighter: Fighter, id: StringName, dmg: float, hs: int, bs: int, kb: float, ki: float,
		size: Vector3, offset: Vector3, tier: int, fx: StringName = &"") -> void:
	owner_fighter = fighter
	move_id = id
	damage = dmg
	hitstun = hs
	blockstun = bs
	knockback = kb
	ki_gain = ki
	hit_tier = tier
	effect = fx
	_hit_this_move.clear()
	var box := BoxShape3D.new()
	box.size = size
	$CollisionShape3D.shape = box
	position = offset
	monitoring = true
	active = true
	# Overlaps that already exist when monitoring turns on are reported next physics frame.
	call_deferred(&"_scan_existing")


func disarm() -> void:
	active = false
	set_deferred(&"monitoring", false)


func _scan_existing() -> void:
	if not active:
		return
	for area in get_overlapping_areas():
		if area is Hurtbox:
			_try_hit(area as Hurtbox)


func _on_area_entered(area: Area3D) -> void:
	if not active:
		return
	if area is Hurtbox:
		_try_hit(area as Hurtbox)


func _try_hit(hurt: Hurtbox) -> void:
	if hurt.owner_fighter == null or owner_fighter == null:
		return
	if hurt.owner_fighter == owner_fighter or hurt.owner_fighter.team == owner_fighter.team:
		return
	var key := hurt.get_instance_id()
	if _hit_this_move.has(key):
		return
	_hit_this_move[key] = true
	landed.emit(hurt)
	hurt.receive_hit(self)
