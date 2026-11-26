class_name MoveData
extends Resource

@export var id: StringName = &"L1"
@export var display_name: String = ""
@export var clip: StringName = &"jab"
@export var startup: int = 6
@export var active: int = 3
@export var recovery: int = 12
@export var damage: float = 6.0
@export var hitstun: int = 16
@export var blockstun: int = 8
@export var knockback: float = 2.0
@export var ki_gain: float = 5.0
@export var hitbox_size: Vector3 = Vector3(0.9, 0.9, 1.0)
@export var hitbox_offset: Vector3 = Vector3(0.0, 1.2, -0.95)
@export var tier: int = 1
## "" | pop | crumple | knockdown
@export var effect: StringName = &""
## Forward speed (m/s) during startup + active; stops when touching the opponent.
@export var lunge: float = 0.0
@export var chain_light: StringName = &""
@export var chain_heavy: StringName = &""
@export var cancel_tech: PackedStringArray = PackedStringArray()
## Shown as a HUD callout when the move starts.
@export var callout: String = ""

@export_group("Technique")
@export var ki_cost: float = 0.0
@export var requires_confirm: bool = false
## "" (normal) | afterimage | blast | rush | flare | counter | armor | quake
@export var kind: StringName = &""
## flare / quake radius in metres.
@export var reach: float = 0.0
## flare daze / armor frames.
@export var duration: int = 0
@export var unblockable: bool = false
## rush: [clip, frames, damage, effect] per segment.
@export var segments: Array = []

@export_group("Projectile")
@export var proj_speed: float = 24.0
@export var proj_scale: float = 1.0
@export var proj_color: Color = Color(0.45, 0.8, 1.0)
@export var proj_life: float = 1.1
## Max turn rate toward the target in rad/s; 0 = straight.
@export var proj_homing: float = 0.0
