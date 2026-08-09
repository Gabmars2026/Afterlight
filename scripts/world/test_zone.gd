extends Node3D
## AFTERLIGHT test zone: greybox movement + interaction + audio course.
## Builds all geometry in code so the project stays text-only and robust.

const PlayerScene := preload("res://scripts/player/player.gd")
const HudScene := preload("res://scripts/ui/hud.gd")
const PauseMenuScript := preload("res://scripts/ui/pause_menu.gd")
const PropLib := preload("res://scripts/world/prop_lib.gd")
const WeatherScript := preload("res://scripts/world/weather.gd")
const CarScript := preload("res://scripts/vehicles/car.gd")
const CastleBuilder := preload("res://scripts/world/castle_builder.gd")
const CitizenScript := preload("res://scripts/ai/citizen.gd")
const WantedScript := preload("res://scripts/core/wanted.gd")
const TrafficScript := preload("res://scripts/vehicles/traffic_car.gd")
const DowntownBuilder := preload("res://scripts/world/downtown_builder.gd")
const SlidingDoorScript := preload("res://scripts/world/sliding_door.gd")
const ToggleLampScript := preload("res://scripts/world/toggle_lamp.gd")
const LootCrateScript := preload("res://scripts/world/loot_crate.gd")
const GlassPaneScript := preload("res://scripts/world/glass_pane.gd")
const LadderZoneScript := preload("res://scripts/world/ladder_zone.gd")
const InteriorZoneScript := preload("res://scripts/world/interior_zone.gd")
const TargetDummyScript := preload("res://scripts/combat/target_dummy.gd")
const GeneratorPropScript := preload("res://scripts/world/generator_prop.gd")
const EnemySpawnerScript := preload("res://scripts/ai/enemy_spawner.gd")
const BreakableScript := preload("res://scripts/world/breakable.gd")
const SaveManagerScript := preload("res://scripts/core/save_manager.gd")
const QuestManagerScript := preload("res://scripts/quests/quest_manager.gd")
const NpcScript := preload("res://scripts/npc/npc.gd")
const FactionManagerScript := preload("res://scripts/core/faction_manager.gd")
const WorldStreamerScript := preload("res://scripts/world/world_streamer.gd")
const CityBuilderScript := preload("res://scripts/world/city_builder.gd")
const GraphicsManagerScript := preload("res://scripts/core/graphics_manager.gd")
const SelfTestScript := preload("res://scripts/core/self_test.gd")
const TimeManagerScript := preload("res://scripts/core/time_manager.gd")
const WeatherManagerScript := preload("res://scripts/core/weather_manager.gd")

const SHOW_SIGNS := false

var player: Player
var hud: Hud

var _grid_mat: StandardMaterial3D
var _concrete_mat: StandardMaterial3D
var _sand_mat: StandardMaterial3D
var _cobble_mat: StandardMaterial3D
var _sun: DirectionalLight3D
var _env: Environment
var _wind: AudioStreamPlayer
var _birds: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _mountains: Node3D
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
	hud.player = player
	player.notify.connect(hud.toast)
	player.inventory.changed.connect(hud.refresh_inventory)
	player.inventory.changed.connect(func() -> void: player.weapons._emit_ammo())
	player.died.connect(_on_player_died)

	_build_interactives()
	_build_district()
	_build_parkour_gym()
	_build_old_market()
	_decorate_interiors()
	_build_weather()
	_build_castle()
	_build_citizens()
	_build_traffic()
	_build_downtown()
	_spawn_npcs()

	var city := CityBuilderScript.new()
	city.nav_parent = _nav_region
	city.sand_mat = _sand_mat
	city.cobble_mat = _cobble_mat
	city.plaster_mat = _grid_mat
	add_child(city)
	city.build()
	_bake_navmesh()
	_build_horde()

	var tm := TimeManagerScript.new()
	tm.sun = _sun
	tm.env = _env
	add_child(tm)
	tm.time_changed.connect(hud.set_time)
	tm.night_changed.connect(func(night: bool) -> void:
		var tw := create_tween()
		tw.parallel().tween_property(_birds, "volume_db",
				-60.0 if night else -16.0, 4.0)
		tw.parallel().tween_property(_crickets, "volume_db",
				-14.0 if night else -60.0, 4.0))

	var weather := WeatherManagerScript.new()
	weather.time_manager = tm
	weather.player = player
	weather.wet_mats = [_sand_mat, _cobble_mat, _grid_mat]
	weather.weather_changed.connect(hud.set_weather)
	add_child(weather)

	var streamer := WorldStreamerScript.new()
	streamer.player = player
	streamer.sand_mat = _sand_mat
	streamer.plaster_mat = _grid_mat
	add_child(streamer)

	var factions := FactionManagerScript.new()
	factions.player = player
	factions.add_to_group("quest_listeners")
	factions.territory_changed.connect(hud.set_territory)
	add_child(factions)

	var quests := QuestManagerScript.new()
	quests.player = player
	quests.factions = factions
	quests.quest_changed.connect(hud.set_quest)
	hud.quests = quests
	add_child(quests)
	player.inventory.changed.connect(quests.notify_inventory_changed)

	var saver := SaveManagerScript.new()
	saver.quest_manager = quests
	saver.faction_manager = factions
	saver.player = player
	saver.hud = hud
	saver.time_manager = tm
	saver.weather_manager = weather

	var gfx := GraphicsManagerScript.new()
	gfx.sun = _sun
	gfx.env = _env
	gfx.streamer = streamer
	gfx.weather = weather
	add_child(gfx)

	_build_mountains()
	_build_terrain()








	if "--selftest" in OS.get_cmdline_user_args():
		var tester := SelfTestScript.new()
		add_child(tester)
		tester.run(self)
	add_child(saver)


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
	_add_key("weapon_cycle", KEY_Q)
	_add_key("weapon_1", KEY_1)
	_add_key("weapon_2", KEY_2)
	_add_key("weapon_3", KEY_3)
	_add_key("debug_stats", KEY_F3)
	_add_key("toggle_view", KEY_V)
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
	sky_mat.sky_top_color = Color(0.28, 0.5, 0.82)
	sky_mat.sky_horizon_color = Color(0.9, 0.86, 0.72)
	sky_mat.ground_bottom_color = Color(0.45, 0.4, 0.3)
	sky_mat.ground_horizon_color = Color(0.88, 0.82, 0.68)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.25
	env.fog_enabled = true
	env.fog_light_color = Color(0.88, 0.83, 0.7)
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.82
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 1.06
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	_env = env

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-44, 35, 0)
	sun.light_color = Color(1.0, 0.93, 0.78)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	add_child(sun)
	_sun = sun

	_grid_mat = StandardMaterial3D.new()
	_grid_mat.albedo_texture = load("res://assets/textures/plaster.png")
	_grid_mat.roughness = 0.9
	_grid_mat.uv1_triplanar = true
	_grid_mat.uv1_world_triplanar = true
	_grid_mat.uv1_scale = Vector3.ONE * 0.5

	# Sun-bleached plaster: the default wall/structure material
	_concrete_mat = StandardMaterial3D.new()
	_concrete_mat.albedo_texture = load("res://assets/textures/plaster.png")
	_concrete_mat.roughness = 0.97
	_concrete_mat.uv1_triplanar = true
	_concrete_mat.uv1_world_triplanar = true
	_concrete_mat.uv1_scale = Vector3.ONE * 0.35

	# Sandy ground
	_sand_mat = StandardMaterial3D.new()
	_sand_mat.albedo_texture = load("res://assets/textures/sand.png")
	_sand_mat.roughness = 1.0
	_sand_mat.uv1_triplanar = true
	_sand_mat.uv1_world_triplanar = true
	_sand_mat.uv1_scale = Vector3.ONE * 0.4

	# Cobblestone streets
	_cobble_mat = StandardMaterial3D.new()
	_cobble_mat.albedo_texture = load("res://assets/textures/cobble.png")
	_cobble_mat.roughness = 0.92
	_cobble_mat.uv1_triplanar = true
	_cobble_mat.uv1_world_triplanar = true
	_cobble_mat.uv1_scale = Vector3.ONE * 0.5


