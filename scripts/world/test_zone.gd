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
const TargetDummyScript := preload("res://scripts/combat/target_dummy.gd")
const GeneratorPropScript := preload("res://scripts/world/generator_prop.gd")
const EnemySpawnerScript := preload("res://scripts/ai/enemy_spawner.gd")

var player: Player
var hud: Hud

var _grid_mat: StandardMaterial3D
var _concrete_mat: StandardMaterial3D
var _wind: AudioStreamPlayer
var _birds: AudioStreamPlayer
var _nav_region: NavigationRegion3D


func _ready() -> void:
	_setup_input()
	_setup_audio_buses()
	# All static geometry goes inside this region so the navmesh can be
	# baked from it at startup (zombies path across the whole map).
	_nav_region = NavigationRegion3D.new()
	add_child(_nav_region)
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
	player.weapons.ammo_changed.connect(hud.set_ammo)
	player.weapons._emit_ammo()
	player.health_changed.connect(hud.set_health)
	hud.set_health(player.health, Player.MAX_HEALTH)
	player.died.connect(_on_player_died)

	_build_interactives()
	_build_district()
	_bake_navmesh()
	_build_horde()


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
	_add_key("weapon_1", KEY_1)
	_add_key("weapon_2", KEY_2)
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
	## "Interior" bus: room reverb. "Tunnel" bus: strong underground echo.
	_make_reverb_bus("Interior", 0.8, 0.33, 0.4)
	_make_reverb_bus("Tunnel", 1.0, 0.55, 0.2)


func _make_reverb_bus(bus_name: String, room: float, wet: float, damping: float) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	var reverb := AudioEffectReverb.new()
	reverb.room_size = room
	reverb.wet = wet
	reverb.damping = damping
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
	interior.ambience = [_wind, _birds]
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
	_nav_region.add_child(body)
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

	# Daytime birds (ducked automatically when indoors)
	_birds = AudioStreamPlayer.new()
	var bird_stream: AudioStreamWAV = load("res://assets/audio/birds_loop.wav")
	bird_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	bird_stream.loop_end = bird_stream.data.size() / 2
	_birds.stream = bird_stream
	_birds.volume_db = -16.0
	_birds.autoplay = true
	add_child(_birds)
	_birds.play()

# ------------------------------------------------------------------ district

