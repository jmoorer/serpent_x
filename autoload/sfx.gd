extends Node

const SHOCK := "res://assets/third_party/vefects/easy-shockwaves-vfx-godot/Vefects/Easy Shockwaves VFX/Audio/WAV/"
const SOUNDS := {
	&"hit_light": "res://assets/audio/hit_light.wav",
	&"hit_heavy": "res://assets/audio/hit_heavy.wav",
	&"whoosh": "res://assets/audio/whoosh.wav",
	&"whoosh_big": "res://assets/audio/whoosh_big.wav",
	&"block": "res://assets/audio/block.wav",
	&"clash": "res://assets/audio/clash.wav",
	&"teleport": "res://assets/audio/teleport.wav",
	&"blast": "res://assets/audio/blast.wav",
	&"kiai": "res://assets/audio/kiai.wav",
	&"shock_small": SHOCK + "SFX_Vefects_Shockwave_01_500ms.wav",
	&"shock_mid": SHOCK + "SFX_Vefects_Shockwave_03_500ms.wav",
	&"shock_big": SHOCK + "SFX_Vefects_Shockwave_05_1s.wav",
	&"ko": SHOCK + "SFX_Vefects_Shockwave_02_1s.wav",
}
const POOL := 12

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _charge: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key: StringName in SOUNDS:
		_streams[key] = load(SOUNDS[key])
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	var loop := load("res://assets/audio/charge_loop.wav") as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = loop.get_length() * loop.mix_rate
	_charge = AudioStreamPlayer.new()
	_charge.stream = loop
	_charge.volume_db = -8.0
	add_child(_charge)


func play(key: StringName, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	var s: AudioStream = _streams.get(key)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func set_charging(on: bool) -> void:
	if on and not _charge.playing:
		_charge.play()
	elif not on and _charge.playing:
		_charge.stop()