func _build_course() -> void:
	# Ground
	_box(Vector3(90, 1, 90), Vector3(0, -0.5, 0), _sand_mat)
	# Cobblestone streets criss-crossing the sand
	_box(Vector3(5.0, 1.04, 90), Vector3(-2, -0.5, 0), _cobble_mat)
	_box(Vector3(90, 1.04, 5.0), Vector3(0, -0.5, 10), _cobble_mat)
	_box(Vector3(5.0, 1.04, 44), Vector3(31, -0.5, 23), _cobble_mat)
	_box(Vector3(34, 1.04, 4.4), Vector3(-28, -0.5, -14), _cobble_mat)

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

	# The old quarantine wall - breached with gates aligned to the roads
	# North: gate on the main road (x -2) to MERIDIAN HEIGHTS
	_box(Vector3(39, 4, 1), Vector3(-25.5, 2, -45), _concrete_mat)
	_box(Vector3(43, 4, 1), Vector3(23.5, 2, -45), _concrete_mat)
	_gate(Vector3(-2, 0, -45), false)
	_sign("MERIDIAN HEIGHTS", Vector3(-2, 5.8, -44.4))
	# South: gates on the main road (x -2) and the east canal road (x 31)
	_box(Vector3(39, 4, 1), Vector3(-25.5, 2, 45), _concrete_mat)
	_box(Vector3(25, 4, 1), Vector3(14.5, 2, 45), _concrete_mat)
	_box(Vector3(10, 4, 1), Vector3(40, 2, 45), _concrete_mat)
	_gate(Vector3(-2, 0, 45), false)
	_gate(Vector3(31, 0, 45), false)
	_sign("THE CANAL", Vector3(-2, 5.8, 44.4))
	# East: gates on the crosstown road (z 10) and toward the pond (z -18)
	_box(Vector3(1, 4, 23), Vector3(45, 2, -33.5), _concrete_mat)
	_box(Vector3(1, 4, 20), Vector3(45, 2, -4), _concrete_mat)
	_box(Vector3(1, 4, 31), Vector3(45, 2, 29.5), _concrete_mat)
	_gate(Vector3(45, 0, 10), true)
	_gate(Vector3(45, 0, -18), true)
	# West: gates on the crosstown road (z 10) and to the ASHLINE camp (z 34)
	_box(Vector3(1, 4, 51), Vector3(-45, 2, -19.5), _concrete_mat)
	_box(Vector3(1, 4, 16), Vector3(-45, 2, 22), _concrete_mat)
	_box(Vector3(1, 4, 7), Vector3(-45, 2, 41.5), _concrete_mat)
	_gate(Vector3(-45, 0, 10), true)
	_gate(Vector3(-45, 0, 34), true)


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
		# Warm-shift every tint slightly so the whole town reads sun-bleached
		use_mat.albedo_color = tint.lerp(Color(0.92, 0.84, 0.68), 0.22)
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