func _build_district() -> void:
	## Phase 2 additions: 3-floor apartment block with interior stairs,
	## balcony fire escape and rooftop; street cars; echo tunnel; shooting
	## range with target dummies; generator that powers a floodlight.
	var bx := -28.0
	var bz := -28.0
	_sign("APARTMENT BLOCK: 3 FLOORS + ROOF", Vector3(bx + 9, 4.2, bz + 4))

	# --- Walls (west + north solid) ---
	_box(Vector3(0.5, 9.4, 12), Vector3(bx - 5.75, 4.7, bz), _grid_mat, Color(0.82, 0.78, 0.72))
	_box(Vector3(12, 9.4, 0.5), Vector3(bx, 4.7, bz + 5.75), _grid_mat, Color(0.82, 0.78, 0.72))
	# East wall: full pieces + window column + door column
	_box(Vector3(0.5, 9.4, 2.6), Vector3(bx + 5.75, 4.7, bz - 4.7), _grid_mat, Color(0.82, 0.78, 0.72))
	_box(Vector3(0.5, 3.7, 1.4), Vector3(bx + 5.75, 1.85, bz - 2.7), _grid_mat, Color(0.82, 0.78, 0.72))
	_box(Vector3(0.5, 4.3, 1.4), Vector3(bx + 5.75, 7.25, bz - 2.7), _grid_mat, Color(0.82, 0.78, 0.72))
	_box(Vector3(0.5, 9.4, 2.5), Vector3(bx + 5.75, 4.7, bz - 0.75), _grid_mat, Color(0.82, 0.78, 0.72))
	_box(Vector3(0.5, 7.0, 1.8), Vector3(bx + 5.75, 5.9, bz + 1.4), _grid_mat, Color(0.82, 0.78, 0.72))
	_box(Vector3(0.5, 9.4, 3.7), Vector3(bx + 5.75, 4.7, bz + 4.15), _grid_mat, Color(0.82, 0.78, 0.72))
	# South wall: two full pieces + balcony window column
	_box(Vector3(5.3, 9.4, 0.5), Vector3(bx - 3.35, 4.7, bz - 5.75), _grid_mat, Color(0.82, 0.78, 0.72))
	_box(Vector3(5.3, 9.4, 0.5), Vector3(bx + 3.35, 4.7, bz - 5.75), _grid_mat, Color(0.82, 0.78, 0.72))
	_box(Vector3(1.4, 3.15, 0.5), Vector3(bx, 1.575, bz - 5.75), _grid_mat, Color(0.82, 0.78, 0.72))
	_box(Vector3(1.4, 4.15, 0.5), Vector3(bx, 7.325, bz - 5.75), _grid_mat, Color(0.82, 0.78, 0.72))

	# --- Floors with stair openings (wood) ---
	_box(Vector3(11.5, 0.3, 9.0), Vector3(bx, 3.0, bz - 1.25), _grid_mat, Color(0.7, 0.55, 0.4), "wood")
	_box(Vector3(6.25, 0.3, 2.5), Vector3(bx - 2.625, 3.0, bz + 4.5), _grid_mat, Color(0.7, 0.55, 0.4), "wood")
	_box(Vector3(11.5, 0.3, 9.0), Vector3(bx, 6.0, bz + 1.25), _grid_mat, Color(0.7, 0.55, 0.4), "wood")
	_box(Vector3(5.25, 0.3, 2.5), Vector3(bx + 3.125, 6.0, bz - 4.5), _grid_mat, Color(0.7, 0.55, 0.4), "wood")
	# Roof (concrete) with hatch hole in the north-east corner
	_box(Vector3(12.5, 0.4, 9.75), Vector3(bx, 9.2, bz - 1.25), _concrete_mat)
	_box(Vector3(9.75, 0.4, 2.75), Vector3(bx - 1.375, 9.2, bz + 4.875), _concrete_mat)

	# --- Stairs: ground -> floor 2 (along north wall, up eastward) ---
	for i in 10:
		_box(Vector3(0.9, 0.3 * (i + 1), 2.0),
				Vector3(bx - 4.05 + i * 0.9, 0.15 * (i + 1), bz + 4.5), _grid_mat)
	# --- Stairs: floor 2 -> floor 3 (along south wall, up westward) ---
	for i in 10:
		_box(Vector3(0.9, 0.3 * (i + 1), 2.0),
				Vector3(bx + 4.05 - i * 0.9, 3.15 + 0.15 * (i + 1), bz - 4.5), _grid_mat)

	# --- Interior lamps ---
	for h in [2.6, 5.5, 8.5]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.88, 0.7)
		lamp.light_energy = 1.6
		lamp.omni_range = 8.0
		lamp.position = Vector3(bx, h, bz)
		add_child(lamp)

	# --- Entrance door (slides up) ---
	var door := SlidingDoorScript.new()
	door.slide_offset = Vector3(0, 2.45, 0)
	var dm := MeshInstance3D.new()
	var dmesh := BoxMesh.new()
	dmesh.size = Vector3(0.25, 2.3, 1.7)
	dm.mesh = dmesh
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.35, 0.4, 0.45)
	dmat.metallic = 0.5
	dm.material_override = dmat
	var dc := CollisionShape3D.new()
	var dshape := BoxShape3D.new()
	dshape.size = Vector3(0.25, 2.3, 1.7)
	dc.shape = dshape
	door.add_child(dm)
	door.add_child(dc)
	door.position = Vector3(bx + 5.75, 1.2, bz + 1.4)
	door.set_meta("surface", "metal")
	add_child(door)

	# --- Breakable glass window (east wall, floor 2) ---
	var glass := GlassPaneScript.new()
	var gm := MeshInstance3D.new()
	var gmesh := BoxMesh.new()
	gmesh.size = Vector3(0.12, 1.4, 1.4)
	gm.mesh = gmesh
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.7, 0.85, 1.0, 0.3)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.metallic = 0.4
	gmat.roughness = 0.05
	gm.material_override = gmat
	var gc := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(0.12, 1.4, 1.4)
	gc.shape = gshape
	glass.add_child(gm)
	glass.add_child(gc)
	glass.position = Vector3(bx + 5.75, 4.4, bz - 2.7)
	add_child(glass)

	# --- Balcony (fire escape route: ground -> balcony -> roof) ---
	_sign("FIRE ESCAPE", Vector3(bx, 4.9, bz - 8.3))
	_box(Vector3(3, 0.3, 1.5), Vector3(bx, 3.15, bz - 6.75), _grid_mat, Color(0.6, 0.62, 0.68), "metal")
	_ladder(Vector3(bx - 1.7, 0, bz - 6.75), 3.9)
	_ladder(Vector3(bx + 1.7, 3.3, bz - 6.4), 6.4)

	# --- Roof hatch ladder (floor 3 -> roof, inside) ---
	_ladder(Vector3(bx + 4.8, 6.15, bz + 4.8), 3.6)

	# --- Rooftop gap jump to the adjacent tower ---
	_sign("GAP JUMP", Vector3(bx - 8.5, 10.4, bz))
	_box(Vector3(4.5, 8.7, 4.5), Vector3(bx - 9.5, 4.35, bz), _grid_mat, Color(0.68, 0.7, 0.78))

	# --- Interior audio zone (whole building) ---
	var interior := InteriorZoneScript.new()
	interior.ambience = [_wind, _birds]
	var iz_col := CollisionShape3D.new()
	var iz_shape := BoxShape3D.new()
	iz_shape.size = Vector3(11.4, 9.0, 11.4)
	iz_col.shape = iz_shape
	interior.add_child(iz_col)
	interior.position = Vector3(bx, 4.7, bz)
	add_child(interior)

	# --- Generator powering a floodlight over the entrance ---
	var flood := OmniLight3D.new()
	flood.light_color = Color(1.0, 0.95, 0.8)
	flood.light_energy = 3.0
	flood.omni_range = 12.0
	flood.position = Vector3(bx + 7.2, 3.8, bz + 1.4)
	add_child(flood)
	var gen := GeneratorPropScript.new()
	gen.powered_light = flood
	var genm := MeshInstance3D.new()
	var genmesh := BoxMesh.new()
	genmesh.size = Vector3(1.2, 0.9, 0.7)
	genm.mesh = genmesh
	genm.position.y = 0.45
	var genmat := StandardMaterial3D.new()
	genmat.albedo_color = Color(0.75, 0.25, 0.2)
	genmat.metallic = 0.5
	genmat.roughness = 0.5
	genm.material_override = genmat
	var genc := CollisionShape3D.new()
	var genshape := BoxShape3D.new()
	genshape.size = Vector3(1.2, 0.9, 0.7)
	genc.shape = genshape
	genc.position.y = 0.45
	gen.add_child(genm)
	gen.add_child(genc)
	gen.position = Vector3(bx + 8.0, 0, bz - 3.0)
	add_child(gen)
	_sign("START THE GENERATOR (E)", Vector3(bx + 8.0, 1.9, bz - 3.0))

	# --- Street cars (climbable) ---
	_car(Vector3(-12, 0, -14), 0.35, Color(0.55, 0.6, 0.68))
	_car(Vector3(-17, 0, -18), -0.2, Color(0.62, 0.4, 0.3))
	_sign("CLIMB THE CARS", Vector3(-14.5, 2.6, -16))

	# --- Echo tunnel (strong reverb) ---
	_sign("ECHO TUNNEL", Vector3(-3.5, 2.6, 32))
	_box(Vector3(18, 3, 0.4), Vector3(7, 1.5, 30.7), _concrete_mat)
	_box(Vector3(18, 3, 0.4), Vector3(7, 1.5, 33.3), _concrete_mat)
	_box(Vector3(18, 0.4, 3.0), Vector3(7, 3.2, 32), _concrete_mat)
	for lx in [2.0, 12.0]:
		var tl := OmniLight3D.new()
		tl.light_color = Color(1.0, 0.8, 0.55)
		tl.light_energy = 1.4
		tl.omni_range = 6.0
		tl.position = Vector3(lx, 2.6, 32)
		add_child(tl)
	var tunnel := InteriorZoneScript.new()
	tunnel.bus_name = "Tunnel"
	tunnel.ambience = [_wind, _birds]
	var tz_col := CollisionShape3D.new()
	var tz_shape := BoxShape3D.new()
	tz_shape.size = Vector3(17.5, 2.9, 2.4)
	tz_col.shape = tz_shape
	tunnel.add_child(tz_col)
	tunnel.position = Vector3(7, 1.45, 32)
	add_child(tunnel)

	# --- Shooting range ---
	_sign("SHOOTING RANGE: 1/2 weapons, LMB fire, R reload", Vector3(34, 3.0, 12))
	for dpos in [Vector3(32, 0, 4), Vector3(35, 0, 0), Vector3(38, 0, -3)]:
		var dummy := TargetDummyScript.new()
		dummy.position = dpos
		add_child(dummy)
	# Impact-test boards: metal pings, wood knocks
	_box(Vector3(0.2, 1.4, 1.4), Vector3(41, 1.7, 4), _grid_mat, Color(0.6, 0.63, 0.7), "metal")
	_box(Vector3(0.2, 1.4, 1.4), Vector3(41, 1.7, 0), _grid_mat, Color(0.55, 0.4, 0.26), "wood")


