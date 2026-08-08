extends Node3D
## AFTERLIGHT Phase 1 test zone: a greybox movement course.
## Builds all geometry in code so the project stays text-only and robust.

const PlayerScene := preload("res://scripts/player/player.gd")
const HudScene := preload("res://scripts/ui/hud.gd")
const SlidingDoorScript := preload("res://scripts/world/sliding_door.gd")
const ToggleLampScript := preload("res://scripts/world/toggle_lamp.gd")

var player: Player
var hud: Hud

var _grid_mat: StandardMaterial3D
var _concrete_mat: StandardMaterial3D


func _ready() -> void:
	_setup_input()
	_build_environment()
	_build_course()

	player = PlayerScene.new()
	player.position = Vector3(0, 0.3, 8)
	add_child(player)

	hud = HudScene.new()
	add_child(hud)

	player.stamina.stamina_changed.connect(hud.set_stamina)
	player.stamina.exhausted_changed.connect(hud.set_exhausted)
	player.interaction_prompt.connect(hud.set_prompt)

	_start_ambience()


func _setup_input() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("jump", KEY_SPACE)
	_add_key("sprint", KEY_SHIFT)
	_add_key("crouch", KEY_CTRL)
	_add_key("interact", KEY_E)


func _add_key(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.52, 0.83)
	sky_mat.sky_horizon_color = Color(0.74, 0.82, 0.93)
	sky_mat.ground_bottom_color = Color(0.3, 0.34, 0.3)
	sky_mat.ground_horizon_color = Color(0.7, 0.77, 0.87)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.25
	env.fog_enabled = true
	env.fog_light_color = Color(0.76, 0.82, 0.92)
	env.fog_density = 0.0015
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 30, 0)
	sun.light_color = Color(1.0, 0.96, 0.89)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)

	_grid_mat = StandardMaterial3D.new()
	_grid_mat.albedo_texture = load("res://assets/textures/grid.png")
	_grid_mat.roughness = 0.9
	_grid_mat.uv1_triplanar = true
	_grid_mat.uv1_world_triplanar = true
	_grid_mat.uv1_scale = Vector3.ONE * 0.5

	_concrete_mat = StandardMaterial3D.new()
	_concrete_mat.albedo_texture = load("res://assets/textures/concrete.png")
	_concrete_mat.roughness = 0.95
	_concrete_mat.uv1_triplanar = true
	_concrete_mat.uv1_world_triplanar = true
	_concrete_mat.uv1_scale = Vector3.ONE * 0.25