func _build_terrain() -> void:
	## Rolling desert dunes around the town, powered by the Terrain3D plugin
	## (baked height data in res://data/terrain). The terrain sits 8 m below
	## the town slab inside the walls, meets it at the rim, and rises into
	## dunes beyond ~75 m so the outskirts are no longer a flat pancake.
	if not ClassDB.can_instantiate("Terrain3D"):
		push_warning("Terrain3D unavailable - outskirts stay flat")
		return
	var terrain: Node3D = ClassDB.instantiate("Terrain3D")
	terrain.name = "Terrain"
	terrain.set("assets", load("res://data/terrain/assets.tres"))
	terrain.set("data_directory", "res://data/terrain")
	add_child(terrain)
	terrain.set("camera", player.camera)
	var tmat: Resource = terrain.get("material")
	if tmat:
		tmat.set("auto_shader", true)
		tmat.set("world_background", 1)  # flat fill beyond the baked regions
	var streamer: Node = get_tree().get_first_node_in_group("streamer")
	if streamer:
		streamer.terrain_data = terrain.get("data")


func _build_mountains() -> void:
	## A ring of hazy mountains on the horizon. Purely visual - it follows
	## the player, so the range never gets closer no matter how far you walk.
	_mountains = Node3D.new()
	add_child(_mountains)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.5, 0.6)
	mat.roughness = 1.0
	for i in 14:
		var ang := TAU * i / 14.0 + rng.randf_range(-0.14, 0.14)
		var dist := rng.randf_range(620.0, 820.0)
		var m := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = rng.randf_range(4.0, 26.0)
		cone.bottom_radius = rng.randf_range(130.0, 230.0)
		cone.height = rng.randf_range(80.0, 170.0)
		cone.radial_segments = 7
		cone.material = mat
		m.mesh = cone
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3(cos(ang) * dist, cone.height * 0.5 - 12.0,
				sin(ang) * dist)
		m.rotation.y = rng.randf_range(0.0, TAU)
		_mountains.add_child(m)


func _process(_delta: float) -> void:
	# Keep the horizon mountains centered on the player (never reachable)
	if _mountains and player:
		_mountains.position = Vector3(player.global_position.x, 0.0,
				player.global_position.z)


func _gate(pos: Vector3, ew: bool) -> void:
	## A breach in the quarantine wall: two posts + an overhead beam
	var side := Vector3(0, 0, 1) if ew else Vector3(1, 0, 0)
	var post := Vector3(0.9, 5.4, 1.6) if ew else Vector3(1.6, 5.4, 0.9)
	_box(post, pos + side * 4.5 + Vector3(0, 2.7, 0), _concrete_mat)
	_box(post, pos - side * 4.5 + Vector3(0, 2.7, 0), _concrete_mat)
	var lintel := Vector3(0.9, 0.8, 10.0) if ew else Vector3(10.0, 0.8, 0.9)
	_box(lintel, pos + Vector3(0, 5.0, 0), _concrete_mat)


func _sign(text: String, pos: Vector3) -> void:
	## Floating helper text, disabled for a clean world (flip to re-enable).
	if not SHOW_SIGNS:
		return
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

	# Night crickets (cross-faded with birds by the day/night cycle)
	_crickets = AudioStreamPlayer.new()
	var cricket_stream: AudioStreamWAV = load("res://assets/audio/crickets_loop.wav")
	cricket_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	cricket_stream.loop_end = cricket_stream.data.size() / 2
	_crickets.stream = cricket_stream
	_crickets.volume_db = -60.0
	_crickets.autoplay = true
	add_child(_crickets)
	_crickets.play()

# ------------------------------------------------------------------ district

