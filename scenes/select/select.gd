extends Control

## School select: 4 loadout cards, live 3D preview running the school's kata, stats + technique list.

const GOLD := Color(1.0, 0.82, 0.3)
const STAT_MAX := {"max_hp": 150.0, "speed": 1.2, "power": 1.2}

var _index: int = 0
var _cards: Array[Button] = []
var _kata_i: int = 0
var _kata_left: float = 0.0
var _aura: CPUParticles3D
var _name: Label
var _tagline: Label
var _stats: Dictionary = {}
var _techs: RichTextLabel

@onready var preview: FighterModel = $Stage/Viewport/World/Preview
@onready var world: Node3D = $Stage/Viewport/World
@onready var cam: Camera3D = $Stage/Viewport/World/Camera3D


func _ready() -> void:
	Feedback.reset()
	preview.rotation.y = PI + 0.4
	cam.position = Vector3(-1.4, 1.65, 4.3)
	cam.look_at(Vector3(-1.4, 1.0, 0.0), Vector3.UP)
	_build_ui()
	_index = maxi(Loadouts.ORDER.find(GameState.player_loadout), 0)
	_cards[_index].grab_focus()
	_select(_index)


func _build_ui() -> void:
	var header := _label("TRAINING  ·  CHOOSE YOUR SCHOOL" if GameState.training else "CHOOSE YOUR SCHOOL", 44, GOLD)
	header.position = Vector2(60, 36)
	add_child(header)
	var goal := "start training" if GameState.training else "enter the tournament"
	var hint := _label("A / D or ← / → to browse   ·   Enter / J to %s   ·   Esc back" % goal, 15, Color(0.85, 0.82, 0.75))
	hint.position = Vector2(62, 96)
	add_child(hint)

	var panel := VBoxContainer.new()
	panel.position = Vector2(60, 140)
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_constant_override("separation", 8)
	add_child(panel)
	_name = _label("", 40, Color.WHITE)
	panel.add_child(_name)
	_tagline = _label("", 18, Color(0.92, 0.88, 0.8))
	panel.add_child(_tagline)
	panel.add_child(_spacer(10))
	for pair in [["HEALTH", "max_hp"], ["SPEED", "speed"], ["POWER", "power"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := _label(pair[0], 16, Color(0.85, 0.82, 0.75))
		l.custom_minimum_size = Vector2(90, 0)
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(300, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = 1.0
		bar.step = 0.0
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.55)
		bg.set_corner_radius_all(3)
		var fill := StyleBoxFlat.new()
		fill.bg_color = GOLD
		fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		panel.add_child(row)
		_stats[pair[1]] = bar
	panel.add_child(_spacer(12))
	_techs = RichTextLabel.new()
	_techs.bbcode_enabled = true
	_techs.fit_content = true
	_techs.custom_minimum_size = Vector2(520, 0)
	_techs.add_theme_font_size_override("normal_font_size", 18)
	_techs.add_theme_font_size_override("bold_font_size", 18)
	_techs.add_theme_color_override("default_color", Color(0.95, 0.92, 0.86))
	_techs.add_theme_constant_override("outline_size", 4)
	_techs.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	panel.add_child(_techs)

	var row := HBoxContainer.new()
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.offset_top = -150
	row.offset_bottom = -40
	row.offset_left = 60
	row.offset_right = -60
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	for i in Loadouts.ORDER.size():
		var d := Loadouts.get_data(Loadouts.ORDER[i])
		var b := Button.new()
		b.text = "%s\n%s" % [d["name"], _style_label(d["style"])]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_stylebox_override("normal", _card_style(Color(0.08, 0.07, 0.06, 0.8), Color(1, 1, 1, 0.25)))
		b.add_theme_stylebox_override("hover", _card_style(Color(0.14, 0.12, 0.1, 0.85), Color(d["aura"], 0.7)))
		b.add_theme_stylebox_override("focus", _card_style(Color(d["main"].darkened(0.35), 0.9), d["aura"], 4))
		b.add_theme_stylebox_override("pressed", _card_style(Color(d["main"], 0.9), d["aura"], 4))
		b.focus_entered.connect(_select.bind(i))
		b.mouse_entered.connect(b.grab_focus)
		b.pressed.connect(_confirm)
		row.add_child(b)
		_cards.append(b)


func _style_label(style: StringName) -> String:
	match style:
		&"capoeira":
			return "capoeira"
		&"boxer":
			return "boxing"
		&"brawler":
			return "elbows & knees"
		_:
			return "kung fu"


func _card_style(bg: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(6)
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(4, size / 7))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _select(i: int) -> void:
	var changed := i != _index or preview.body == null
	_index = i
	var id: StringName = Loadouts.ORDER[i]
	var d := Loadouts.get_data(id)
	_name.text = d["name"]
	_name.add_theme_color_override("font_color", d["aura"])
	_tagline.text = d["tagline"]
	for key: String in _stats:
		var bar: ProgressBar = _stats[key]
		var tw := create_tween()
		tw.tween_property(bar, "value", float(d[key]) / STAT_MAX[key], 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var moves := Moveset.build(d["style"], d["techs"])
	var text := ""
	for pair in [["U", &"tech1"], ["I", &"tech2"], ["O", &"tech3"]]:
		var t: MoveData = moves[pair[1]]
		text += "[b][color=#ffd24d]%s[/color]  %s[/b]  [color=#bdb6a8]%d ki · %s[/color]\n" % [
			pair[0], t.display_name, int(t.ki_cost), FightHUD.KIND_HINT.get(t.kind, "")]
	_techs.text = text
	if not changed:
		return
	preview.build(d["body"], d["main"], d["accent"])
	preview.play(Moveset.idle_clip(d["style"]), 0.0)
	preview.flash(d["aura"], 0.25, 2.0)
	if _aura:
		_aura.queue_free()
	_aura = Fx.make_aura(preview, d["aura"])
	_aura.emitting = true
	_kata_i = 0
	_kata_left = 0.5
	Sfx.play(&"whoosh", -10.0)


func _process(delta: float) -> void:
	_kata_left -= delta
	if _kata_left > 0.0:
		return
	var d := Loadouts.get_data(Loadouts.ORDER[_index])
	var kata: Array = d["kata"]
	if _kata_i % 2 == 1:
		preview.play(Moveset.idle_clip(d["style"]), 0.2)
		_kata_left = 0.7
	else:
		var clip: StringName = kata[(_kata_i / 2) % kata.size()]
		preview.play(clip, 0.15)
		_kata_left = preview.clip_length(clip) * 0.9
	_kata_i += 1


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		_cards[posmod(_index - 1, _cards.size())].grab_focus()
	elif event.is_action_pressed("move_right"):
		_cards[posmod(_index + 1, _cards.size())].grab_focus()
	elif event.is_action_pressed("light"):
		_confirm()
	elif event.is_action_pressed("pause"):
		GameState.go_title()


func _confirm() -> void:
	GameState.player_loadout = Loadouts.ORDER[_index]
	Sfx.play(&"shock_small", -4.0)
	if not GameState.training:
		GameState.reset_tournament()
	GameState.go_fight()
