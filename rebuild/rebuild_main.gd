extends Node3D
## Minimal clean boot scene. Legacy scenes and builders remain available.

const RebuildWorldScript := preload("res://rebuild/world/rebuild_world.gd")
const PlayerScript := preload("res://scripts/player/player.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const PauseMenuScript := preload("res://scripts/ui/pause_menu.gd")
const CarScript := preload("res://scripts/vehicles/car.gd")
const MotorcycleScript := preload("res://scripts/vehicles/motorcycle.gd")
const AmbientCitizenScript := preload("res://scripts/npc/ambient_citizen.gd")

const CITIZEN_MODELS := [
	"res://assets/characters/quaternius_modular_men/glTF/Adventurer.gltf",
	"res://assets/characters/quaternius_modular_men/glTF/Beach.gltf",
	"res://assets/characters/quaternius_modular_men/glTF/Casual_2.gltf",
	"res://assets/characters/quaternius_modular_men/glTF/Casual_Hoodie.gltf",
	"res://assets/characters/quaternius_modular_men/glTF/Farmer.gltf",
	"res://assets/characters/quaternius_modular_men/glTF/Punk.gltf",
	"res://assets/characters/quaternius_modular_men/glTF/Suit.gltf",
	"res://assets/characters/quaternius_modular_men/glTF/Worker.gltf",
]

var player: Player
var hud: Hud


func _ready() -> void:
	_setup_input()
	_setup_environment()
	_start_ambience()
	var world := RebuildWorldScript.new()
	world.name = "AssetDrivenWorld"
	add_child(world)
	world.build()
	_spawn_player()
	_spawn_vehicle()
	_spawn_motorcycles()
	_spawn_citizens()
	add_child(PauseMenuScript.new())


func _spawn_player() -> void:
	player = PlayerScript.new()
	player.position = Vector3(0, 0.3, 24)
	add_child(player)
	hud = HudScript.new()
	add_child(hud)
	hud.player = player
	player.stamina.stamina_changed.connect(hud.set_stamina)
	player.stamina.exhausted_changed.connect(hud.set_exhausted)
	player.interaction_prompt.connect(hud.set_prompt)
	player.weapons.ammo_changed.connect(hud.set_ammo)
	player.weapons._emit_ammo()
	player.health_changed.connect(hud.set_health)
	hud.set_health(player.health, Player.MAX_HEALTH)
	player.notify.connect(hud.toast)
	player.inventory.changed.connect(hud.refresh_inventory)
	player.inventory.changed.connect(func() -> void: player.weapons._emit_ammo())
	hud.set_quest("CLEAN REBUILD: explore the new districts and workshop")


func _spawn_vehicle() -> void:
	var parking_spots: Array[Vector3] = [Vector3(9, 0.2, 24), Vector3(-18, 0.2, 24),
			Vector3(32, 0.2, -18), Vector3(-42, 0.2, -18),
			Vector3(64, 0.2, 72), Vector3(-76, 0.2, 72),
			Vector3(86, 0.2, -72), Vector3(-92, 0.2, -72),
			Vector3(120, 0.2, 24), Vector3(-120, 0.2, 24)]
	for i in parking_spots.size():
		var car := CarScript.new()
		car.visual_kind = i
		car.position = parking_spots[i]
		car.rotation.y = PI * 0.5 if i % 2 == 0 else -PI * 0.5
		car.name = "DrivableCar_%02d" % (i + 1)
		add_child(car)


func _spawn_motorcycles() -> void:
	# Bikes sit on roadside shoulders near the starting district and downtown.
	# They use the same E/WASD/mouse controls as cars, so no extra bindings or
	# tutorial friction are introduced.
	var parking_spots: Array[Vector3] = [Vector3(14, 0.2, 16),
			Vector3(-110, 0.2, -106), Vector3(250, 0.2, 226),
			Vector3(-370, 0.2, 346)]
	for i in parking_spots.size():
		var bike := MotorcycleScript.new()
		bike.position = parking_spots[i]
		bike.rotation.y = PI * 0.5 if i % 2 == 0 else -PI * 0.5
		bike.name = "DrivableMotorcycle_%02d" % (i + 1)
		add_child(bike)


func _spawn_citizens() -> void:
	# Fixed pedestrian-safe anchors keep citizens off the driving lanes while
	# still making every district feel occupied.
	var anchors := [
		Vector3(-12, 0.15, 18), Vector3(15, 0.15, 10),
		Vector3(-13, 0.15, -8), Vector3(13, 0.15, -18),
		Vector3(-38, 0.15, 28), Vector3(38, 0.15, 18),
		Vector3(-42, 0.15, -20), Vector3(42, 0.15, -30),
		Vector3(-68, 0.15, 12), Vector3(68, 0.15, -8),
		Vector3(-72, 0.15, -42), Vector3(72, 0.15, 42),
		Vector3(-24, 0.15, 62), Vector3(25, 0.15, 68),
		Vector3(-18, 0.15, -68), Vector3(22, 0.15, -62),
	]
	for i in anchors.size():
		var citizen := AmbientCitizenScript.new()
		citizen.position = anchors[i]
		citizen.model_path = CITIZEN_MODELS[i % CITIZEN_MODELS.size()]
		citizen.wander_radius = 5.0 + float(i % 3) * 1.5
		citizen.name = "Citizen_%02d" % (i + 1)
		add_child(citizen)


func _setup_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.18, 0.38, 0.68)
	sky_material.sky_horizon_color = Color(0.86, 0.79, 0.66)
	sky_material.ground_bottom_color = Color(0.32, 0.3, 0.26)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 1.1
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 28, 0)
	sun.light_color = Color(1.0, 0.92, 0.78)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)


func _start_ambience() -> void:
	for data in [["res://assets/audio/wind_loop.wav", -22.0],
			["res://assets/audio/birds_loop.wav", -27.0],
			["res://assets/audio/city_traffic_loop.wav", -19.0]]:
		var player_audio := AudioStreamPlayer.new()
		var stream := load(data[0]) as AudioStreamWAV
		if stream == null:
			continue
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size() / 2
		player_audio.stream = stream
		player_audio.volume_db = data[1]
		add_child(player_audio)
		player_audio.play()


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
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)


func _add_mouse(action: String, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