func _build_district() -> void:
	## Phase 2 additions: 3-floor apartment block with interior stairs,
	## balcony fire escape and rooftop; street cars; echo tunnel; shooting
	## range with target dummies; generator that powers a floodlight.
	var bx := -28.0
	var bz := -28.0
	_sign("APARTMENT BLOCK: 3 FLOORS + ROOF", Vector3(bx + 9, 4.2, bz + 4))

	# --- Walls (west + north solid) ---
	_box(Vector3(0.5, 9.4, 12), Vector3(bx - 5.75, 4.7, bz), _grid_mat, Color(0.83, 0.56, 0.43))
	_box(Vector3(12, 9.4, 0.5), Vector3(bx, 4.7, bz + 5.75), _grid_mat, Color(0.83, 0.56, 0.43))
	# East wall: full pieces + window column + door column
	_box(Vector3(0.5, 9.4, 2.6), Vector3(bx + 5.75, 4.7, bz - 4.7), _grid_mat, Color(0.83, 0.56, 0.43))
	_box(Vector3(0.5, 3.7, 1.4), Vector3(bx + 5.75, 1.85, bz - 2.7), _grid_mat, Color(0.83, 0.56, 0.43))
	_box(Vector3(0.5, 4.3, 1.4), Vector3(bx + 5.75, 7.25, bz - 2.7), _grid_mat, Color(0.83, 0.56, 0.43))
	_box(Vector3(0.5, 9.4, 2.5), Vector3(bx + 5.75, 4.7, bz - 0.75), _grid_mat, Color(0.83, 0.56, 0.43))
	_box(Vector3(0.5, 7.0, 1.8), Vector3(bx + 5.75, 5.9, bz + 1.4), _grid_mat, Color(0.83, 0.56, 0.43))
	_box(Vector3(0.5, 9.4, 3.7), Vector3(bx + 5.75, 4.7, bz + 4.15), _grid_mat, Color(0.83, 0.56, 0.43))
	# South wall: two full pieces + balcony window column
	_box(Vector3(5.3, 9.4, 0.5), Vector3(bx - 3.35, 4.7, bz - 5.75), _grid_mat, Color(0.83, 0.56, 0.43))
	_box(Vector3(5.3, 9.4, 0.5), Vector3(bx + 3.35, 4.7, bz - 5.75), _grid_mat, Color(0.83, 0.56, 0.43))
	_box(Vector3(1.4, 3.15, 0.5), Vector3(bx, 1.575, bz - 5.75), _grid_mat, Color(0.83, 0.56, 0.43))
	_box(Vector3(1.4, 4.15, 0.5), Vector3(bx, 7.325, bz - 5.75), _grid_mat, Color(0.83, 0.56, 0.43))

	# --- Floors with stair openings (wood) ---
	_box(Vector3(11.5, 0.3, 9.0), Vector3(bx, 3.0, bz - 1.25), _grid_mat, Color(0.7, 0.55, 0.4), "wood")
	# Shortened strip: leaves full head clearance over the ground-floor stairs
	_box(Vector3(3.1, 0.3, 2.5), Vector3(bx - 4.2, 3.0, bz + 4.5), _grid_mat, Color(0.7, 0.55, 0.4), "wood")
	_box(Vector3(11.5, 0.3, 9.0), Vector3(bx, 6.0, bz + 1.25), _grid_mat, Color(0.7, 0.55, 0.4), "wood")
	# Shortened strip: leaves full head clearance over the floor-2 stairs
	_box(Vector3(3.45, 0.3, 2.5), Vector3(bx + 4.03, 6.0, bz - 4.5), _grid_mat, Color(0.7, 0.55, 0.4), "wood")
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
	_box(Vector3(4.5, 8.7, 4.5), Vector3(bx - 9.5, 4.35, bz), _grid_mat, Color(0.45, 0.6, 0.75))

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
	# Phase 18: one car still runs - hop in with E
	var runner: CharacterBody3D = CarScript.new()
	runner.position = Vector3(-7.5, 0.4, -11.0)
	runner.rotation.y = 0.35
	add_child(runner)
	_sign("THIS ONE STILL RUNS - PRESS E", Vector3(-7.5, 2.6, -11.0))
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
	# Phase 14: special infected
	_spawner("screamer", Vector3(-26, 0.1, -24))    # The Blocks
	_spawner("brute", Vector3(-23, 0.1, 30))        # The Yards
	_spawner("climber", Vector3(20, 0.1, -27))      # phase-1 building
	_spawner("hunter", Vector3(8, 0.1, 32))         # near the tunnel
	# Old Market is contested too
	_spawner("shambler", Vector3(30, 0.1, 8))
	_spawner("stalker", Vector3(36, 0.1, 26))


func _spawner(kind: String, pos: Vector3) -> void:
	var s := EnemySpawnerScript.new()
	s.kind = kind
	s.position = pos
	add_child(s)


func _on_player_died() -> void:
	hud.show_death()
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		get_tree().reload_current_scene())


# ---------------------------------------------------------------- phase 4

func _build_parkour_gym() -> void:
	## Practice area for Phase 4 movement: wall-jump shaft, ledge traverse,
	## gap jump with ledge catch, and a roll-landing tower.
	var gx := -24.0
	var gz := 30.0
	var wall_tint := Color(0.62, 0.66, 0.74)
	_sign("PARKOUR GYM", Vector3(gx, 4.2, gz - 10))

	# --- Wall-jump shaft: bounce between the two walls to reach the top ---
	_sign("WALL SHAFT: JUMP BETWEEN THE WALLS", Vector3(gx - 5, 2.0, gz - 2.4))
	_box(Vector3(0.5, 8.0, 4.0), Vector3(gx - 6.0, 4.0, gz + 2), _grid_mat, wall_tint)
	_box(Vector3(0.5, 8.0, 4.0), Vector3(gx - 4.1, 4.0, gz + 2), _grid_mat, wall_tint)
	# Exit platform bridging the far end of the shaft
	_box(Vector3(2.6, 0.4, 1.8), Vector3(gx - 5.05, 7.8, gz + 4.8), _concrete_mat)

	# --- Ledge traverse: jump, grab the top edge, shimmy along, climb up ---
	_sign("JUMP + GRAB THE TOP EDGE, SHIMMY WITH A / D", Vector3(gx + 3, 2.2, gz + 5.4))
	_box(Vector3(8.0, 3.2, 0.9), Vector3(gx + 3, 1.6, gz + 8), _grid_mat, wall_tint)

	# --- Gap jump with a ledge catch on the far side ---
	_sign("SPRINT, JUMP THE GAP, CATCH THE LEDGE", Vector3(gx + 8, 2.8, gz - 5.6))
	_box(Vector3(3, 1.2, 3), Vector3(gx + 8, 0.6, gz - 2), _grid_mat, wall_tint)
	_box(Vector3(3, 4.4, 3), Vector3(gx + 8, 2.2, gz + 3.9), _grid_mat, wall_tint)

	# --- Roll tower: climb the ladder, jump off, hold crouch to roll ---
	_sign("JUMP OFF - HOLD CTRL TO ROLL THE LANDING", Vector3(gx - 12, 2.2, gz + 4.4))
	_box(Vector3(2.5, 6.0, 2.5), Vector3(gx - 12, 3.0, gz + 8), _concrete_mat)
	_ladder(Vector3(gx - 12 + 1.45, 0, gz + 8), 6.4)


# ------------------------------------------------------------------
# PHASE 5 - OLD MARKET (north-east district)
# ------------------------------------------------------------------

