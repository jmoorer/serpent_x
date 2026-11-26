class_name HitPayload
extends RefCounted

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
