extends Node
## Save/load v1: F9 saves, F10 loads. Stores player position, view,
## health, stamina and ammo as JSON in user://afterlight_save.json.
## (World state - broken objects, zombie positions - comes with save v2.)

const SAVE_PATH := "user://afterlight_save.json"

var player: Player
var hud: Hud
var time_manager: Node

var _snd_save: AudioStreamPlayer
var _snd_load: AudioStreamPlayer


func _ready() -> void:
	_add_key("quicksave", KEY_F9)
	_add_key("quickload", KEY_F10)
	_snd_save = AudioStreamPlayer.new()
	_snd_save.stream = load("res://assets/audio/save_blip.wav")
	add_child(_snd_save)
	_snd_load = AudioStreamPlayer.new()
	_snd_load.stream = load("res://assets/audio/load_blip.wav")
	add_child(_snd_load)


func _add_key(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quicksave"):
		save_game()
	elif event.is_action_pressed("quickload"):
		load_game()


func save_game() -> void:
	if player.health <= 0:
		return
	var mags: Array = []
	for w in player.weapons._weapons:
		mags.append(w["mag"])
	var data := {
		"pos": [player.global_position.x, player.global_position.y,
				player.global_position.z],
		"yaw": player.rotation.y,
		"pitch": player.head.rotation.x,
		"health": player.health,
		"stamina": player.stamina.stamina,
		"mags": mags,
		"day": time_manager.day,
		"hour": time_manager.hour,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	_snd_save.play()
	hud.toast("GAME SAVED")


func load_game() -> void:
	if player.health <= 0:
		return
	if not FileAccess.file_exists(SAVE_PATH):
		hud.toast("NO SAVE FOUND")
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	if data.is_empty():
		hud.toast("SAVE FILE UNREADABLE")
		return
	var p: Array = data["pos"]
	player.global_position = Vector3(p[0], p[1], p[2])
	player.rotation.y = data["yaw"]
	player.head.rotation.x = data["pitch"]
	player.velocity = Vector3.ZERO
	player.health = int(data["health"])
	player.health_changed.emit(player.health, Player.MAX_HEALTH)
	player.stamina.stamina = float(data["stamina"])
	player.stamina.stamina_changed.emit(player.stamina.stamina,
			player.stamina.MAX_STAMINA)
	var mags: Array = data["mags"]
	for i in mini(mags.size(), player.weapons._weapons.size()):
		player.weapons._weapons[i]["mag"] = int(mags[i])
	player.weapons._emit_ammo()
	if data.has("day"):
		time_manager.day = int(data["day"])
		time_manager.hour = float(data["hour"])
	_snd_load.play()
	hud.toast("GAME LOADED")