func _build_weather() -> void:
	## Phase 17: drifting clouds + rain showers.
	var weather: Node3D = WeatherScript.new()
	weather.name = "Weather"
	weather.player = player
	weather.environment = _env
	add_child(weather)




func _build_downtown() -> void:
	## Phase 22: NEON DISTRICT east of town, plus its own crowd.
	var dt: Node3D = DowntownBuilder.new()
	dt.name = "Downtown"
	dt.position = Vector3(170, 0, 10)
	add_child(dt)
	var rng := RandomNumberGenerator.new()
	rng.seed = 22
	for i in 8:
		var civ: CharacterBody3D = CitizenScript.new()
		civ.anchor = Vector3(170, 1.2, 10)
		civ.anchor_radius = 55.0
		civ.position = Vector3(170 + rng.randf_range(-50, 50), 2.2,
				10 + rng.randf_range(-50, 50))
		add_child(civ)
	for i in 2:
		var cop: CharacterBody3D = CitizenScript.new()
		cop.is_cop = true
		cop.anchor = Vector3(170, 1.2, 10)
		cop.anchor_radius = 55.0
		cop.position = Vector3(170 + rng.randf_range(-40, 40), 2.2,
				10 + rng.randf_range(-40, 40))
		add_child(cop)
	# Bar staff and regulars (tight anchors keep them inside)
	var keeper: CharacterBody3D = CitizenScript.new()
	keeper.anchor = Vector3(140.5, 1.4, 30.5)
	keeper.anchor_radius = 1.5
	keeper.position = keeper.anchor + Vector3(0, 0.3, 0)
	add_child(keeper)
	var pat1: CharacterBody3D = CitizenScript.new()
	pat1.anchor = Vector3(139, 1.4, 26.5)
	pat1.anchor_radius = 1.2
	pat1.position = pat1.anchor + Vector3(0, 0.3, 0)
	add_child(pat1)
	var pat2: CharacterBody3D = CitizenScript.new()
	pat2.anchor = Vector3(144.5, 1.4, 24.5)
	pat2.anchor_radius = 1.2
	pat2.position = pat2.anchor + Vector3(0, 0.3, 0)
	add_child(pat2)


func _build_traffic() -> void:
	## Phase 21: cars cruising loops on the two main streets.
	var loop_a := [Vector3(-3.2, 0.1, -68), Vector3(-3.2, 0.1, 60),
			Vector3(-0.8, 0.1, 60), Vector3(-0.8, 0.1, -68)]
	var loop_b := [Vector3(-68, 0.1, 8.8), Vector3(66, 0.1, 8.8),
			Vector3(66, 0.1, 11.2), Vector3(-68, 0.1, 11.2)]
	var paints := [Color(0.7, 0.25, 0.2), Color(0.25, 0.4, 0.7),
			Color(0.8, 0.75, 0.6), Color(0.3, 0.55, 0.35),
			Color(0.55, 0.55, 0.6), Color(0.75, 0.55, 0.2),
			Color(0.4, 0.35, 0.5)]
	for i in 7:
		var car: CharacterBody3D = TrafficScript.new()
		car.paint = paints[i]
		var loop: Array = loop_a if i < 4 else loop_b
		car.waypoints = loop
		var leg := i % 2
		car.wp = leg * 2
		var a: Vector3 = loop[leg * 2]
		var b: Vector3 = loop[leg * 2 + 1]
		car.position = a.lerp(b, fposmod(0.15 + 0.18 * i, 0.9))
		car.position.y = 0.2
		var head := b - a
		car.rotation.y = atan2(-head.x, -head.z)
		add_child(car)


func _build_citizens() -> void:
	## Phase 20: townsfolk going about their day, plus a police force.
	var wm: Node = WantedScript.new()
	wm.name = "WantedManager"
	wm.hud = hud
	add_child(wm)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20
	for i in 14:
		var civ: CharacterBody3D = CitizenScript.new()
		civ.position = Vector3(rng.randf_range(-60, 60), 0.2,
				rng.randf_range(-60, 60))
		add_child(civ)
	for i in 5:
		var cop: CharacterBody3D = CitizenScript.new()
		cop.is_cop = true
		cop.position = Vector3(rng.randf_range(-55, 55), 0.2,
				rng.randf_range(-55, 55))
		add_child(cop)


func _build_castle() -> void:
	## Phase 19: the medieval castle in the dunes north of town.
	var castle: Node3D = CastleBuilder.new()
	castle.name = "Castle"
	castle.position = Vector3(0, 0, -170)
	add_child(castle)


