class_name Loadouts
extends RefCounted

## Player-selectable schools: animation style + technique school + stats + look.
## speed scales walk/strafe/dash; power scales all outgoing damage.

const ORDER: Array[StringName] = [&"turtle", &"crane", &"wolf", &"mountain"]

const DATA := {
	&"turtle": {
		"name": "Turtle School",
		"tagline": "All-rounder. Blink behind, blast, finish.",
		"body": &"turtle", "style": &"turtle", "techs": &"turtle",
		"main": Color(0.95, 0.5, 0.12), "accent": Color(0.12, 0.2, 0.55), "aura": Color(1.0, 0.85, 0.3),
		"max_hp": 120.0, "speed": 1.0, "power": 1.0,
		"kata": [&"jab", &"cross", &"hook2", &"roundhouse2", &"palm_blast", &"spin_flip"],
	},
	&"crane": {
		"name": "Crane School",
		"tagline": "Fast capoeira kicks. Blind them, zap them.",
		"body": &"crane", "style": &"capoeira", "techs": &"crane",
		"main": Color(0.92, 0.9, 0.86), "accent": Color(0.2, 0.5, 0.32), "aura": Color(0.6, 1.0, 0.85),
		"max_hp": 100.0, "speed": 1.15, "power": 0.95,
		"kata": [&"chapa", &"martelo", &"armada", &"magic_1h", &"meia_lua", &"compasso"],
	},
	&"wolf": {
		"name": "Wolf Fang",
		"tagline": "Boxer. Parry and punish, homing ki ball.",
		"body": &"wolf", "style": &"boxer", "techs": &"wolf",
		"main": Color(0.22, 0.28, 0.42), "accent": Color(0.95, 0.55, 0.15), "aura": Color(0.6, 0.8, 1.0),
		"max_hp": 110.0, "speed": 1.08, "power": 1.0,
		"kata": [&"jab2", &"cross", &"right_hook", &"uppercut_jab", &"chidori", &"roundhouse"],
	},
	&"mountain": {
		"name": "Mountain Fist",
		"tagline": "Slow bruiser. Tank hits, shatter the ring.",
		"body": &"mountain", "style": &"brawler", "techs": &"mountain",
		"main": Color(0.55, 0.2, 0.14), "accent": Color(0.9, 0.7, 0.25), "aura": Color(1.0, 0.45, 0.25),
		"max_hp": 145.0, "speed": 0.88, "power": 1.15,
		"kata": [&"hook", &"elbow", &"jab_elbow", &"area_burst", &"knee", &"spin_flip2"],
	},
}


static func get_data(id: StringName) -> Dictionary:
	return DATA.get(id, DATA[&"turtle"])
