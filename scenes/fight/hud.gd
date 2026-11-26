class_name FightHUD
extends CanvasLayer

const GOLD := Color(1.0, 0.82, 0.3)
const KI := Color(0.45, 0.8, 1.0)
const CONTROLS := "[b]Move[/b] WASD (toward / around foe)   [b]Hop[/b] Space   [b]Dash[/b] Shift   [b]Block[/b] L (hold)   [b]Charge ki[/b] C (hold)\n" \
	+ "[b]J[/b] light string ×4   [b]K[/b] heavy — branches: J›K pop · J J›K knee crush · J J J›K tornado heel   [b]Dash+J[/b] flying kick\n"
const KIND_HINT := {
	&"afterimage": "blink behind",
	&"blast": "ki blast",
	&"flare": "blinds if they face you",
	&"counter": "parry, auto-counter",
	&"armor": "3 s super armor",
	&"quake": "unblockable slam, hop it",
	&"rush": "mid-combo only",
}

var _p_hp: ProgressBar
var _p_trail: ProgressBar
var _e_hp: ProgressBar
var _e_trail: ProgressBar
var _p_ki: ProgressBar
var _e_ki: ProgressBar
var _p_name: Label
var _e_name: Label
var _timer: Label
var _round: Label
var _banner: Label
var _controls: RichTextLabel
var _combo := {}
var _callout := {}
var _confirm: Label
var _combo_tw := {}


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_p_name = _label(root, "You", 22, Vector2(40, 14), GOLD)
	_e_name = _label(root, "Enemy", 22, Vector2(-460, 14), GOLD, true)
	_e_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_p_trail = _bar(root, Vector2(40, 46), Vector2(420, 26), Color(1, 1, 1, 0.85), false)
	_p_hp = _bar(root, Vector2(40, 46), Vector2(420, 26), Color(1.0, 0.75, 0.2), false, true)
	_e_trail = _bar(root, Vector2(-460, 46), Vector2(420, 26), Color(1, 1, 1, 0.85), true)
	_e_hp = _bar(root, Vector2(-460, 46), Vector2(420, 26), Color(1.0, 0.75, 0.2), true, true)
	_p_ki = _bar(root, Vector2(40, 78), Vector2(300, 12), KI, false)
	_e_ki = _bar(root, Vector2(-340, 78), Vector2(300, 12), KI, true)
	_p_ki.max_value = Fighter.MAX_KI
	_e_ki.max_value = Fighter.MAX_KI
	_set_ticks(_p_ki, [20.0, 25.0, 45.0])
	_set_ticks(_e_ki, [20.0, 25.0, 45.0])

	_timer = _label(root, "75", 44, Vector2(-60, 10), Color.WHITE, false, true)
	_timer.custom_minimum_size = Vector2(120, 0)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round = _label(root, "", 16, Vector2(-250, 66), Color(0.85, 0.85, 0.8), false, true)
	_round.custom_minimum_size = Vector2(500, 0)
	_round.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for side in [0, 1]:
		var c := _label(root, "", 46, Vector2(60, 220) if side == 0 else Vector2(-380, 220), GOLD, side == 1)
		c.custom_minimum_size = Vector2(320, 0)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		c.modulate.a = 0.0
		_combo[side] = c
		var co := _label(root, "", 34, Vector2(60, 470) if side == 0 else Vector2(-560, 470), Color(1, 1, 1), side == 1)
		co.custom_minimum_size = Vector2(500, 0)
		co.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		co.modulate.a = 0.0
		_callout[side] = co

	_confirm = _label(root, "DRAGON FIST READY — press O", 20, Vector2(60, 280), Color(1.0, 0.6, 0.2))
	_confirm.visible = false

	_banner = _label(root, "", 72, Vector2(-500, -60), Color.WHITE, false, true, true)
	_banner.custom_minimum_size = Vector2(1000, 120)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.pivot_offset = Vector2(500, 60)
	_banner.visible = false

	_controls = RichTextLabel.new()
	_controls.bbcode_enabled = true
	_controls.fit_content = true
	_controls.text = "[center]" + CONTROLS + "[/center]"
	_controls.add_theme_font_size_override("normal_font_size", 15)
	_controls.add_theme_font_size_override("bold_font_size", 15)
	_controls.add_theme_color_override("default_color", Color(0.92, 0.9, 0.85))
	_controls.anchor_left = 0.0
	_controls.anchor_right = 1.0
	_controls.anchor_top = 1.0
	_controls.anchor_bottom = 1.0
	_controls.offset_top = -92
	_controls.offset_bottom = -12
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0, 0, 0, 0.5)
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	_controls.add_theme_stylebox_override("normal", panel)
	root.add_child(_controls)


