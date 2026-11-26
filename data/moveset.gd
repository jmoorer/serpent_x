class_name Moveset
extends RefCounted

## Shared frame data; each style only swaps the animation clips, so every
## opponent plays fair but looks and reads differently.
##
## String: L1 > L2 > L3 > L4. Heavy branches: neutral H0, L1>H1 pop, L2>H2 crumple, L3>H3 knockdown.
## Air (after a hop or the H1 chase jump): AL1 > AL2 > AL3 blowback; K from neutral air, AL1 or AL2 is the AH spike.

const STYLES := {
	&"turtle": {
		"idle": &"idle_turtle", "L1": &"jab", "L2": &"cross", "L3": &"hook2", "L4": &"roundhouse2",
		"H0": &"mma_kick", "H1": &"uppercut", "H2": &"knee", "H3": &"spin_flip", "DL": &"flying_kick",
		"T1": &"elbow_back", "T2": &"palm_blast",
		"AL1": &"jab2", "AL2": &"knee", "AL3": &"roundhouse2", "AH": &"spin_flip",
	},
	&"boxer": {
		"idle": &"idle_fighting", "L1": &"jab2", "L2": &"cross", "L3": &"right_hook", "L4": &"uppercut_jab",
		"H0": &"mma_kick2", "H1": &"uppercut", "H2": &"knee_lead", "H3": &"roundhouse", "DL": &"flying_kick",
		"T1": &"elbow", "T2": &"palm_blast3",
		"AL1": &"jab", "AL2": &"right_hook", "AL3": &"uppercut_jab", "AH": &"spin_flip2",
	},
	&"brawler": {
		"idle": &"idle_fight", "L1": &"hook", "L2": &"elbow", "L3": &"jab_elbow", "L4": &"crescent",
		"H0": &"roundhouse", "H1": &"uppercut", "H2": &"knee", "H3": &"spin_flip2", "DL": &"flying_kick",
		"T1": &"elbow_back", "T2": &"palm_blast3",
		"AL1": &"elbow", "AL2": &"knee_lead", "AL3": &"crescent", "AH": &"spin_flip2",
	},
	&"capoeira": {
		"idle": &"idle_ginga", "L1": &"chapa", "L2": &"bencao", "L3": &"martelo", "L4": &"armada",
		"H0": &"meia_lua", "H1": &"compasso", "H2": &"chapa_gira", "H3": &"spin_flip", "DL": &"flying_kick",
		"T1": &"elbow_back", "T2": &"magic_1h",
		"AL1": &"chapa", "AL2": &"martelo", "AL3": &"armada", "AH": &"spin_flip",
	},
}

## Rush segments: [clip, frames, damage, effect]
const RUSH := [
	[&"jab2", 9, 3.0, &""],
	[&"cross", 9, 3.0, &""],
	[&"hook2", 10, 4.0, &""],
	[&"knee", 11, 4.0, &""],
	[&"uppercut", 13, 5.0, &""],
	[&"spin_flip", 24, 13.0, &"knockdown"],
]
const CRANE_RUSH := [
	[&"chapa", 10, 3.0, &""],
	[&"bencao", 10, 3.0, &""],
	[&"martelo", 11, 4.0, &""],
	[&"meia_lua", 12, 4.0, &""],
	[&"armada", 12, 5.0, &""],
	[&"compasso", 24, 13.0, &"knockdown"],
]
const WOLF_RUSH := [
	[&"jab", 8, 2.5, &""],
	[&"jab2", 8, 2.5, &""],
	[&"cross", 9, 3.0, &""],
	[&"hook", 9, 3.0, &""],
	[&"right_hook", 9, 3.0, &""],
	[&"uppercut_jab", 11, 4.0, &""],
	[&"uppercut", 22, 12.0, &"knockdown"],
]
const MOUNTAIN_RUSH := [
	[&"hook", 11, 4.5, &""],
	[&"elbow", 11, 4.5, &""],
	[&"knee", 12, 5.0, &""],
	[&"uppercut", 13, 6.0, &""],
	[&"spin_flip2", 26, 15.0, &"knockdown"],
]

const PUNCH_BOX := Vector3(0.9, 0.9, 1.05)
const KICK_BOX := Vector3(1.1, 1.1, 1.25)


static func idle_clip(style: StringName) -> StringName:
	return STYLES.get(style, STYLES[&"turtle"])["idle"]


