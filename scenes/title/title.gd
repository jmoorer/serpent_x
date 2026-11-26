extends Control

const KATA := [&"jab", &"cross", &"hook2", &"roundhouse2", &"idle_turtle", &"uppercut", &"spin_flip",
	&"idle_turtle", &"palm_blast", &"flying_kick", &"taunt", &"idle_turtle"]

var _kata_i: int = 0
var _kata_left: float = 1.0
var _orbit: float = 0.0

@onready var hero: FighterModel = $Stage/Viewport/World/Hero
@onready var rival: FighterModel = $Stage/Viewport/World/Rival
@onready var cam: Camera3D = $Stage/Viewport/World/Camera3D


func _ready() -> void:
	Feedback.reset()
	var look := GameState.loadout()
	hero.build(look["body"], look["main"], look["accent"])
	hero.play(&"idle_turtle", 0.0)
	rival.build(&"y", Color(0.45, 0.32, 0.75), Color(0.9, 0.9, 0.95))
	rival.play(&"idle_ginga", 0.0)
	$Menu/VBox/Play.pressed.connect(_on_play)
	$Menu/VBox/Training.pressed.connect(_on_training)
	$Menu/VBox/Quit.pressed.connect(_on_quit)
	$Menu/VBox/Play.grab_focus()
	var title := $Menu/VBox/TitleLabel as Label
	title.pivot_offset = title.size * 0.5
	title.scale = Vector2.ONE * 1.4
	title.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(title, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(title, "modulate:a", 1.0, 0.4)


func _process(delta: float) -> void:
	_kata_left -= delta
	if _kata_left <= 0.0:
		var clip: StringName = KATA[_kata_i]
		_kata_i = (_kata_i + 1) % KATA.size()
		hero.play(clip, 0.18)
		_kata_left = 0.8 if String(clip).begins_with("idle") else hero.clip_length(clip) * 0.92
	_orbit += delta * 0.12
	var center := Vector3(0.6, 1.0, 0)
	cam.position = center + Vector3(sin(_orbit) * 5.2, 0.6, cos(_orbit) * 5.2)
	cam.look_at(center, Vector3.UP)


func _on_play() -> void:
	Sfx.play(&"shock_small", -4.0)
	GameState.training = false
	GameState.go_select()


func _on_training() -> void:
	Sfx.play(&"shock_small", -4.0)
	GameState.training = true
	GameState.go_select()


func _on_quit() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_play()
