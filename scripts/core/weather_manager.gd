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
var rain_scale := 1.0  # set by graphics preset

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
var _bolt: Node3D
var _bolt_light: OmniLight3D


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

	# v1.17.0: a visible lightning bolt + its own flash light. The sky
	# brightening still goes through time_manager.weather_light - this
	# never touches the sun directly.
	_bolt = Node3D.new()
	_bolt.name = "LightningBolt"
	_bolt.visible = false
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.92, 0.95, 1.0)
	bm.emission_enabled = true
	bm.emission = Color(0.85, 0.9, 1.0)
	bm.emission_energy_multiplier = 6.0
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var y := 72.0
	var xoff := 0.0
	var zoff := 0.0
	while y > 6.0:
		var seg := MeshInstance3D.new()
		var box := BoxMesh.new()
		var step := rng.randf_range(9.0, 13.0)
		box.size = Vector3(0.45, step + 1.5, 0.45)
		box.material = bm
		seg.mesh = box
		seg.position = Vector3(xoff, y - step * 0.5, zoff)
		seg.rotation.z = rng.randf_range(-0.35, 0.35)
		seg.rotation.x = rng.randf_range(-0.2, 0.2)
		_bolt.add_child(seg)
		xoff += rng.randf_range(-3.5, 3.5)
		zoff += rng.randf_range(-2.5, 2.5)
		y -= step
	_bolt_light = OmniLight3D.new()
	_bolt_light.light_color = Color(0.8, 0.86, 1.0)
	_bolt_light.light_energy = 0.0
	_bolt_light.omni_range = 120.0
	_bolt_light.position = Vector3(0, 40, 0)
	_bolt.add_child(_bolt_light)
	add_child(_bolt)


func _process(delta: float) -> void:
	_next_change -= delta
	if _next_change <= 0.0:
		_set_state(_pick_next())
	var target: Dictionary = STATES[state]
	# Smooth transitions
	_light = lerpf(_light, target["light"], delta * 0.5)
	_fog = lerpf(_fog, target["fog"], delta * 0.4)
	_wet = lerpf(_wet, 1.0 if target["rain"] > 0 else 0.0, delta * 0.25)
	# Lightning: frequent in storms, occasional in plain rain
	if state == "storm" or state == "rain":
		_next_flash -= delta
		if _next_flash <= 0.0:
			_flash = 1.0
			_next_flash = randf_range(4.0, 11.0) if state == "storm" \
					else randf_range(10.0, 22.0)
			_strike()
			get_tree().create_timer(randf_range(0.4, 1.6)).timeout.connect(
					_thunder_snd.play)
	_flash = maxf(0.0, _flash - delta * 3.5)
	_bolt.visible = _flash > 0.45
	_bolt_light.light_energy = _flash * _flash * 9.0
	# Hand the result to the day/night cycle (single writer to the sky)
	time_manager.weather_light = _light + _flash * 1.8
	time_manager.weather_fog = _fog
	# Rain field follows the player
	if player:
		_rain_node.global_position = player.global_position + Vector3(0, 11, 0)
	var raining: int = target["rain"]
	_rain_node.emitting = raining > 0
	_rain_node.amount = maxi(int(raining * rain_scale), 1)
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


func _strike() -> void:
	## Drop the bolt somewhere near (but not on) the player
	if player == null:
		return
	var ang := randf() * TAU
	var dist := randf_range(45.0, 95.0)
	_bolt.global_position = player.global_position + \
			Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
	_bolt.rotation.y = randf() * TAU


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