func _decorate_interiors() -> void:
	## Phase 16: furniture and clutter from the Medieval Village pack.
	var bx := -28.0
	var bz := -28.0
	# --- Apartment ground floor: living room ---
	PropLib.place(self, "Table", Vector3(bx - 2.5, 0, bz - 2.5), 0.0, 0.75)
	PropLib.place(self, "Chair", Vector3(bx - 4.3, 0, bz - 2.5), PI / 2, 0.75)
	PropLib.place(self, "Seat", Vector3(bx - 0.7, 0, bz - 2.5), -PI / 2, 0.75)
	PropLib.place(self, "Chope_A", Vector3(bx - 2.9, 1.05, bz - 2.9), 0.6, 0.5, false)
	PropLib.place(self, "Cup", Vector3(bx - 2.1, 1.05, bz - 2.2), 0.0, 1.0, false)
	PropLib.place(self, "Barril", Vector3(bx + 4.6, 0, bz - 4.5))
	PropLib.place(self, "Barril", Vector3(bx + 4.6, 0, bz - 3.2), 0.9)
	PropLib.place(self, "Wood_Trunk", Vector3(bx - 4.6, 0, bz - 4.6), 0.5, 0.8)
	# --- Apartment floor 2 ---
	PropLib.place(self, "Barril", Vector3(bx - 4.7, 3.15, bz + 2.2))
	PropLib.place(self, "Barril", Vector3(bx - 3.5, 3.15, bz + 2.6), 1.7)
	PropLib.place(self, "Table", Vector3(bx + 2.0, 3.15, bz - 0.5), 0.0, 0.7)
	PropLib.place(self, "Seat", Vector3(bx + 2.0, 3.15, bz + 1.5), PI, 0.7)
	PropLib.place(self, "Chope_B", Vector3(bx + 2.2, 4.13, bz - 0.7), 2.1, 0.5, false)
	PropLib.place(self, "Panel", Vector3(bx - 5.4, 4.3, bz - 1.0), PI / 2, 1.0, false)
	# --- Apartment floor 3: trophy wall + squatter corner ---
	PropLib.place(self, "Sword", Vector3(bx - 1.5, 7.6, bz + 5.35), 0.0, 1.0, false)
	PropLib.place(self, "Battle_Axe", Vector3(bx + 0.5, 7.7, bz + 5.35), 0.0, 0.9, false)
	PropLib.place(self, "Wood_Axe", Vector3(bx + 2.3, 7.5, bz + 5.35), 0.0, 1.0, false)
	PropLib.place(self, "Shield", Vector3(bx - 3.5, 7.6, bz + 5.3), 0.0, 1.0, false, PI / 2)
	PropLib.place(self, "Wood_Plank_A", Vector3(bx - 2.0, 6.16, bz + 2.0), 0.4, 0.6, false)
	PropLib.place(self, "Barril", Vector3(bx + 4.5, 6.15, bz + 4.6))
	PropLib.place(self, "Chair", Vector3(bx + 3.8, 6.15, bz + 2.5), -2.0, 0.75)
	# --- Shop: counter clutter, corner table, hanging lamp ---
	PropLib.place(self, "Chope_A", Vector3(35.0, 0.95, 15.6), 0.3, 0.55, false)
	PropLib.place(self, "Chope_B", Vector3(36.2, 0.95, 15.7), 1.2, 0.55, false)
	PropLib.place(self, "Cup", Vector3(35.6, 0.95, 15.4), 0.0, 1.0, false)
	PropLib.place(self, "Barril", Vector3(38.7, 0, 16.2))
	PropLib.place(self, "Barril", Vector3(37.5, 0, 16.4), 2.3, 0.9)
	PropLib.place(self, "Table", Vector3(34.2, 0, 12.6), 0.2, 0.6)
	PropLib.place(self, "Seat", Vector3(32.9, 0, 12.6), PI / 2, 0.7)
	PropLib.place(self, "Cup", Vector3(34.2, 0.84, 12.6), 0.0, 1.0, false)
	PropLib.place(self, "Lamp", Vector3(36, 3.2, 14), 0.0, 1.0, false)
	PropLib.place(self, "Panel", Vector3(38.0, 2.2, 16.8), PI, 1.0, false)
	# --- Undercroft storage: supplies in the dark ---
	PropLib.place(self, "Barril", Vector3(43.0, 0, 16.0), 0.7)
	PropLib.place(self, "Wood_Trunk", Vector3(42.8, 0, 11.9), -0.4, 0.8)
	PropLib.place(self, "Wood_Plank_B", Vector3(42.0, 0.06, 13.8), 0.5, 0.6, false)
	# --- Market square: standing sign ---
	PropLib.place(self, "Signal", Vector3(26.0, 0, 15.8), 0.9)