func _car(pos: Vector3, yrot: float, color: Color) -> void:
	var car := StaticBody3D.new()
	car.set_meta("surface", "metal")
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = 0.6
	paint.roughness = 0.4
	var body := MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(4.2, 0.6, 1.9)
	bmesh.material = paint
	body.mesh = bmesh
	body.position.y = 0.55
	car.add_child(body)
	var cabin := MeshInstance3D.new()
	var cmesh := BoxMesh.new()
	cmesh.size = Vector3(2.0, 0.55, 1.7)
	cmesh.material = paint
	cabin.mesh = cmesh
	cabin.position = Vector3(-0.2, 1.125, 0)
	car.add_child(cabin)
	var wheel_mat := StandardMaterial3D.new()
	wheel_mat.albedo_color = Color(0.12, 0.12, 0.12)
	for wx in [-1.45, 1.45]:
		for wz in [-0.95, 0.95]:
			var wheel := MeshInstance3D.new()
			var wmesh := CylinderMesh.new()
			wmesh.top_radius = 0.32
			wmesh.bottom_radius = 0.32
			wmesh.height = 0.25
			wmesh.material = wheel_mat
			wheel.mesh = wmesh
			wheel.rotation.x = PI / 2.0
			wheel.position = Vector3(wx, 0.32, wz)
			car.add_child(wheel)
	var col1 := CollisionShape3D.new()
	var shape1 := BoxShape3D.new()
	shape1.size = Vector3(4.2, 0.6, 1.9)
	col1.shape = shape1
	col1.position.y = 0.55
	car.add_child(col1)
	var col2 := CollisionShape3D.new()
	var shape2 := BoxShape3D.new()
	shape2.size = Vector3(2.0, 0.55, 1.7)
	col2.shape = shape2
	col2.position = Vector3(-0.2, 1.125, 0)
	car.add_child(col2)
	car.position = pos
	car.rotation.y = yrot
	add_child(car)


