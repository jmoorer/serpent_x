class_name Hurtbox
extends Area3D

var owner_fighter: Fighter


func _ready() -> void:
	collision_layer = 2  # hurtbox
	collision_mask = 0
	monitorable = true
	monitoring = false


func setup(fighter: Fighter) -> void:
	owner_fighter = fighter


func receive_hit(hit_source: Object) -> void:
	if owner_fighter:
		owner_fighter.take_hit(hit_source)