func _build_old_market() -> void:
	## Market square with stalls, an enterable shop with a hidden storage
	## room behind a weak wall, and a two-storey house. Wooden doors and
	## the weak wall are breakable - shoot them apart.
	var wood := Color(0.5, 0.36, 0.22)
	var plaster := Color(0.82, 0.76, 0.66)
	var plaster2 := Color(0.74, 0.7, 0.64)

	# ---------- Market square: 3 stalls + crates + rubble ----------
	_stall(Vector3(23, 0, 13.5), Color(0.75, 0.25, 0.2))
	_stall(Vector3(23, 0, 18.5), Color(0.2, 0.55, 0.3))
	_stall(Vector3(27, 0, 22.5), Color(0.25, 0.35, 0.7))
	_loot_crate(Vector3(23.9, 0, 16.2))
	_loot_crate(Vector3(38.5, 0, 15.8))
	_box(Vector3(1.4, 0.7, 1.1), Vector3(29, 0.35, 17), _concrete_mat, Color(0.6, 0.6, 0.62))
	_box(Vector3(0.9, 0.45, 0.8), Vector3(29.6, 0.22, 18.1), _concrete_mat, Color(0.55, 0.55, 0.58))
	# Breakable barricade across the alley between market and shop
	_breakable(Vector3(2.2, 1.15, 0.22), Vector3(30.6, 0.58, 14.0), wood, 50)

	# ---------- SHOP (x 32..40, z 11..17), flat grabbable roof ----------
	# North wall (solid)
	_box(Vector3(8, 3.2, 0.3), Vector3(36, 1.6, 17), _concrete_mat, plaster)
	# South wall with window
	_box(Vector3(3.1, 3.2, 0.3), Vector3(33.55, 1.6, 11), _concrete_mat, plaster)
	_box(Vector3(3.1, 3.2, 0.3), Vector3(38.45, 1.6, 11), _concrete_mat, plaster)
	_box(Vector3(1.8, 0.9, 0.3), Vector3(36, 0.45, 11), _concrete_mat, plaster)
	_box(Vector3(1.8, 0.9, 0.3), Vector3(36, 2.75, 11), _concrete_mat, plaster)
	_glass_pane(Vector3(1.8, 1.4, 0.12), Vector3(36, 1.6, 11))
	# West wall with door opening (faces the market)
	_box(Vector3(0.3, 3.2, 2.4), Vector3(32, 1.6, 12.2), _concrete_mat, plaster)
	_box(Vector3(0.3, 3.2, 2.4), Vector3(32, 1.6, 15.8), _concrete_mat, plaster)
	_box(Vector3(0.3, 0.9, 1.2), Vector3(32, 2.75, 14), _concrete_mat, plaster)
	_breakable(Vector3(0.14, 2.3, 1.14), Vector3(32, 1.15, 14), wood, 70)
	# East wall, shared with the storage room: cracked WEAK WALL in the middle
	_box(Vector3(0.3, 3.2, 1.9), Vector3(40, 1.6, 11.95), _concrete_mat, plaster)
	_box(Vector3(0.3, 3.2, 1.9), Vector3(40, 1.6, 16.05), _concrete_mat, plaster)
	_box(Vector3(0.3, 0.8, 2.2), Vector3(40, 2.8, 14), _concrete_mat, plaster)
	_breakable(Vector3(0.28, 2.4, 2.2), Vector3(40, 1.2, 14), Color(0.45, 0.42, 0.36), 140)
	# Shop counter + shelf
	_box(Vector3(3.2, 0.95, 0.7), Vector3(35.5, 0.48, 15.6), _grid_mat, wood, "wood")
	_box(Vector3(0.5, 1.9, 3.4), Vector3(39.5, 0.95, 12.9), _grid_mat, wood, "wood")

	# ---------- UNDERCROFT storage (x 40..44, z 11..17), pitch dark ----------
	_box(Vector3(0.3, 3.2, 6.3), Vector3(44, 1.6, 14), _concrete_mat, plaster2)
	_box(Vector3(4, 3.2, 0.3), Vector3(42, 1.6, 17), _concrete_mat, plaster2)
	_box(Vector3(4, 3.2, 0.3), Vector3(42, 1.6, 11), _concrete_mat, plaster2)
	# One roof slab across shop + storage; top at 3.6 m = ledge-grabbable
	_box(Vector3(12.6, 0.4, 6.6), Vector3(38, 3.4, 14), _concrete_mat, Color(0.5, 0.5, 0.54))
	_loot_crate(Vector3(42.2, 0, 15.4))
	_loot_crate(Vector3(41.3, 0, 12.6))
	var ucl := OmniLight3D.new()
	ucl.light_color = Color(1.0, 0.25, 0.18)
	ucl.light_energy = 0.55
	ucl.omni_range = 5.0
	ucl.position = Vector3(42, 2.6, 14)
	add_child(ucl)

	# Shop lamp + switch by the door
	var shop_lamp := OmniLight3D.new()
	shop_lamp.light_color = Color(1.0, 0.85, 0.6)
	shop_lamp.light_energy = 2.2
	shop_lamp.omni_range = 7.0
	shop_lamp.position = Vector3(36, 2.7, 14)
	add_child(shop_lamp)
	_lamp_switch(shop_lamp, Vector3(32.6, 1.4, 15.7))

	# ---------- HOUSE (x 23..29, z 29..35), two storeys + roof ladder ----------
	_box(Vector3(0.3, 5.6, 6), Vector3(23, 2.8, 32), _concrete_mat, plaster2)
	_box(Vector3(0.3, 5.6, 6), Vector3(29, 2.8, 32), _concrete_mat, plaster2)
	# North wall with upstairs window
	_box(Vector3(6, 3.4, 0.3), Vector3(26, 1.7, 35), _concrete_mat, plaster2)
	_box(Vector3(1.6, 2.2, 0.3), Vector3(23.8, 4.5, 35), _concrete_mat, plaster2)
	_box(Vector3(1.6, 2.2, 0.3), Vector3(28.2, 4.5, 35), _concrete_mat, plaster2)
	_box(Vector3(2.8, 0.5, 0.3), Vector3(26, 3.65, 35), _concrete_mat, plaster2)
	_box(Vector3(2.8, 0.3, 0.3), Vector3(26, 5.45, 35), _concrete_mat, plaster2)
	_glass_pane(Vector3(2.8, 1.4, 0.12), Vector3(26, 4.6, 35))
	# South wall with breakable front door
	_box(Vector3(2.4, 5.6, 0.3), Vector3(24.2, 2.8, 29), _concrete_mat, plaster2)
	_box(Vector3(2.4, 5.6, 0.3), Vector3(27.8, 2.8, 29), _concrete_mat, plaster2)
	_box(Vector3(1.2, 3.3, 0.3), Vector3(26, 3.95, 29), _concrete_mat, plaster2)
	_breakable(Vector3(1.14, 2.3, 0.14), Vector3(26, 1.15, 29), wood, 70)
	# Upstairs floor (stair opening along the east side)
	_box(Vector3(4.5, 0.3, 6), Vector3(25.25, 2.55, 32), _concrete_mat, Color(0.6, 0.58, 0.55))
	# Interior stairs along the east wall (climb south-to-... up northwards)
	for i in 9:
		_box(Vector3(1.2, 0.3, 0.6), Vector3(28.3, 0.15 + 0.3 * i, 34.4 - 0.6 * i),
				_concrete_mat, Color(0.62, 0.6, 0.57))
	# Roof (top at 6.0 m) + outside ladder to it
	_box(Vector3(6.6, 0.4, 6.6), Vector3(26, 5.8, 32), _concrete_mat, Color(0.5, 0.5, 0.54))
	_ladder(Vector3(22.5, 0, 32), 6.6)
	_loot_crate(Vector3(24.2, 2.7, 34))
	var house_lamp := OmniLight3D.new()
	house_lamp.light_color = Color(1.0, 0.85, 0.6)
	house_lamp.light_energy = 2.0
	house_lamp.omni_range = 6.5
	house_lamp.position = Vector3(26, 2.3, 32)
	add_child(house_lamp)
	_lamp_switch(house_lamp, Vector3(26.9, 1.4, 29.6))

	# ---------- Interior audio zones ----------
	_interior_zone(Vector3(8.4, 6.2, 6.4), Vector3(36, 3.2, 14), "Interior")
	_interior_zone(Vector3(4.2, 6.2, 6.4), Vector3(42, 3.2, 14), "Tunnel")
	_interior_zone(Vector3(6.4, 6.4, 6.4), Vector3(26, 3.2, 32), "Interior")


