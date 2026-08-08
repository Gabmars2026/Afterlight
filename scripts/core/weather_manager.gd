extends Node
## Weather system (Phase 13). Cycles clear / overcast / fog / rain / storm.
## Dims the sun through TimeManager, thickens fog, follows the player with
## a rain particle field, plays rain + thunder, wets surfaces (roughness),
## and dampens zombie sight/hearing while it rains.

signal weather_changed(label: String)

const STATES := {
	"clear": {"label": "", "light": 1.0, "fog": 0.0, "rain": 0},
	"overcast": {"label": "OVERCAST", "light": 0.72, "fog": 0.004, "rain": 0},
	"fog": {"label": "FOG", "light": 0.78, "fog": 0.05, "rain": 0},
	"rain": {"label": "RAIN", "light": 0.58, "fog": 0.012, "rain": 420},
	"storm": {"label": "STORM", "light": 0.42, "fog": 0.02, "rain": 850},
}

var time_manager: Node
var player: Node3D
var wet_mats: Array = []

var state := "clear"
var _light := 1.0
var _fog := 0.0
var _wet := 0.0
var _next_change := 60.0
var _flash := 0.0
var _next_flash := 6.0
var _rain_node: CPUParticles3D
var _rain_snd: AudioStreamPlayer
var _thunder_snd: AudioStreamPlayer


func _ready() -> void:
	_rain_node = CPUParticles3D.new()
	_rain_node.amount = 500
	_rain_node.lifetime = 1.1
	_rain_node.emitting = false
	_rain_node.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain_node.emission_box_extents = Vector3(16, 1, 16)
	_rain_node.direction = Vector3(0, -1, 0)
	_rain_node.spread = 3.0
	_rain_node.initial_velocity_min = 17.0
	_rain_node.initial_velocity_max = 20.0
	_rain_node.gravity = Vector3(0, -9, 0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.02, 0.35, 0.02)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.78, 0.9, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	_rain_node.mesh = mesh
	add_child(_rain_node)

	_rain_snd = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = load("res://assets/audio/rain_loop.wav")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	_rain_snd.stream = stream
	_rain_snd.volume_db = -80.0
	add_child(_rain_snd)

	_thunder_snd = AudioStreamPlayer.new()
	_thunder_snd.stream = load("res://assets/audio/thunder.wav")
	_thunder_snd.volume_db = -2.0
	add_child(_thunder_snd)


func _process(delta: float) -> void:
	_next_change -= delta
	if _next_change <= 0.0:
		_set_state(_pick_next())
	var target: Dictionary = STATES[state]
	# Smooth transitions
	_light = lerpf(_light, target["light"], delta * 0.5)
	_fog = lerpf(_fog, target["fog"], delta * 0.4)
	_wet = lerpf(_wet, 1.0 if target["rain"] > 0 else 0.0, delta * 0.25)
	# Lightning
	if state == "storm":
		_next_flash -= delta
		if _next_flash <= 0.0:
			_flash = 1.0
			_next_flash = randf_range(4.0, 11.0)
			get_tree().create_timer(randf_range(0.4, 1.6)).timeout.connect(
					_thunder_snd.play)
	_flash = maxf(0.0, _flash - delta * 3.5)
	# Hand the result to the day/night cycle (single writer to the sky)
	time_manager.weather_light = _light + _flash * 1.8
	time_manager.weather_fog = _fog
	# Rain field follows the player
	if player:
		_rain_node.global_position = player.global_position + Vector3(0, 11, 0)
	var raining: int = target["rain"]
	_rain_node.emitting = raining > 0
	_rain_node.amount = maxi(raining, 1)
	_rain_snd.volume_db = lerpf(_rain_snd.volume_db,
			(-8.0 if raining > 500 else -14.0) if raining > 0 else -80.0,
			delta * 1.5)
	if raining > 0 and not _rain_snd.playing:
		_rain_snd.play()
	elif raining == 0 and _rain_snd.playing and _rain_snd.volume_db < -60.0:
		_rain_snd.stop()
	# Wet surfaces: sun glints off the ground while/after it rains
	for m in wet_mats:
		m.roughness = lerpf(1.0, 0.5, _wet)


func _pick_next() -> String:
	var roll := randf()
	if roll < 0.38:
		return "clear"
	if roll < 0.58:
		return "overcast"
	if roll < 0.73:
		return "fog"
	if roll < 0.91:
		return "rain"
	return "storm"


func _set_state(new_state: String) -> void:
	state = new_state
	_next_change = randf_range(90.0, 200.0)
	_next_flash = randf_range(2.0, 6.0)
	weather_changed.emit(STATES[state]["label"])
	get_tree().call_group("enemies", "set_rain", STATES[state]["rain"] > 0)


func serialize() -> String:
	return state


func restore(data: String) -> void:
	if STATES.has(data):
		_set_state(data)
