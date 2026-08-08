class_name FootstepController
extends Node3D
## Surface-aware, 3D-positional footstep + body audio.
## Sounds come from the player's feet, route through a switchable audio bus
## (Default outdoors / Interior indoors), and change per surface.

const SURFACES := ["concrete", "metal", "wood", "grass"]

var _steps: Dictionary = {}          # surface -> Array[AudioStream]
var _land_stream: AudioStream
var _ladder_streams: Array = []
var _pool: Array[AudioStreamPlayer3D] = []
var _pool_i := 0
var _bus := "Master"


func _ready() -> void:
	_steps["concrete"] = _load_set(["step_1.wav", "step_2.wav", "step_3.wav", "step_4.wav"])
	_steps["metal"] = _load_set(["step_metal_1.wav", "step_metal_2.wav", "step_metal_3.wav"])
	_steps["wood"] = _load_set(["step_wood_1.wav", "step_wood_2.wav", "step_wood_3.wav"])
	_steps["grass"] = _load_set(["step_grass_1.wav", "step_grass_2.wav", "step_grass_3.wav"])
	_land_stream = load("res://assets/audio/land.wav")
	_ladder_streams = _load_set(["ladder_1.wav", "ladder_2.wav"])
	for i in 4:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 6.0
		p.max_distance = 40.0
		add_child(p)
		_pool.append(p)


func _load_set(names: Array) -> Array:
	var out: Array = []
	for n in names:
		var s = load("res://assets/audio/%s" % n)
		if s:
			out.append(s)
	return out


func set_bus(bus_name: String) -> void:
	_bus = bus_name
	for p in _pool:
		p.bus = bus_name


func play_step(surface: String = "concrete", sprinting: bool = false, crouched: bool = false) -> void:
	var set: Array = _steps.get(surface, _steps["concrete"])
	if set.is_empty():
		return
	var vol := -8.0
	if sprinting:
		vol = -4.0
	elif crouched:
		vol = -16.0
	_play(set[randi() % set.size()], vol, randf_range(0.92, 1.08))


func play_land(surface: String = "concrete", hard: bool = false) -> void:
	_play(_land_stream, -2.0 if hard else -7.0, randf_range(0.95, 1.05))
	# double-hit with a surface step makes landings feel physical
	var set: Array = _steps.get(surface, _steps["concrete"])
	if not set.is_empty():
		_play(set[randi() % set.size()], -6.0, 0.85)


func play_ladder() -> void:
	if _ladder_streams.is_empty():
		return
	_play(_ladder_streams[randi() % _ladder_streams.size()], -8.0, randf_range(0.9, 1.1))


func _play(stream: AudioStream, volume_db: float, pitch: float) -> void:
	if stream == null:
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = _bus
	p.play()
