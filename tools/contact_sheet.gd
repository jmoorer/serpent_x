extends SceneTree

## Renders bots posed at a clip's impact (or a given fraction) into a PNG grid.
## Run windowed: godot --path . --script res://tools/contact_sheet.gd -- <out.png> [clip ...]

const LIB := "res://assets/anims/fighter_anims.res"
const RIG := "res://assets/third_party/mixamo/y-bot/Y Bot.fbx"
const COLS := 8
const SPACING := 2.2

var _out := "/tmp/contact.png"
var _frames := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var lib := load(LIB) as AnimationLibrary
	var names: Array = []
	if args.size() > 1:
		names = args.slice(1)
	else:
		for n in lib.get_animation_list():
			if lib.get_animation(n).has_meta(&"impact"):
				names.append(String(n))

	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.17, 0.2)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -60, 0)
	world.add_child(sun)

	var rows := int(ceil(names.size() / float(COLS)))
	for i in names.size():
		var clip := String(names[i])
		var forced_t := -1.0
		if clip.contains("@"):
			forced_t = clip.get_slice("@", 1).to_float()
			clip = clip.get_slice("@", 0)
		var a := lib.get_animation(StringName(clip))
		var bot := (load(RIG) as PackedScene).instantiate() as Node3D
		world.add_child(bot)
		bot.position = Vector3((i % COLS) * SPACING, -(i / COLS) * 2.6, 0)
		bot.rotation_degrees.y = 90.0
		var old := bot.get_node_or_null("AnimationPlayer")
		if old:
			old.free()
		var ap := AnimationPlayer.new()
		bot.add_child(ap)
		ap.add_animation_library(&"", lib)
		var t: float = forced_t if forced_t >= 0.0 else a.get_meta(&"impact", a.length * 0.5)
		ap.play(StringName(clip))
		ap.seek(t, true)
		ap.pause()
		var label := Label3D.new()
		label.text = "%s %.2f %s" % [clip, t, a.get_meta(&"limb", "")]
		label.font_size = 40
		label.pixel_size = 0.004
		label.position = Vector3(0, 2.05, 0)
		label.rotation_degrees.y = -90.0
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		bot.add_child(label)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(rows * 2.6, COLS * SPACING * 9.0 / 16.0) + 0.6
	cam.position = Vector3((COLS - 1) * SPACING * 0.5, -(rows - 1) * 2.6 * 0.5 + 1.0, 20)
	world.add_child(cam)
	cam.current = true
	root.size = Vector2i(1920, 1080)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 8:
		var img := root.get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out)
		return true
	return false
