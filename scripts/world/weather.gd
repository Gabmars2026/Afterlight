extends Node3D
## Phase 17: weather. A drifting cloud layer that wraps around the player
## and periodic rain showers with sound. Clouds darken while it rains and
## the fog thickens. Rain hides itself when the player is under a roof.

const CLOUD_COUNT := 22
const WRAP := 420.0

var player: Node3D
var environment: Environment

var _clouds: Array = []
var _cloud_mat := StandardMaterial3D.new()
var _wind := Vector3(2.6, 0.0, 1.2)
var _rain: CPUParticles3D
var _rain_sfx: AudioStreamPlayer
var _state := "clear"
var _timer := 55.0
var _wet := 0.0
var _base_fog := -1.0
var _roof_check := 0.0
var _under_roof := false


func _ready() -> void:
	# --- Cloud layer: puffy unshaded blobs, shared tintable material ---
	_cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cloud_mat.albedo_color = Color(1, 1, 1, 0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in CLOUD_COUNT:
		var cloud := Node3D.new()
		for j in rng.randi_range(3, 5):
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radial_segments = 10
			sm.rings = 5
			var r := rng.randf_range(9.0, 22.0)
			sm.radius = r
			sm.height = r * 0.8
			sm.material = _cloud_mat
			mi.mesh = sm
			mi.position = Vector3(rng.randf_range(-20, 20),
					rng.randf_range(-3, 3), rng.randf_range(-14, 14))
			mi.scale = Vector3(1.6, 0.5, 1.2)
			cloud.add_child(mi)
		cloud.position = Vector3(rng.randf_range(-WRAP, WRAP),
				rng.randf_range(65.0, 95.0), rng.randf_range(-WRAP, WRAP))
		add_child(cloud)
		_clouds.append(cloud)

	# --- Rain particles: follow the player, fall as thin streaks ---
	_rain = CPUParticles3D.new()
	_rain.emitting = false
	_rain.amount = 800
	_rain.lifetime = 1.0
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(16, 1, 16)
	_rain.direction = Vector3(0, -1, 0)
	_rain.spread = 2.0
	_rain.initial_velocity_min = 16.0
	_rain.initial_velocity_max = 20.0
	_rain.gravity = Vector3(0, -20, 0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.55)
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(0.7, 0.78, 0.9, 0.5)
	rmat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	quad.material = rmat
	_rain.mesh = quad
	add_child(_rain)

	# --- Rain sound (code-side loop) ---
	var ws: AudioStreamWAV = load("res://assets/audio/rain_loop.wav")
	if ws:
		ws.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ws.loop_end = ws.data.size() / 2
		_rain_sfx = AudioStreamPlayer.new()
		_rain_sfx.stream = ws
		_rain_sfx.volume_db = -60.0
		add_child(_rain_sfx)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var ppos: Vector3 = player.global_position

	# Drift clouds with the wind, wrapping around the player
	for c in _clouds:
		c.position += _wind * delta
		if c.position.x - ppos.x > WRAP:
			c.position.x -= WRAP * 2.0
		elif ppos.x - c.position.x > WRAP:
			c.position.x += WRAP * 2.0
		if c.position.z - ppos.z > WRAP:
			c.position.z -= WRAP * 2.0
		elif ppos.z - c.position.z > WRAP:
			c.position.z += WRAP * 2.0

	# Shower state machine
	_timer -= delta
	if _timer <= 0.0:
		if _state == "clear":
			_state = "rain"
			_timer = randf_range(45.0, 80.0)
		else:
			_state = "clear"
			_timer = randf_range(80.0, 150.0)
	_wet = move_toward(_wet, 1.0 if _state == "rain" else 0.0, delta / 3.0)

	# Roof test: no rain streaks indoors
	_roof_check -= delta
	if _roof_check <= 0.0:
		_roof_check = 0.3
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(
				ppos + Vector3(0, 0.5, 0), ppos + Vector3(0, 40, 0), 1)
		_under_roof = not space.intersect_ray(q).is_empty()

	# Apply
	_rain.position = ppos + Vector3(0, 11, 0)
	_rain.emitting = _wet > 0.05 and not _under_roof
	_cloud_mat.albedo_color = Color(1, 1, 1, 0.8).lerp(
			Color(0.4, 0.42, 0.48, 0.95), _wet)
	if environment:
		if _base_fog < 0.0:
			_base_fog = environment.fog_density
		environment.fog_density = lerpf(_base_fog, _base_fog * 2.5 + 0.004, _wet)
	if _rain_sfx:
		var vol := clampf(_wet, 0.0001, 1.0) * (0.35 if _under_roof else 1.0)
		_rain_sfx.volume_db = linear_to_db(maxf(vol, 0.0001)) - 6.0
		if _wet > 0.02 and not _rain_sfx.playing:
			_rain_sfx.play()
		elif _wet <= 0.02 and _rain_sfx.playing:
			_rain_sfx.stop()


## Debug helper: force a state immediately.
func force_weather(state: String) -> void:
	_state = state
	_timer = 9999.0
	_wet = 1.0 if state == "rain" else 0.0
