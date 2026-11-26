class_name MoveList
extends PanelContainer

## On-screen move list with frame data, generated from a fighter's built moveset.

const GOLD_HEX := "#ffd24d"
const DIM_HEX := "#bdb6a8"
const TECH_KEYS := {"tech1": "U", "tech2": "I", "tech3": "O"}
const EFFECT_NAMES := {&"pop": "launch", &"crumple": "crumple", &"knockdown": "knockdown"}
const NORMALS := [
	["J", &"L1", "Light 1"],
	["J J", &"L2", "Light 2"],
	["J J J", &"L3", "Light 3"],
	["J J J J", &"L4", "Light 4"],
	["K", &"H0", "Heavy"],
	["J › K", &"H1", ""],
	["J J › K", &"H2", ""],
	["J J J › K", &"H3", ""],
	["Shift+J", &"DL", ""],
	["Shift+K", &"H0", "Dash Heavy"],
]

var _text: RichTextLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.border_color = Color(1, 0.82, 0.3, 0.45)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(12)
	add_theme_stylebox_override("panel", bg)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(520, 0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 13)
	_text.add_theme_font_size_override("bold_font_size", 13)
	_text.add_theme_color_override("default_color", Color(0.95, 0.92, 0.86))
	_text.add_theme_constant_override("table_h_separation", 12)
	_text.add_theme_constant_override("table_v_separation", 2)
	add_child(_text)


func build(moves: Dictionary, school: String, power: float) -> void:
	var t := "[b][color=%s]MOVE LIST[/color]  ·  %s[/b]   [color=%s](Tab to hide)[/color]\n" % [GOLD_HEX, school, DIM_HEX]
	t += "[table=5]" + _header()
	for row: Array in NORMALS:
		var m: MoveData = moves[row[1]]
		var label: String = row[2] if row[2] != "" else m.callout
		t += _row(row[0], label, m, power)
	t += "[/table]\n[table=5]" + _header()
	for key: String in TECH_KEYS:
		var m: MoveData = moves[StringName(key)]
		t += _row(TECH_KEYS[key], m.display_name, m, power)
	if moves.has(&"counter_hit"):
		t += _row("(auto)", "Counter Hit", moves[&"counter_hit"], power)
	t += "[/table]\n[color=%s]%s[/color]" % [DIM_HEX,
		"Hold L block · hold C charge ki · Space hop · O rush needs a confirm (3-hit string, Knee Crush, U hit). Damage scales down per combo hit."]
	_text.text = t


func _header() -> String:
	var h := ""
	for c in ["INPUT", "MOVE", "DMG", "START", "NOTES"]:
		h += "[cell][color=%s]%s[/color][/cell]" % [DIM_HEX, c]
	return h


func _row(input: String, label: String, m: MoveData, power: float) -> String:
	var dmg := m.damage
	for seg: Array in m.segments:
		dmg += float(seg[2])
	var cells := [
		"[b][color=%s]%s[/color][/b]" % [GOLD_HEX, input],
		label,
		"%d" % roundi(dmg * power) if dmg > 0.0 else "—",
		"%df" % m.startup if m.startup > 0 else "—",
		_notes(m),
	]
	var r := ""
	for c: String in cells:
		r += "[cell]%s[/cell]" % c
	return r


func _notes(m: MoveData) -> String:
	var parts: Array[String] = []
	if m.ki_cost > 0.0:
		parts.append("%d ki" % int(m.ki_cost))
	if m.kind != &"":
		parts.append(FightHUD.KIND_HINT.get(m.kind, ""))
	if EFFECT_NAMES.has(m.effect):
		parts.append(EFFECT_NAMES[m.effect])
	if m.unblockable:
		parts.append("unblockable")
	if not String(m.id).begins_with("L"):
		if m.chain_light != &"":
			parts.append("› J")
		if m.chain_heavy != &"":
			parts.append("› K")
	if not m.cancel_tech.is_empty():
		var keys: Array[String] = []
		for c: String in m.cancel_tech:
			keys.append(TECH_KEYS.get(c, c))
		parts.append("cancel " + "/".join(keys))
	return "[color=%s]%s[/color]" % [DIM_HEX, ", ".join(parts)]
