extends Node3D

const ROUND_TIME := 75.0
const FIGHTER_SCENE := preload("res://actors/fighter.tscn")

enum Phase { INTRO, FIGHT, KO, RESULT }

var phase: Phase = Phase.INTRO
var time_left: float = ROUND_TIME
var player: Fighter
var enemy: Fighter
var ai: AIController
var training: TrainingSession
var _result_done: bool = false

@onready var spawn_p: Marker3D = $SpawnPlayer
@onready var spawn_e: Marker3D = $SpawnEnemy
@onready var camera_rig: CameraRig = $CameraRig
@onready var hud: FightHUD = $HUD


func _ready() -> void:
	Feedback.reset()
	var profile := GameState.opponent_profile()
	_spawn_fighters(profile)
	camera_rig.bind(player, enemy)
	hud.setup_names("You", String(profile["display_name"]), String(profile["title"]))
	if GameState.training:
		_start_training(profile)
		return
	hud.set_round(GameState.round_index)
	hud.show_controls(GameState.showing_controls)
	GameState.showing_controls = false

	phase = Phase.INTRO
	camera_rig.focus(enemy)
	enemy.taunt()
	await hud.show_banner("ROUND %d" % (GameState.round_index + 1), 1.0)
	await hud.show_banner(String(profile["display_name"]).to_upper(), 0.9, Color(profile["aura"]))
	camera_rig.focus(null)
	await hud.show_banner("FIGHT!", 0.7, Color(1.0, 0.82, 0.3))
	Sfx.play(&"shock_small", -6.0)
	player.controllable = true
	enemy.controllable = true
	phase = Phase.FIGHT
	time_left = ROUND_TIME


func _start_training(profile: Dictionary) -> void:
	hud.set_training()
	hud.show_controls(false)
	training = TrainingSession.new()
	add_child(training)
	training.setup(player, enemy, hud, profile, spawn_p.global_position, spawn_e.global_position)
	player.controllable = true
	enemy.controllable = true
	phase = Phase.FIGHT
	hud.show_banner("TRAINING", 0.8, Color(1.0, 0.82, 0.3))


func _spawn_fighters(profile: Dictionary) -> void:
	var look := GameState.loadout()
	player = FIGHTER_SCENE.instantiate() as Fighter
	player.is_player = true
	player.team = 1
	player.display_name = "You"
	player.max_hp = float(look["max_hp"])
	player.speed_mult = float(look["speed"])
	player.power = float(look["power"])
	add_child(player)
	player.global_position = spawn_p.global_position
	player.setup_look(look["body"], look["style"], look["main"], look["accent"], look["aura"], look["techs"])
	hud.setup_player_kit(player.moves)

	enemy = FIGHTER_SCENE.instantiate() as Fighter
	enemy.is_player = false
	enemy.team = 2
	enemy.display_name = String(profile["display_name"])
	enemy.max_hp = float(profile["max_hp"])
	add_child(enemy)
	enemy.global_position = spawn_e.global_position
	enemy.setup_look(profile["body"], profile["style"], profile["main"], profile["accent"], profile["aura"])

	player.opponent = enemy
	enemy.opponent = player
	player.refill()
	enemy.refill()

	if not GameState.training:
		ai = AIController.new()
		add_child(ai)
		ai.setup(enemy, profile)

	player.hp_changed.connect(func (v: float) -> void: hud.set_player_hp(v, player.max_hp))
	enemy.hp_changed.connect(func (v: float) -> void: hud.set_enemy_hp(v, enemy.max_hp))
	player.ki_changed.connect(hud.set_player_ki)
	enemy.ki_changed.connect(hud.set_enemy_ki)
	player.combo_changed.connect(func (h: int) -> void: hud.show_combo(0, h))
	enemy.combo_changed.connect(func (h: int) -> void: hud.show_combo(1, h))
	player.technique_used.connect(func (n: String) -> void: hud.callout(0, n))
	enemy.technique_used.connect(func (n: String) -> void: hud.callout(1, n))
	player.died.connect(_on_fighter_died.bind(false))
	enemy.died.connect(_on_fighter_died.bind(true))

	hud.set_player_hp(player.hp, player.max_hp)
	hud.set_enemy_hp(enemy.hp, enemy.max_hp)
	hud.set_player_ki(0.0)
	hud.set_enemy_ki(0.0)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		GameState.go_title()
		return
	if phase != Phase.FIGHT:
		return
	hud.set_confirm(player.confirm_ready and player.ki >= (player.moves[&"tech3"] as MoveData).ki_cost)
	if training:
		return
	time_left = maxf(time_left - delta, 0.0)
	hud.set_timer(time_left)
	if time_left <= 0.0:
		_finish_round(player.hp >= enemy.hp, true)


func _on_fighter_died(player_won: bool) -> void:
	if phase != Phase.FIGHT:
		return
	_finish_round(player_won, false)


func _finish_round(won: bool, timeout: bool) -> void:
	if _result_done:
		return
	_result_done = true
	phase = Phase.KO
	hud.set_confirm(false)
	player.controllable = false
	enemy.controllable = false
	if not timeout:
		Feedback.slowmo(0.25, 1.1)
	await hud.show_banner("TIME!" if timeout else "K.O.!", 1.4, Color(1.0, 0.35, 0.25))
	phase = Phase.RESULT
	var winner := player if won else enemy
	winner.celebrate()
	camera_rig.focus(winner)
	if won:
		var was_final := GameState.round_index >= GameState.MAX_ROUNDS - 1
		GameState.notify_round_result(true)
		if was_final:
			await hud.show_banner("TOURNAMENT CHAMPION!", 3.0, Color(1.0, 0.82, 0.3))
			GameState.go_title()
		else:
			await hud.show_banner("YOU WIN", 1.6, Color(1.0, 0.82, 0.3))
			GameState.go_fight()
	else:
		await hud.show_banner("ELIMINATED", 2.2, Color(0.8, 0.8, 0.85))
		GameState.notify_round_result(false)
		GameState.go_title()
