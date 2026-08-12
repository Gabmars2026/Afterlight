extends Node
## Quest system (Phase 9, campaign in Phase 17). Runs a 5-quest main story
## with typed objectives - reach / kill / collect / talk - a light beacon
## over reach targets, per-quest rewards and faction reputation swings.
##
## THE AFTERLIGHT CAMPAIGN
##  1 The Last Signal     - the radio on the blue tower still whispers
##  2 Voices in the Static - Mara needs the warehouses checked
##  3 The Heights          - something is nesting on the office tower
##  4 Under the Park       - the survivors' water runs through the sewers
##  5 Afterlight           - relight the city beacon. Bring them home.

signal quest_changed(text: String)

var player: Node
var factions: Node
var _quests: Array = []
var _qidx := 0
var _idx := 0
var _kills := 0
var _beacon: MeshInstance3D
var _all_done := false


func _ready() -> void:
	add_to_group("quest_listeners")
	_quests = [
		{"name": "THE LAST SIGNAL", "steps": [
			{"type": "reach", "text": "climb the BLUE TOWER and check the antenna",
				"target": Vector3(-37.5, 9.2, -28), "radius": 3.0},
			{"type": "collect", "text": "gather %d/5 SCRAP METAL to fix the radio",
				"id": "scrap", "count": 5},
			{"type": "reach", "text": "bring the scrap to the MARKET SHOP counter",
				"target": Vector3(36, 1.2, 14), "radius": 3.0,
				"deliver": {"id": "scrap", "count": 5}},
		], "reward": {"items": {"bandage": 2, "ammo_rifle": 30},
			"rep": {"survivors": 15}}},
		{"name": "VOICES IN THE STATIC", "steps": [
			{"type": "talk", "text": "the radio names a trader - find MARA in the OLD MARKET",
				"npc": "MARA"},
			{"type": "reach", "text": "search the CANAL WAREHOUSES to the south",
				"target": Vector3(-25, 1.0, 52), "radius": 5.0},
			{"type": "collect", "text": "salvage %d/4 PLANKS from the docks",
				"id": "planks", "count": 4},
			{"type": "talk", "text": "bring word (and wood) to DEX at the market square",
				"npc": "DEX", "deliver": {"id": "planks", "count": 4}},
		], "reward": {"items": {"bat": 1, "ammo_pistol": 16},
			"rep": {"survivors": 10, "scavengers": 5}}},
		{"name": "THE HEIGHTS", "steps": [
			{"type": "reach", "text": "something nests on the OFFICE TOWER roof - climb the fire escape",
				"target": Vector3(-20, 15.8, -62), "radius": 5.0},
			{"type": "talk", "text": "report the rooftops clear to IVY",
				"npc": "IVY"},
		], "reward": {"items": {"ammo_pistol": 24, "bandage": 1},
			"rep": {"wardens": 15}}},
		{"name": "UNDER THE PARK", "steps": [
			{"type": "reach", "text": "the water line runs under GREENROW - descend into the SEWERS",
				"target": Vector3(58, -3.8, -38), "radius": 5.0},
			{"type": "collect", "text": "gather %d/3 CLOTH to filter the water intake",
				"id": "cloth", "count": 3},
		], "reward": {"items": {"bandage": 3, "ammo_rifle": 20},
			"rep": {"scavengers": 15, "survivors": 5}}},
		{"name": "AFTERLIGHT", "steps": [
			{"type": "collect", "text": "the beacon needs parts - gather %d/8 SCRAP METAL",
				"id": "scrap", "count": 8},
			{"type": "reach", "text": "install the beacon atop the BLUE TOWER",
				"target": Vector3(-37.5, 9.2, -28), "radius": 3.0,
				"deliver": {"id": "scrap", "count": 8}},
		], "reward": {"items": {"bandage": 3, "ammo_rifle": 40, "ammo_pistol": 24},
			"rep": {"survivors": 20, "wardens": 20, "scavengers": 20}}},
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


func _step() -> Dictionary:
	if _qidx >= _quests.size():
		return {}
	var steps: Array = _quests[_qidx]["steps"]
	if _idx >= steps.size():
		return {}
	return steps[_idx]


func _process(_delta: float) -> void:
	var step := _step()
	if step.is_empty() or player == null:
		return
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
	var step := _step()
	if step.get("type", "") == "kill":
		_kills += 1
		if _kills >= step["count"]:
			_advance()
		else:
			_refresh()


func on_npc_talked(nm: String) -> void:
	var step := _step()
	if step.get("type", "") == "talk" and step["npc"] == nm:
		if step.has("deliver"):
			if player.inventory.count_of(step["deliver"]["id"]) \
					< step["deliver"]["count"]:
				player.notify.emit("%s NEEDS %d %s" % [nm,
						step["deliver"]["count"],
						step["deliver"]["id"].to_upper()])
				return
			player.inventory.take(step["deliver"]["id"], step["deliver"]["count"])
		_advance()


func _advance() -> void:
	_idx += 1
	_kills = 0
	player.notify.emit("OBJECTIVE COMPLETE")
	if _idx >= _quests[_qidx]["steps"].size():
		_complete_quest()
	_refresh()


func _complete_quest() -> void:
	var q: Dictionary = _quests[_qidx]
	player.notify.emit("QUEST COMPLETE: " + q["name"])
	var reward: Dictionary = q["reward"]
	for id in reward["items"]:
		player.pickup(id, reward["items"][id])
	if factions:
		for f in reward["rep"]:
			factions.add_rep(f, reward["rep"][f])
	_qidx += 1
	_idx = 0
	if _qidx >= _quests.size():
		_finale()


func _finale() -> void:
	if _all_done:
		return
	_all_done = true
	player.notify.emit("THE BEACON BURNS - MERIDIAN FALLS REMEMBERS")
	# A permanent warm light column over the blue tower
	var column := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.8
	cyl.bottom_radius = 0.8
	cyl.height = 120.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.5, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.4)
	mat.emission_energy_multiplier = 2.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cyl.material = mat
	column.mesh = cyl
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	column.position = Vector3(-37.5, 60, -28)
	add_child(column)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.85, 0.55)
	lamp.light_energy = 2.0
	lamp.omni_range = 30.0
	lamp.position = Vector3(-37.5, 12, -28)
	add_child(lamp)


func _refresh() -> void:
	if _qidx >= _quests.size():
		quest_changed.emit("AFTERLIGHT RESTORED - Meridian Falls breathes again")
		_beacon.visible = false
		return
	var q: Dictionary = _quests[_qidx]
	var step := _step()
	var text: String = q["name"] + " (%d/%d): " % [_qidx + 1, _quests.size()] \
			+ step["text"]
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
	if _step().get("type", "") == "collect":
		_refresh()


func current_reach_target() -> Variant:
	## Where the active objective is, or null (used by the map screen).
	if _qidx >= _quests.size():
		return null
	var steps: Array = _quests[_qidx]["steps"]
	if _idx >= steps.size():
		return null
	var step: Dictionary = steps[_idx]
	if step["type"] == "reach":
		return step["target"]
	return null


func serialize() -> Array:
	return [_qidx, _idx, _kills]


func restore(data: Array) -> void:
	if data.size() >= 3:
		_qidx = clampi(int(data[0]), 0, _quests.size())
		_idx = int(data[1])
		_kills = int(data[2])
	else:
		# old save format: [idx, kills] within quest 1
		_qidx = 0
		_idx = clampi(int(data[0]), 0, _quests[0]["steps"].size())
		_kills = int(data[1])
	if _qidx >= _quests.size():
		_all_done = false
		_finale()
	_refresh()
