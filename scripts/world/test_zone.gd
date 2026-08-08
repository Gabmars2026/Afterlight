extends Node3D
## AFTERLIGHT test zone: greybox movement + interaction + audio course.
## Builds all geometry in code so the project stays text-only and robust.

const PlayerScene := preload("res://scripts/player/player.gd")
const HudScene := preload("res://scripts/ui/hud.gd")
const PauseMenuScript := preload("res://scripts/ui/pause_menu.gd")
const SlidingDoorScript := preload("res://scripts/world/sliding_door.gd")
const ToggleLampScript := preload("res://scripts/world/toggle_lamp.gd")
const LootCrateScript := preload("res://scripts/world/loot_crate.gd")
const GlassPaneScript := preload("res://scripts/world/glass_pane.gd")
const LadderZoneScript := preload("res://scripts/world/ladder_zone.gd")
const InteriorZoneScript := preload("res://scripts/world/interior_zone.gd")

var player: Player
var hud: Hud

var _grid_mat: StandardMaterial3D
var _concrete_mat: StandardMaterial3D
var _wind: AudioStreamPlayer


func _ready() -> void:
	_setup_input()
	_setup_audio_buses()
	_build_environment()
	_build_course()
	_start_ambience()

	player = PlayerScene.new()
	player.position = Vector3(0, 0.3, 8)
	add_child(player)

	hud = HudScene.new()
	add_child(hud)

	add_child(PauseMenuScript.new())

	player.stamina.stamina_changed.connect(hud.set_stamina)
	player.stamina.exhausted_changed.connect(hud.set_exhausted)
	player.interaction_prompt.connect(hud.set_prompt)

	_build_interactives()


func _setup_input() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("jump", KEY_SPACE)
	_add_key("sprint", KEY_SHIFT)
	_add_key("crouch", KEY_CTRL)
	_add_key("interact", KEY_E)
	_add_key("reload", KEY_R)
	_add_key("inventory", KEY_TAB)
	_add_key("map", KEY_M)
	_add_mouse("fire", MOUSE_BUTTON_LEFT)
	_add_mouse("aim", MOUSE_BUTTON_RIGHT)


