class_name TrainingSession
extends Node

## Training mode: dummy behaviour picker, HP refill, infinite ki, position reset,
## status panel with last-combo damage, and the on-screen move list.

const REFILL_DELAY := 0.8
const GOLD_HEX := "#ffd24d"
const DIM_HEX := "#bdb6a8"
## Keys 1-9, then 0 for the tenth mode.
const KEY_LABELS := ["Stand", "Block", "After hit", "Random", "Hop", "Jab", "CPU", "Tech", "Wakeup", "Throw"]

var player: Fighter
var enemy: Fighter
var dummy: TrainingDummy
var infinite_ki: bool = true
var move_list: MoveList
var _spawn_p: Vector3
var _spawn_e: Vector3
var _calm := {}
var _combo_hits: int = 0
var _combo_dmg: float = 0.0
var _status: RichTextLabel


func setup(p: Fighter, e: Fighter, hud: CanvasLayer, cpu_profile: Dictionary, spawn_p: Vector3, spawn_e: Vector3) -> void:
	player = p
	enemy = e
	_spawn_p = spawn_p
	_spawn_e = spawn_e
	for f: Fighter in [p, e]:
		f.immortal = true
		_calm[f] = 0.0
	dummy = TrainingDummy.new()
	add_child(dummy)
	dummy.setup(e, cpu_profile)
	e.got_hit.connect(_on_dummy_hit)
	_build_ui(hud)
	move_list.build(p.moves, String(GameState.loadout()["name"]), p.power)
	_refresh()


func _build_ui(hud: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(40, 100)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(6)
	bg.content_margin_left = 10
	bg.content_margin_right = 10
	bg.content_margin_top = 6
	bg.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", bg)
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.fit_content = true
	_status.scroll_active = false
	_status.custom_minimum_size = Vector2(470, 0)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_font_size_override("normal_font_size", 14)
	_status.add_theme_font_size_override("bold_font_size", 14)
	_status.add_theme_color_override("default_color", Color(0.95, 0.92, 0.86))
	panel.add_child(_status)
	hud.add_child(panel)

	move_list = MoveList.new()
	move_list.anchor_left = 1.0
	move_list.anchor_right = 1.0
	move_list.anchor_top = 1.0
	move_list.anchor_bottom = 1.0
	move_list.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	move_list.grow_vertical = Control.GROW_DIRECTION_BEGIN
	move_list.offset_left = -24
	move_list.offset_right = -24
	move_list.offset_top = -20
	move_list.offset_bottom = -20
	hud.add_child(move_list)


func _physics_process(delta: float) -> void:
	for f: Fighter in [player, enemy]:
		_calm[f] = 0.0 if f.is_stunned() else _calm[f] + delta
		if _calm[f] >= REFILL_DELAY and f.hp < f.max_hp:
			f.hp = f.max_hp
			f.hp_changed.emit(f.hp)
		if infinite_ki and f.ki < Fighter.MAX_KI:
			f.ki = Fighter.MAX_KI
			f.ki_changed.emit(f.ki)


func _on_dummy_hit(attacker: Fighter, dealt: float) -> void:
	if attacker != player:
		return
	if player.combo_count == 0:
		_combo_dmg = 0.0
	_combo_dmg += dealt
	_combo_hits = player.combo_count + 1
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var k := key.physical_keycode
	if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < KEY_LABELS.size():
		dummy.set_mode((k - KEY_1) as TrainingDummy.Mode)
	elif k == KEY_0 and KEY_LABELS.size() >= 10:
		dummy.set_mode(9 as TrainingDummy.Mode)
	elif k == KEY_F:
		infinite_ki = not infinite_ki
	elif k == KEY_R:
		reset_positions()
	elif k == KEY_TAB:
		move_list.visible = not move_list.visible
	else:
		return
	get_viewport().set_input_as_handled()
	Sfx.play(&"whoosh", -14.0)
	_refresh()


func reset_positions() -> void:
	player.reset_to(_spawn_p)
	enemy.reset_to(_spawn_e)
	dummy.set_mode(dummy.mode)


func _refresh() -> void:
	var keys := ""
	for i in KEY_LABELS.size():
		var on := i == int(dummy.mode)
		keys += "[color=%s][b]%d[/b] %s[/color]   " % [GOLD_HEX if on else DIM_HEX, (i + 1) % 10, KEY_LABELS[i]]
	var t := "[b][color=%s]TRAINING[/color]   Dummy: %s[/b]\n" % [GOLD_HEX, dummy.mode_name()]
	t += keys + "\n"
	t += "[color=%s][b]F[/b] infinite ki: %s   [b]R[/b] reset   [b]Tab[/b] move list   [b]Esc[/b] title[/color]\n" % [
		DIM_HEX, "ON" if infinite_ki else "OFF"]
	t += "Last combo: [b]%d[/b] hits · [b]%d[/b] dmg" % [_combo_hits, roundi(_combo_dmg)]
	_status.text = t
