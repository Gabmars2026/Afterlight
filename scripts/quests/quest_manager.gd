extends Node
## Quest system (Phase 9). Runs a chain of typed objectives and shows a
## beacon of light over "reach" targets. First quest: The Last Signal.

signal quest_changed(text: String)

var player: Node
var _steps: Array = []
var _idx := 0
var _kills := 0
var _beacon: MeshInstance3D
var _done_notified := false


func _ready() -> void:
	add_to_group("quest_listeners")
	_steps = [
		{"type": "reach", "text": "THE LAST SIGNAL: climb the BLUE TOWER and check the antenna",
			"target": Vector3(-37.5, 9.2, -28), "radius": 3.0},
		{"type": "kill", "text": "THE LAST SIGNAL: the noise drew them - put down %d/5 zombies",
			"count": 5},
		{"type": "collect", "text": "THE LAST SIGNAL: gather %d/5 SCRAP METAL to fix the radio",
			"id": "scrap", "count": 5},
		{"type": "reach", "text": "THE LAST SIGNAL: bring the scrap to the MARKET SHOP counter",
			"target": Vector3(36, 1.2, 14), "radius": 3.0,
			"deliver": {"id": "scrap", "count": 5}},
	]
	_build_beacon()
	_refresh()


func _build_beacon() -> void:
	_beacon = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.35
	cyl.height = 60.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.9, 1.0, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.8, 1.0)
	mat.emission_energy_multiplier = 1.6
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cyl.material = mat
	_beacon.mesh = cyl
	_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beacon)


func _process(_delta: float) -> void:
	if _idx >= _steps.size() or player == null:
		return
	var step: Dictionary = _steps[_idx]
	match step["type"]:
		"reach":
			if player.global_position.distance_to(step["target"]) <= step["radius"]:
				if step.has("deliver"):
					if player.inventory.count_of(step["deliver"]["id"]) \
							< step["deliver"]["count"]:
						return
					player.inventory.take(step["deliver"]["id"],
							step["deliver"]["count"])
				_advance()
		"collect":
			if player.inventory.count_of(step["id"]) >= step["count"]:
				_advance()


func on_enemy_killed() -> void:
	if _idx < _steps.size() and _steps[_idx]["type"] == "kill":
		_kills += 1
		if _kills >= _steps[_idx]["count"]:
			_advance()
		else:
			_refresh()


func _advance() -> void:
	_idx += 1
	_kills = 0
	player.notify.emit("OBJECTIVE COMPLETE")
	if _idx >= _steps.size():
		_complete()
	_refresh()


func _complete() -> void:
	if _done_notified:
		return
	_done_notified = true
	player.notify.emit("QUEST COMPLETE: THE LAST SIGNAL")
	player.pickup("bandage", 2)
	player.pickup("ammo_rifle", 30)


func _refresh() -> void:
	if _idx >= _steps.size():
		quest_changed.emit("THE LAST SIGNAL - COMPLETE  (more quests in Phase 17)")
		_beacon.visible = false
		return
	var step: Dictionary = _steps[_idx]
	var text: String = step["text"]
	if step["type"] == "kill":
		text = text % _kills
	elif step["type"] == "collect":
		text = text % mini(player.inventory.count_of(step["id"]) if player else 0,
				step["count"])
	quest_changed.emit(text)
	if step["type"] == "reach":
		_beacon.visible = true
		_beacon.position = step["target"] + Vector3(0, 28, 0)
	else:
		_beacon.visible = false


func notify_inventory_changed() -> void:
	# Keeps the collect counter live as the player gathers materials
	if _idx < _steps.size() and _steps[_idx]["type"] == "collect":
		_refresh()


func serialize() -> Array:
	return [_idx, _kills]


func restore(data: Array) -> void:
	_idx = clampi(int(data[0]), 0, _steps.size())
	_kills = int(data[1])
	if _idx >= _steps.size():
		_done_notified = true
	_refresh()