func _build_course() -> void:
	# Ground
	_box(Vector3(90, 1, 90), Vector3(0, -0.5, 0), _concrete_mat)

	# --- Sprint lane with signs ---
	_sign("SPRINT: hold SHIFT", Vector3(0, 2.2, 2))

	# --- Crouch tunnel ---
	_sign("CROUCH: hold CTRL", Vector3(-10, 2.2, -6))
	_box(Vector3(6, 0.4, 6), Vector3(-10, 1.2, -10), _grid_mat, Color(0.8, 0.8, 0.9))
	_box(Vector3(0.4, 1.4, 6), Vector3(-13.2, 0.7, -10), _grid_mat)
	_box(Vector3(0.4, 1.4, 6), Vector3(-6.8, 0.7, -10), _grid_mat)

	# --- Slide bar (sprint + tap CTRL underneath) ---
	_sign("SLIDE: sprint + tap CTRL", Vector3(10, 2.4, -4))
	_box(Vector3(6, 0.35, 1.2), Vector3(10, 1.05, -8), _grid_mat, Color(0.95, 0.75, 0.5))
	_box(Vector3(0.5, 1.0, 1.2), Vector3(7.25, 0.5, -8), _grid_mat)
	_box(Vector3(0.5, 1.0, 1.2), Vector3(12.75, 0.5, -8), _grid_mat)

	# --- Jump gap platforms ---
	_sign("JUMP THE GAPS", Vector3(0, 3.0, -18))
	var heights := [0.6, 1.1, 1.7, 2.2]
	for i in 4:
		_box(Vector3(3, heights[i] * 2.0, 3), Vector3(-4.5 + i * 3.9, heights[i], -22), _grid_mat,
				Color(0.75 + i * 0.05, 0.8, 0.9))

	# --- Stairs up to a two-story building with rooftop ---
	for i in 8:
		_box(Vector3(3, 0.4, 1.0), Vector3(20, 0.2 + i * 0.4, -14 - i * 1.0), _grid_mat)
	# Building shell
	_box(Vector3(10, 0.5, 10), Vector3(20, 3.35, -27), _grid_mat, Color(0.85, 0.85, 0.9))  # floor 2
	_box(Vector3(10, 0.5, 10), Vector3(20, 6.7, -27), _concrete_mat)                        # roof
	_box(Vector3(0.5, 7, 10), Vector3(15.25, 3.5, -27), _grid_mat)                          # west wall
	_box(Vector3(0.5, 7, 10), Vector3(24.75, 3.5, -27), _grid_mat)                          # east wall
	_box(Vector3(10, 7, 0.5), Vector3(20, 3.5, -32.25), _grid_mat)                          # north wall
	# South wall with door opening
	_box(Vector3(3.4, 7, 0.5), Vector3(16.7, 3.5, -21.75), _grid_mat)
	_box(Vector3(3.4, 7, 0.5), Vector3(23.3, 3.5, -21.75), _grid_mat)
	_box(Vector3(3.2, 3.6, 0.5), Vector3(20, 5.2, -21.75), _grid_mat)

	# Sliding door in the opening
	var door := SlidingDoorScript.new()
	var door_mesh := MeshInstance3D.new()
	var door_box := BoxMesh.new()
	door_box.size = Vector3(3.2, 3.4, 0.3)
	door_mesh.mesh = door_box
	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.5, 0.32, 0.2)
	door_mat.roughness = 0.7
	door_mesh.material_override = door_mat
	var door_col := CollisionShape3D.new()
	var door_shape := BoxShape3D.new()
	door_shape.size = Vector3(3.2, 3.4, 0.3)
	door_col.shape = door_shape
	door.add_child(door_mesh)
	door.add_child(door_col)
	door.position = Vector3(20, 1.7, -21.75)
	add_child(door)
	_sign("USE THE DOOR (E)", Vector3(20, 4.6, -20.5))

	# Interior lamp + switch
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.light_energy = 2.4
	lamp.omni_range = 9.0
	lamp.position = Vector3(20, 2.6, -27)
	add_child(lamp)

	var switch := ToggleLampScript.new()
	switch.lamp = lamp
	var sw_mesh := MeshInstance3D.new()
	var sw_box := BoxMesh.new()
	sw_box.size = Vector3(0.25, 0.4, 0.12)
	sw_mesh.mesh = sw_box
	var sw_mat := StandardMaterial3D.new()
	sw_mat.albedo_color = Color(0.9, 0.2, 0.15)
	sw_mat.emission_enabled = true
	sw_mat.emission = Color(0.9, 0.2, 0.15)
	sw_mat.emission_energy_multiplier = 0.6
	sw_mesh.material_override = sw_mat
	var sw_col := CollisionShape3D.new()
	var sw_shape := BoxShape3D.new()
	sw_shape.size = Vector3(0.3, 0.45, 0.2)
	sw_col.shape = sw_shape
	switch.add_child(sw_mesh)
	switch.add_child(sw_col)
	switch.position = Vector3(16.0, 1.4, -22.1)
	add_child(switch)

	# Boundary walls
	_box(Vector3(90, 4, 1), Vector3(0, 2, 45), _concrete_mat)
	_box(Vector3(90, 4, 1), Vector3(0, 2, -45), _concrete_mat)
	_box(Vector3(1, 4, 90), Vector3(45, 2, 0), _concrete_mat)
	_box(Vector3(1, 4, 90), Vector3(-45, 2, 0), _concrete_mat)


func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D, tint := Color.WHITE) -> void:
	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	var use_mat := mat
	if tint != Color.WHITE:
		use_mat = mat.duplicate()
		use_mat.albedo_color = tint
	mesh_instance.material_override = use_mat
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(mesh_instance)
	body.add_child(col)
	body.position = pos
	add_child(body)


func _sign(text: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1, 1, 1, 0.95)
	label.outline_size = 12
	label.position = pos
	add_child(label)


func _start_ambience() -> void:
	var wind := AudioStreamPlayer.new()
	var stream: AudioStreamWAV = load("res://assets/audio/wind_loop.wav")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	wind.stream = stream
	wind.volume_db = -18.0
	wind.autoplay = true
	add_child(wind)
	wind.play()