func _ladder(base: Vector3, height: float) -> void:
	## Ladder visual (rails + rungs) plus a LadderZone the player climbs with W.
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.75, 0.3, 0.2)
	rail_mat.metallic = 0.5
	rail_mat.roughness = 0.5
	var visual := Node3D.new()
	visual.position = base
	for side in [-0.35, 0.35]:
		var rail := MeshInstance3D.new()
		var rail_box := BoxMesh.new()
		rail_box.size = Vector3(0.07, height, 0.07)
		rail.mesh = rail_box
		rail.material_override = rail_mat
		rail.position = Vector3(0, height * 0.5, side)
		visual.add_child(rail)
	for i in int(height / 0.36):
		var rung := MeshInstance3D.new()
		var rung_box := BoxMesh.new()
		rung_box.size = Vector3(0.06, 0.06, 0.7)
		rung.mesh = rung_box
		rung.material_override = rail_mat
		rung.position = Vector3(0, 0.3 + i * 0.36, 0)
		visual.add_child(rung)
	add_child(visual)
	var zone := LadderZoneScript.new()
	var zc := CollisionShape3D.new()
	var zshape := BoxShape3D.new()
	zshape.size = Vector3(1.0, height + 0.6, 1.0)
	zc.shape = zshape
	zone.add_child(zc)
	zone.position = base + Vector3(0, height * 0.5 + 0.2, 0)
	add_child(zone)


# ---------------------------------------------------------------- phase 3

func _bake_navmesh() -> void:
	## Bake a navigation mesh from all static colliders inside _nav_region.
	## One-time cost at startup; zombies use it to path around buildings.
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	# Values are exact multiples of cell size so nothing gets rounded away
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	_nav_region.navigation_mesh = nav_mesh
	_nav_region.bake_navigation_mesh(false)


func _build_horde() -> void:
	## Zombie spawn points. Shamblers: slow, tough, hit hard.
	## Stalkers: fast, fragile, see further. Respawn ~18 s after dying.
	_sign("!! INFESTED ZONE - ZOMBIES ROAM WEST !!", Vector3(-10, 3.0, -12))
	_spawner("shambler", Vector3(-16, 0.1, -20))
	_spawner("shambler", Vector3(-20, 0.1, 0))
	_spawner("shambler", Vector3(-34, 0.1, -10))
	_spawner("stalker", Vector3(-8, 0.1, -34))
	_spawner("stalker", Vector3(14, 0.1, 24))


func _spawner(kind: String, pos: Vector3) -> void:
	var s := EnemySpawnerScript.new()
	s.kind = kind
	s.position = pos
	add_child(s)


func _on_player_died() -> void:
	hud.show_death()
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		get_tree().reload_current_scene())
