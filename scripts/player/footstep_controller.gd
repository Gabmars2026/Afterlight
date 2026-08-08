class_name FootstepController
extends Node
## Plays footstep and landing sounds. Attach as a child of the Player node.

var _steps: Array[AudioStream] = []
var _land: AudioStream
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in 4:
		_steps.append(load("res://assets/audio/step_%d.wav" % (i + 1)))
	_land = load("res://assets/audio/land.wav")
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)


func play_step(sprinting: bool) -> void:
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _steps[_rng.randi() % _steps.size()]
	p.pitch_scale = _rng.randf_range(0.92, 1.08)
	p.volume_db = -5.0 if sprinting else -9.0
	p.play()


func play_land(hard: bool) -> void:
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _land
	p.pitch_scale = _rng.randf_range(0.95, 1.05)
	p.volume_db = -2.0 if hard else -7.0
	p.play()