## `techs` picks the U / I / O technique school independently of the animation style.
static func build(style: StringName, techs: StringName = &"turtle") -> Dictionary:
	var c: Dictionary = STYLES.get(style, STYLES[&"turtle"])
	var m := {}

	m[&"L1"] = _move(&"L1", c["L1"], 6, 3, 12, 5.0, 17, 10, 1.4, 4.5, 1)
	m[&"L1"].chain_light = &"L2"
	m[&"L1"].chain_heavy = &"H1"
	m[&"L1"].cancel_tech = PackedStringArray(["tech1"])

	m[&"L2"] = _move(&"L2", c["L2"], 7, 3, 13, 6.0, 18, 10, 1.6, 4.5, 1)
	m[&"L2"].chain_light = &"L3"
	m[&"L2"].chain_heavy = &"H2"
	m[&"L2"].cancel_tech = PackedStringArray(["tech1"])

	m[&"L3"] = _move(&"L3", c["L3"], 8, 3, 15, 7.0, 20, 11, 2.0, 5.0, 1)
	m[&"L3"].chain_light = &"L4"
	m[&"L3"].chain_heavy = &"H3"
	m[&"L3"].cancel_tech = PackedStringArray(["tech1", "tech3"])

	m[&"L4"] = _move(&"L4", c["L4"], 11, 4, 22, 10.0, 26, 12, 9.0, 3.5, 2, KICK_BOX)
	m[&"L4"].effect = &"knockdown"
	m[&"L4"].cancel_tech = PackedStringArray(["tech3"])

	m[&"H0"] = _move(&"H0", c["H0"], 13, 4, 21, 12.0, 22, 11, 7.5, 5.5, 2, KICK_BOX)
	m[&"H0"].cancel_tech = PackedStringArray(["tech2", "tech3"])

	m[&"H1"] = _move(&"H1", c["H1"], 10, 4, 20, 10.0, 30, 11, 1.0, 3.5, 2, Vector3(0.9, 1.3, 1.0), Vector3(0, 1.45, -0.85))
	m[&"H1"].effect = &"pop"
	m[&"H1"].chain_light = &"L1"
	m[&"H1"].cancel_tech = PackedStringArray(["tech1", "tech2", "tech3"])
	m[&"H1"].callout = "Rising Dragon"

	m[&"H2"] = _move(&"H2", c["H2"], 9, 3, 18, 9.0, 55, 10, 0.4, 5.5, 2, Vector3(0.9, 0.9, 0.9), Vector3(0, 1.0, -0.8))
	m[&"H2"].effect = &"crumple"
	m[&"H2"].cancel_tech = PackedStringArray(["tech1", "tech3"])
	m[&"H2"].callout = "Knee Crush"

	m[&"H3"] = _move(&"H3", c["H3"], 14, 5, 26, 15.0, 30, 13, 11.0, 4.0, 3, KICK_BOX)
	m[&"H3"].effect = &"knockdown"
	m[&"H3"].callout = "Tornado Heel"

	m[&"DL"] = _move(&"DL", c["DL"], 9, 5, 18, 9.0, 22, 10, 6.0, 10.0, 2, KICK_BOX)
	m[&"DL"].chain_light = &"L2"
	m[&"DL"].cancel_tech = PackedStringArray(["tech1", "tech2"])
	m[&"DL"].callout = "Flying Kick"

	m[&"AL1"] = _air(&"AL1", c["AL1"], 5, 3, 12, 5.0, 20, 8, 0.6, 5.0, 1)
	m[&"AL1"].chain_light = &"AL2"
	m[&"AL1"].chain_heavy = &"AH"

	m[&"AL2"] = _air(&"AL2", c["AL2"], 6, 3, 13, 6.0, 20, 9, 0.6, 5.0, 1)
	m[&"AL2"].chain_light = &"AL3"
	m[&"AL2"].chain_heavy = &"AH"

	m[&"AL3"] = _air(&"AL3", c["AL3"], 8, 4, 16, 9.0, 30, 10, 9.0, 4.0, 2, KICK_BOX)
	m[&"AL3"].effect = &"knockdown"
	m[&"AL3"].callout = "Heaven Kick"

	m[&"AH"] = _air(&"AH", c["AH"], 10, 4, 18, 12.0, 24, 12, 1.5, 4.0, 3, Vector3(1.2, 1.4, 1.3), Vector3(0, 0.85, -1.0))
	m[&"AH"].effect = &"spike"
	m[&"AH"].callout = "Meteor Smash"

	match techs:
		&"crane":
			_crane_techs(m)
		&"wolf":
			_wolf_techs(m)
		&"mountain":
			_mountain_techs(m)
		_:
			_turtle_techs(m, c)
	return m


static func _rush(name: String, segs: Array, cost: float) -> MoveData:
	var t3 := _move(&"tech3", &"dash_f", 0, 0, 22, 0.0, 0, 12, 0.0, 0.0, 3)
	t3.display_name = name
	t3.kind = &"rush"
	t3.ki_cost = cost
	t3.requires_confirm = true
	t3.segments = segs
	return t3


## Turtle: blink behind, straight ki blast, Dragon Fist Rush.
static func _turtle_techs(m: Dictionary, c: Dictionary) -> void:
	var t1 := _move(&"tech1", c["T1"], 14, 3, 16, 9.0, 26, 10, 2.5, 0.0, 2)
	t1.display_name = "Afterimage Step"
	t1.kind = &"afterimage"
	t1.ki_cost = 20.0
	t1.chain_light = &"L1"
	t1.chain_heavy = &"H0"
	t1.cancel_tech = PackedStringArray(["tech3"])
	m[&"tech1"] = t1

	var t2 := _move(&"tech2", c["T2"], 16, 2, 22, 12.0, 24, 12, 6.0, 0.0, 2)
	t2.display_name = "Kame Whip"
	t2.kind = &"blast"
	t2.ki_cost = 25.0
	m[&"tech2"] = t2

	m[&"tech3"] = _rush("Dragon Fist Rush", RUSH, 45.0)