func _add_key(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _add_mouse(action: String, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _setup_audio_buses() -> void:
	## "Interior" bus: reverb for indoor spaces (InteriorZone routes to it).
	if AudioServer.get_bus_index("Interior") != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "Interior")
	AudioServer.set_bus_send(idx, "Master")
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.8
	reverb.wet = 0.33
	reverb.damping = 0.4
	AudioServer.add_bus_effect(idx, reverb)


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

	# --- Sprint lane + auto-vault obstacle ---
	_sign("SPRINT: hold SHIFT", Vector3(0, 2.2, 2))
	_sign("VAULT: sprint into it", Vector3(0, 1.9, -1))
	_box(Vector3(2.6, 0.75, 0.45), Vector3(0, 0.375, -3), _grid_mat, Color(0.95, 0.6, 0.4))

	# --- Grass patch (grass footsteps) ---
	_sign("GRASS", Vector3(-24, 1.6, 4))
	_box(Vector3(12, 0.12, 12), Vector3(-24, 0.06, 8), _grid_mat, Color(0.35, 0.62, 0.3), "grass")

	# --- Crawl vent (hold CTRL, then keep walking in) ---
	_sign("CRAWL VENT: crouch, walk in", Vector3(-20, 2.0, -4))
	_box(Vector3(0.3, 0.85, 4), Vector3(-21.0, 0.425, -8), _grid_mat, Color(0.6, 0.6, 0.68), "metal")
	_box(Vector3(0.3, 0.85, 4), Vector3(-19.0, 0.425, -8), _grid_mat, Color(0.6, 0.6, 0.68), "metal")
	_box(Vector3(2.3, 0.3, 4), Vector3(-20.0, 1.0, -8), _grid_mat, Color(0.55, 0.55, 0.62), "metal")
	_sign("NICE CRAWL", Vector3(-20, 1.6, -12))

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

	# --- Metal scaffold (mantle practice + metal footsteps) ---
	_sign("MANTLE: jump at the ledge", Vector3(10, 3.6, -14))
	_box(Vector3(3, 1.0, 3), Vector3(8, 0.5, -17), _grid_mat, Color(0.62, 0.64, 0.7), "metal")
	_box(Vector3(3, 2.0, 3), Vector3(12, 1.0, -17), _grid_mat, Color(0.58, 0.6, 0.66), "metal")

	# --- Jump gap platforms ---
	_sign("JUMP THE GAPS", Vector3(0, 3.0, -18))
	var heights := [0.6, 1.1, 1.7, 2.2]
	for i in 4:
		_box(Vector3(3, heights[i] * 2.0, 3), Vector3(-4.5 + i * 3.9, heights[i], -22), _grid_mat,
				Color(0.75 + i * 0.05, 0.8, 0.9))

	# --- Stairs up to the two-story building ---
	for i in 8:
		_box(Vector3(3, 0.4, 1.0), Vector3(20, 0.2 + i * 0.4, -14 - i * 1.0), _grid_mat)

	# --- Building shell (wood second floor, concrete roof) ---
	_box(Vector3(10, 0.5, 10), Vector3(20, 3.35, -27), _grid_mat, Color(0.72, 0.56, 0.4), "wood")  # floor 2
	_box(Vector3(10, 0.5, 10), Vector3(20, 6.7, -27), _concrete_mat)                        # roof
	_box(Vector3(0.5, 7, 10), Vector3(15.25, 3.5, -27), _grid_mat)                          # west wall
	_box(Vector3(0.5, 7, 10), Vector3(24.75, 3.5, -27), _grid_mat)                          # east wall
	_box(Vector3(10, 7, 0.5), Vector3(20, 3.5, -32.25), _grid_mat)                          # north wall
	# South wall: door opening at ground level + glass window at second floor
	_box(Vector3(3.4, 7, 0.5), Vector3(16.7, 3.5, -21.75), _grid_mat)
	_box(Vector3(3.4, 7, 0.5), Vector3(23.3, 3.5, -21.75), _grid_mat)
	_box(Vector3(0.7, 3.6, 0.5), Vector3(18.75, 5.2, -21.75), _grid_mat)   # window frame left
	_box(Vector3(0.7, 3.6, 0.5), Vector3(21.25, 5.2, -21.75), _grid_mat)   # window frame right
	_box(Vector3(1.8, 0.6, 0.5), Vector3(20, 3.7, -21.75), _grid_mat)      # window sill
	_box(Vector3(1.8, 1.4, 0.5), Vector3(20, 6.3, -21.75), _grid_mat)      # above window
	_sign("JUMP THROUGH THE GLASS", Vector3(20, 7.6, -20.2))

	# --- Rooftop gap jump tower ---
	_box(Vector3(5, 6.4, 5), Vector3(20, 3.2, -36.5), _grid_mat, Color(0.7, 0.72, 0.8))
	_sign("ROOFTOP GAP JUMP", Vector3(20, 8.4, -34.4))

	# Boundary walls
	_box(Vector3(90, 4, 1), Vector3(0, 2, 45), _concrete_mat)
	_box(Vector3(90, 4, 1), Vector3(0, 2, -45), _concrete_mat)
	_box(Vector3(1, 4, 90), Vector3(45, 2, 0), _concrete_mat)
	_box(Vector3(1, 4, 90), Vector3(-45, 2, 0), _concrete_mat)


func _build_interactives() -> void:
	# --- Sliding door (slides sideways, with sound) ---
	var door := SlidingDoorScript.new()
	door.slide_offset = Vector3(3.3, 0, 0)
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
	door.set_meta("surface", "metal")
	add_child(door)
	_sign("USE THE DOOR (E)", Vector3(20, 4.6, -20.5))

	# --- Interior lamp + switch ---
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

	# --- Loot crate (ground floor) ---
	var crate := LootCrateScript.new()
	var crate_mesh := MeshInstance3D.new()
	var crate_box := BoxMesh.new()
	crate_box.size = Vector3(0.9, 0.8, 0.9)
	crate_mesh.mesh = crate_box
	crate_mesh.position.y = 0.4
	var crate_mat := StandardMaterial3D.new()
	crate_mat.albedo_color = Color(0.45, 0.32, 0.2)
	crate_mat.roughness = 0.85
	crate_mesh.material_override = crate_mat
	var crate_col := CollisionShape3D.new()
	var crate_shape := BoxShape3D.new()
	crate_shape.size = Vector3(0.9, 0.8, 0.9)
	crate_col.shape = crate_shape
	crate_col.position.y = 0.4
	var lid_pivot := Node3D.new()
	lid_pivot.position = Vector3(0, 0.8, -0.45)
	var lid_mesh := MeshInstance3D.new()
	var lid_box := BoxMesh.new()
	lid_box.size = Vector3(0.95, 0.1, 0.95)
	lid_mesh.mesh = lid_box
	lid_mesh.position = Vector3(0, 0.05, 0.475)
	lid_mesh.material_override = crate_mat
	lid_pivot.add_child(lid_mesh)
	crate.add_child(crate_mesh)
	crate.add_child(crate_col)
	crate.add_child(lid_pivot)
	crate.lid = lid_pivot
	crate.position = Vector3(18, 0, -29)
	crate.set_meta("surface", "wood")
	add_child(crate)
	_sign("SEARCH THE CRATE (E)", Vector3(18, 1.8, -29))

	# --- Breakable glass window (second floor, above the stairs) ---
	var glass := GlassPaneScript.new()
	var glass_mesh := MeshInstance3D.new()
	var glass_box := BoxMesh.new()
	glass_box.size = Vector3(1.8, 1.6, 0.12)
	glass_mesh.mesh = glass_box
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.7, 0.85, 1.0, 0.3)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.metallic = 0.4
	glass_mat.roughness = 0.05
	glass_mesh.material_override = glass_mat
	var glass_col := CollisionShape3D.new()
	var glass_shape := BoxShape3D.new()
	glass_shape.size = Vector3(1.8, 1.6, 0.12)
	glass_col.shape = glass_shape
	glass.add_child(glass_mesh)
	glass.add_child(glass_col)
	glass.position = Vector3(20, 4.8, -21.75)
	add_child(glass)

	# --- Ladder up the east wall to the roof ---
	_sign("LADDER: walk in, hold W", Vector3(26.2, 2.4, -27))
	var ladder_visual := Node3D.new()
	ladder_visual.position = Vector3(25.15, 0, -27)
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.75, 0.3, 0.2)
	rail_mat.metallic = 0.5
	rail_mat.roughness = 0.5
	for side in [-0.35, 0.35]:
		var rail := MeshInstance3D.new()
		var rail_box := BoxMesh.new()
		rail_box.size = Vector3(0.07, 7.4, 0.07)
		rail.mesh = rail_box
		rail.material_override = rail_mat
		rail.position = Vector3(0.12, 3.7, side)
		ladder_visual.add_child(rail)
	for i in 20:
		var rung := MeshInstance3D.new()
		var rung_box := BoxMesh.new()
		rung_box.size = Vector3(0.06, 0.06, 0.7)
		rung.mesh = rung_box
		rung.material_override = rail_mat
		rung.position = Vector3(0.12, 0.35 + i * 0.36, 0)
		ladder_visual.add_child(rung)
	add_child(ladder_visual)

	var ladder_zone := LadderZoneScript.new()
	var lz_col := CollisionShape3D.new()
	var lz_shape := BoxShape3D.new()
	lz_shape.size = Vector3(1.1, 8.2, 1.1)
	lz_col.shape = lz_shape
	ladder_zone.add_child(lz_col)
	ladder_zone.position = Vector3(25.55, 4.1, -27)
	add_child(ladder_zone)

	# --- Interior audio zone (reverb + ducked wind inside the building) ---
	var interior := InteriorZoneScript.new()
	interior.wind_player = _wind
	var iz_col := CollisionShape3D.new()
	var iz_shape := BoxShape3D.new()
	iz_shape.size = Vector3(9.4, 6.4, 9.4)
	iz_col.shape = iz_shape
	interior.add_child(iz_col)
	interior.position = Vector3(20, 3.5, -27)
	add_child(interior)


func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D, tint := Color.WHITE,
		surface := "concrete") -> StaticBody3D:
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
	body.set_meta("surface", surface)
	add_child(body)
	return body


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
	_wind = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = load("res://assets/audio/wind_loop.wav")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	_wind.stream = stream
	_wind.volume_db = -18.0
	_wind.autoplay = true
	add_child(_wind)
	_wind.play()
