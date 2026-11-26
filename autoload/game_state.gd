extends Node

signal tournament_won
signal eliminated
signal round_changed(round_index: int)

const MAX_ROUNDS := 3
const FIGHT_SCENE := "res://scenes/fight/fight.tscn"
const TITLE_SCENE := "res://scenes/title/title.tscn"
const SELECT_SCENE := "res://scenes/select/select.tscn"

var round_index: int = 0
var showing_controls: bool = true
var player_loadout: StringName = &"turtle"
var training: bool = false


func loadout() -> Dictionary:
	return Loadouts.get_data(player_loadout)


func reset_tournament() -> void:
	round_index = 0
	showing_controls = true
	round_changed.emit(round_index)


func advance_round() -> bool:
	round_index += 1
	if round_index >= MAX_ROUNDS:
		tournament_won.emit()
		return false
	round_changed.emit(round_index)
	return true


func notify_round_result(won: bool) -> void:
	if not won:
		eliminated.emit()
		return
	advance_round()


func go_title() -> void:
	Feedback.reset()
	Sfx.set_charging(false)
	get_tree().change_scene_to_file(TITLE_SCENE)


func go_select() -> void:
	Feedback.reset()
	Sfx.set_charging(false)
	get_tree().change_scene_to_file(SELECT_SCENE)


func go_fight() -> void:
	Feedback.reset()
	Sfx.set_charging(false)
	get_tree().change_scene_to_file(FIGHT_SCENE)


## Training partner; the AI fields drive the dummy's CPU mode.
func training_profile() -> Dictionary:
	return {
		"id": "dummy",
		"display_name": "Training Dummy",
		"title": "Sparring Partner",
		"body": &"y",
		"style": &"boxer",
		"main": Color(0.55, 0.55, 0.58),
		"accent": Color(0.3, 0.3, 0.34),
		"aura": Color(0.8, 0.85, 0.95),
		"max_hp": 150.0,
		"aggression": 0.55,
		"block_skill": 0.45,
		"string_len": 3,
		"tech_chance": 0.25,
		"air_chance": 0.3,
		"uses_tech2": true,
		"uses_rush": true,
		"uses_afterimage": true,
		"uses_charge": false,
	}


func opponent_profile() -> Dictionary:
	if training:
		return training_profile()
	match round_index:
		0:
			return {
				"id": "tinto",
				"display_name": "Tinto",
				"title": "Street Boxer",
				"body": &"y",
				"style": &"boxer",
				"main": Color(0.75, 0.75, 0.78),
				"accent": Color(0.75, 0.2, 0.15),
				"aura": Color(1.0, 0.55, 0.35),
				"max_hp": 100.0,
				"aggression": 0.35,
				"block_skill": 0.2,
				"string_len": 2,
				"tech_chance": 0.05,
				"uses_tech2": false,
				"uses_rush": false,
				"uses_afterimage": false,
				"uses_charge": false,
			}
		1:
			return {
				"id": "goro",
				"display_name": "Goro",
				"title": "Iron Bull",
				"body": &"y",
				"style": &"brawler",
				"main": Color(0.3, 0.55, 0.3),
				"accent": Color(0.85, 0.7, 0.25),
				"aura": Color(0.55, 1.0, 0.5),
				"max_hp": 125.0,
				"aggression": 0.55,
				"block_skill": 0.45,
				"string_len": 3,
				"tech_chance": 0.25,
				"air_chance": 0.12,
				"uses_tech2": true,
				"uses_rush": false,
				"uses_afterimage": false,
				"uses_charge": true,
			}
		_:
			return {
				"id": "riku",
				"display_name": "Riku",
				"title": "Crane Phantom",
				"body": &"y",
				"style": &"capoeira",
				"main": Color(0.45, 0.32, 0.75),
				"accent": Color(0.9, 0.9, 0.95),
				"aura": Color(0.75, 0.55, 1.0),
				"max_hp": 140.0,
				"aggression": 0.7,
				"block_skill": 0.55,
				"string_len": 4,
				"tech_chance": 0.4,
				"air_chance": 0.3,
				"uses_tech2": true,
				"uses_rush": true,
				"uses_afterimage": true,
				"uses_charge": true,
			}