## Crane: blinding flash (unblockable daze, must face you), fast thin beam, kick barrage.
static func _crane_techs(m: Dictionary) -> void:
	var t1 := _move(&"tech1", &"seal", 16, 2, 24, 0.0, 0, 0, 0.0, 0.0, 2)
	t1.display_name = "Solar Flare"
	t1.kind = &"flare"
	t1.ki_cost = 25.0
	t1.reach = 5.5
	t1.duration = 80
	m[&"tech1"] = t1

	var t2 := _move(&"tech2", &"magic_1h", 10, 2, 18, 8.0, 22, 9, 3.0, 0.0, 1)
	t2.display_name = "Dodon Ray"
	t2.kind = &"blast"
	t2.ki_cost = 20.0
	t2.proj_speed = 48.0
	t2.proj_scale = 0.45
	t2.proj_color = Color(1.0, 0.85, 0.3)
	t2.proj_life = 0.6
	m[&"tech2"] = t2

	m[&"tech3"] = _rush("Crane Kick Barrage", CRANE_RUSH, 45.0)


## Wolf: parry stance that auto-counters, slow homing ball, long punch flurry.
static func _wolf_techs(m: Dictionary) -> void:
	var t1 := _move(&"tech1", &"block", 3, 22, 16, 0.0, 0, 0, 0.0, 0.0, 2)
	t1.display_name = "Counter Stance"
	t1.kind = &"counter"
	t1.ki_cost = 15.0
	m[&"tech1"] = t1

	var ch := _move(&"counter_hit", &"right_hook", 5, 3, 16, 12.0, 36, 12, 0.8, 8.0, 2)
	ch.effect = &"crumple"
	ch.chain_light = &"L2"
	ch.cancel_tech = PackedStringArray(["tech2", "tech3"])
	m[&"counter_hit"] = ch

	var t2 := _move(&"tech2", &"chidori", 18, 2, 20, 13.0, 30, 12, 2.0, 0.0, 2)
	t2.display_name = "Spirit Ball"
	t2.kind = &"blast"
	t2.effect = &"pop"
	t2.ki_cost = 30.0
	t2.proj_speed = 13.0
	t2.proj_scale = 1.35
	t2.proj_color = Color(1.0, 0.95, 0.75)
	t2.proj_life = 2.6
	t2.proj_homing = 2.6
	m[&"tech2"] = t2

	m[&"tech3"] = _rush("Wolf Fang Fist", WOLF_RUSH, 45.0)


## Mountain: super armor buff, unblockable ground slam (hop over it), heavy rush.
static func _mountain_techs(m: Dictionary) -> void:
	var t1 := _move(&"tech1", &"victory", 10, 0, 14, 0.0, 0, 0, 0.0, 0.0, 2)
	t1.display_name = "Iron Body"
	t1.kind = &"armor"
	t1.ki_cost = 20.0
	t1.duration = 180
	m[&"tech1"] = t1

	var t2 := _move(&"tech2", &"area_burst", 20, 2, 22, 14.0, 0, 0, 8.0, 0.0, 2)
	t2.display_name = "Earth Splitter"
	t2.kind = &"quake"
	t2.effect = &"knockdown"
	t2.unblockable = true
	t2.ki_cost = 30.0
	t2.reach = 4.5
	m[&"tech2"] = t2

	m[&"tech3"] = _rush("Volcano Crush", MOUNTAIN_RUSH, 50.0)


static func _air(id: StringName, clip: StringName, su: int, act: int, rec: int, dmg: float, hs: int, bs: int,
		kb: float, lunge: float, tier: int, box: Vector3 = PUNCH_BOX, offset: Vector3 = Vector3(0, 1.2, -0.95)) -> MoveData:
	var d := _move(id, clip, su, act, rec, dmg, hs, bs, kb, lunge, tier, box, offset)
	d.air = true
	return d


static func _move(id: StringName, clip: StringName, su: int, act: int, rec: int, dmg: float, hs: int, bs: int,
		kb: float, lunge: float, tier: int, box: Vector3 = PUNCH_BOX, offset: Vector3 = Vector3(0, 1.2, -0.95)) -> MoveData:
	var d := MoveData.new()
	d.id = id
	d.clip = clip
	d.startup = su
	d.active = act
	d.recovery = rec
	d.damage = dmg
	d.hitstun = hs
	d.blockstun = bs
	d.knockback = kb
	d.lunge = lunge
	d.tier = tier
	d.hitbox_size = box
	d.hitbox_offset = offset if box != KICK_BOX else Vector3(0, 1.15, -1.1)
	d.ki_gain = 4.0 + 3.0 * tier
	return d