func _stall(pos: Vector3, canopy_tint: Color) -> void:
	## Wooden market stall: 4 posts, canopy, counter.
	var wood := Color(0.5, 0.36, 0.22)
	for dx in [-1.05, 1.05]:
		for dz in [-0.75, 0.75]:
			_box(Vector3(0.12, 2.2, 0.12), pos + Vector3(dx, 1.1, dz), _grid_mat, wood, "wood")
	_box(Vector3(2.5, 0.12, 1.9), pos + Vector3(0, 2.26, 0), _grid_mat, canopy_tint, "wood")
	_box(Vector3(2.0, 0.9, 0.85), pos + Vector3(0, 0.45, 0), _grid_mat, wood.lightened(0.12), "wood")


func _breakable(size: Vector3, pos: Vector3, tint: Color, hp: int) -> void:
	var b := BreakableScript.new()
	b.setup(size, tint, hp)
	b.position = pos
	add_child(b)


func _loot_crate(pos: Vector3) -> void:
	var crate := LootCrateScript.new()
	var crate_mesh := MeshInstance3D.new()
	var crate_box := BoxMesh.new()
	crate_box.size = Vector3(0.9, 0.8, 0.9)
	crate_mesh.mesh = crate_box
	crate_mesh.position.y = 0.4
	var crate_mat := StandardMaterial3D.new()
	crate_mat.albedo_color = Color(0.55, 0.4, 0.22)
	crate_mat.roughness = 0.9
	crate_mesh.material_override = crate_mat
	var crate_col := CollisionShape3D.new()
	var crate_shape := BoxShape3D.new()
	crate_shape.size = Vector3(0.9, 0.8, 0.9)
	crate_col.shape = crate_shape
	crate_col.position.y = 0.4
	crate.add_child(crate_mesh)
	crate.add_child(crate_col)
	crate.position = pos
	crate.set_meta("surface", "wood")
	add_child(crate)


func _glass_pane(size: Vector3, pos: Vector3) -> void:
	var glass := GlassPaneScript.new()
	var glass_mesh := MeshInstance3D.new()
	var glass_box := BoxMesh.new()
	glass_box.size = size
	glass_mesh.mesh = glass_box
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.7, 0.85, 1.0, 0.3)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.1
	glass_mesh.material_override = glass_mat
	var glass_col := CollisionShape3D.new()
	var glass_shape := BoxShape3D.new()
	glass_shape.size = size
	glass_col.shape = glass_shape
	glass.add_child(glass_mesh)
	glass.add_child(glass_col)
	glass.position = pos
	add_child(glass)


func _lamp_switch(lamp: OmniLight3D, pos: Vector3) -> void:
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
	switch.position = pos
	add_child(switch)


func _interior_zone(size: Vector3, pos: Vector3, bus: String) -> void:
	var zone := InteriorZoneScript.new()
	zone.bus_name = bus
	zone.ambience = [_wind, _birds]
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	zone.add_child(col)
	zone.position = pos
	add_child(zone)


# ---------------------------------------------------------------- NPCs

func _spawn_npcs() -> void:
	_npc("MARA", Color(0.55, 0.3, 0.25), Vector3(35, 0, 15), 2.5,
			Vector3(37, 0, 15.5), [
		"Welcome to what's left of the market. Take what you need - crates re-stock themselves somehow.",
		"Cloth and scrap keep this place alive. Check the crafting list when you press TAB.",
		"Two cloth makes a bandage. Cheaper than dying.",
	])
	_npc("DEX", Color(0.28, 0.35, 0.45), Vector3(25, 0, 16), 5.0,
			Vector3(25.5, 0, 33), [
		"Stay off the streets after 20:00. They get faster in the dark. And they see farther.",
		"Gunfire pulls every walker in half the district. A pipe to the skull is quieter.",
		"I hold the square. You watch your own back out there.",
	])
	_npc("IVY", Color(0.35, 0.42, 0.3), Vector3(25, 0, 21), 6.0,
			Vector3(27, 0, 31), [
		"The old antenna on the blue tower still hums at night. Somebody should look at it.",
		"I strip the cars for scrap. Three pieces makes a decent pipe.",
		"Found a bat in a crate once. Best day of my year.",
	])


func _npc(nm: String, color: Color, work: Vector3, radius: float,
		home: Vector3, dialogue: Array) -> void:
	var n: CharacterBody3D = NpcScript.new()
	n.setup(nm, color, work, radius, home, dialogue)
	n.position = work + Vector3(0, 0.4, 0)
	add_child(n)