func _label(parent: Control, text: String, size: int, pos: Vector2, color: Color, right: bool = false,
		center: bool = false, middle: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", maxi(4, size / 6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if right:
		l.anchor_left = 1.0
		l.anchor_right = 1.0
		l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	elif center:
		l.anchor_left = 0.5
		l.anchor_right = 0.5
	if middle:
		l.anchor_top = 0.5
		l.anchor_bottom = 0.5
	l.position = pos
	if right:
		l.offset_left = pos.x
		l.offset_right = -40
	elif center:
		l.offset_left = pos.x
	parent.add_child(l)
	return l


func _bar(parent: Control, pos: Vector2, size: Vector2, color: Color, right: bool, transparent_bg: bool = false) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = size
	b.size = size
	b.value = 100
	if right:
		b.anchor_left = 1.0
		b.anchor_right = 1.0
		b.offset_left = pos.x
		b.offset_right = pos.x + size.x
		b.offset_top = pos.y
		b.offset_bottom = pos.y + size.y
		b.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	else:
		b.position = pos
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.0 if transparent_bg else 0.55)
	bg.border_color = Color(1, 1, 1, 0.0 if transparent_bg else 0.5)
	bg.set_border_width_all(0 if transparent_bg else 2)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	return b


func _set_ticks(bar: ProgressBar, marks: Array) -> void:
	for c in bar.get_children():
		c.queue_free()
	for mark: float in marks:
		var tick := ColorRect.new()
		tick.color = Color(1, 1, 1, 0.35)
		tick.size = Vector2(2, 12)
		var frac: float = mark / Fighter.MAX_KI
		tick.position = Vector2((1.0 - frac if bar.fill_mode == ProgressBar.FILL_END_TO_BEGIN else frac) * 300.0, 0)
		bar.add_child(tick)


## Player's U / I / O techniques drive ki ticks, the controls strip and the confirm prompt.
func setup_player_kit(moves: Dictionary) -> void:
	var marks: Array = []
	var line := ""
	for pair in [["U", &"tech1"], ["I", &"tech2"], ["O", &"tech3"]]:
		var t: MoveData = moves[pair[1]]
		marks.append(t.ki_cost)
		line += "[b]%s[/b] %s (%d ki, %s)   " % [pair[0], t.display_name, int(t.ki_cost), KIND_HINT.get(t.kind, "")]
	_set_ticks(_p_ki, marks)
	_controls.text = "[center]" + CONTROLS + line + "[b]Esc[/b] title[/center]"
	_confirm.text = "%s READY — press O" % (moves[&"tech3"] as MoveData).display_name.to_upper()


func setup_names(player_name: String, enemy_name: String, enemy_title: String = "") -> void:
	_p_name.text = player_name
	_e_name.text = enemy_name if enemy_title.is_empty() else "%s  ·  %s" % [enemy_title, enemy_name]


func set_round(n: int) -> void:
	_round.text = "WORLD TOURNAMENT  ·  ROUND %d / 3" % (n + 1)


func set_training() -> void:
	_round.text = "TRAINING MODE"
	_timer.text = "∞"


func set_timer(t: float) -> void:
	_timer.text = "%d" % ceili(t)


func set_player_hp(v: float, mx: float) -> void:
	_set_hp(_p_hp, _p_trail, v, mx)


func set_enemy_hp(v: float, mx: float) -> void:
	_set_hp(_e_hp, _e_trail, v, mx)


func _set_hp(bar: ProgressBar, trail: ProgressBar, v: float, mx: float) -> void:
	bar.max_value = mx
	trail.max_value = mx
	bar.value = v
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = Color(1.0, 0.75, 0.2) if v / mx > 0.3 else Color(1.0, 0.3, 0.2)
	if v >= trail.value:
		trail.value = v
		return
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(trail, "value", v, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func set_player_ki(v: float) -> void:
	_p_ki.value = v


func set_enemy_ki(v: float) -> void:
	_e_ki.value = v


func show_combo(side: int, hits: int) -> void:
	var l: Label = _combo[side]
	if _combo_tw.has(side):
		(_combo_tw[side] as Tween).kill()
	if hits < 2:
		var fade := create_tween()
		fade.tween_property(l, "modulate:a", 0.0, 0.4)
		_combo_tw[side] = fade
		return
	l.text = "%d HITS" % hits
	l.modulate.a = 1.0
	l.pivot_offset = Vector2(0 if side == 0 else 320, 30)
	l.scale = Vector2.ONE * 1.45
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	_combo_tw[side] = tw


func callout(side: int, text: String) -> void:
	var l: Label = _callout[side]
	l.text = text.to_upper() + "!"
	l.modulate = Color(1, 1, 1, 1)
	l.pivot_offset = Vector2(0 if side == 0 else 500, 24)
	l.scale = Vector2(1.6, 0.4)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)


func set_confirm(on: bool) -> void:
	_confirm.visible = on


func show_banner(text: String, duration: float = 1.5, color: Color = Color.WHITE) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.visible = true
	_banner.scale = Vector2.ONE * 1.6
	_banner.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.12)
	await get_tree().create_timer(duration, true, false, true).timeout
	_banner.visible = false


func show_controls(on: bool) -> void:
	_controls.visible = on
