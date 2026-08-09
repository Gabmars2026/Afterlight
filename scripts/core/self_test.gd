extends Node
## Phase 19: automated self-test. Run with:
##   godot --headless --path . -- --selftest
## Exercises inventory, crafting, combat math, factions, weather, quests,
## save/load and world streaming, then quits with exit code 0 (all pass)
## or 1 (failures, listed in the output).

var _zone: Node
var _fails: Array[String] = []
var _count := 0


func run(zone: Node) -> void:
	_zone = zone
	await _zone.get_tree().process_frame
	await _zone.get_tree().process_frame
	print("=== AFTERLIGHT SELF-TEST ===")
	_test_inventory()
	_test_crafting()
	_test_player()
	_test_factions()
	_test_weather()
	_test_quests()
	await _test_save_load()
	await _test_streaming()
	print("=== %d checks, %d failed ===" % [_count, _fails.size()])
	for f in _fails:
		print("FAIL: " + f)
	_zone.get_tree().quit(0 if _fails.is_empty() else 1)


func _check(cond: bool, label: String) -> void:
	_count += 1
	if not cond:
		_fails.append(label)


func _test_inventory() -> void:
	var inv = _zone.player.inventory
	var before: int = inv.count_of("scrap")
	var left: int = inv.add_item("scrap", 3)
	_check(left == 0, "inventory accepts 3 scrap")
	_check(inv.count_of("scrap") == before + 3, "scrap count updates")
	var taken: int = inv.take("scrap", 2)
	_check(taken == 2, "take() returns what it removed")
	_check(inv.count_of("scrap") == before + 1, "scrap count after take")
	inv.take("scrap", 99)  # drain the rest


func _test_crafting() -> void:
	var inv = _zone.player.inventory
	inv.take("cloth", 99)
	_check(not inv.can_craft(0), "cannot craft bandage without cloth")
	inv.add_item("cloth", 2)
	_check(inv.can_craft(0), "can craft bandage with 2 cloth")
	var err: String = inv.craft(0)
	_check(err == "", "crafting bandage succeeds")
	_check(inv.count_of("cloth") == 0, "crafting consumed the cloth")


func _test_player() -> void:
	var p = _zone.player
	var hp0: int = p.health
	p.take_damage(10)
	_check(p.health == hp0 - 10, "take_damage subtracts health")
	p.heal(10)
	_check(p.health == hp0, "heal restores health")
	var got: int = p.pickup("bandage", 1)
	_check(got == 1, "pickup adds to inventory")
	p.inventory.take("bandage", 1)


func _test_factions() -> void:
	var f = _zone.get_tree().get_first_node_in_group("quest_listeners")
	# find the faction manager specifically
	f = null
	for n in _zone.get_tree().get_nodes_in_group("quest_listeners"):
		if "rep" in n and n.get("rep") is Dictionary:
			f = n
			break
	_check(f != null, "faction manager present")
	if f == null:
		return
	var r0: int = f.rep["survivors"]
	f.add_rep("survivors", 10)
	_check(f.rep["survivors"] == clampi(r0 + 10, -100, 100), "add_rep applies")
	f.add_rep("feral", 50)
	_check(f.rep["feral"] == -100, "feral reputation stays locked")
	f.rep["survivors"] = r0


func _test_weather() -> void:
	var w = _zone.get_node_or_null("WeatherManager")
	if w == null:
		for c in _zone.get_children():
			if "rain_scale" in c:
				w = c
				break
	_check(w != null, "weather manager present")
	if w == null:
		return
	for st in ["clear", "overcast", "fog", "rain", "storm"]:
		w._set_state(st)
		_check(w.state == st, "weather can enter " + st)
	w._set_state("clear")


func _test_quests() -> void:
	var q = null
	for n in _zone.get_tree().get_nodes_in_group("quest_listeners"):
		if "_quests" in n:
			q = n
			break
	_check(q != null, "quest manager present")
	if q == null:
		return
	_check(q._quests.size() == 5, "campaign has 5 quests")
	var snap: Array = q.serialize()
	q.restore([1, 0, 0])
	_check(q._qidx == 1, "quest restore jumps to quest 2")
	q.restore([1, 0])  # old v2 format: [step_idx, kills]
	_check(q._qidx == 0 and q._idx == 1, "old save format still restores")
	q.restore(snap)


func _test_save_load() -> void:
	var saver = null
	for c in _zone.get_children():
		if "quest_manager" in c and c.has_method("save_game"):
			saver = c
			break
	_check(saver != null, "save manager present")
	if saver == null:
		return
	var p = _zone.player
	var pos0: Vector3 = p.global_position
	saver.save_game()
	p.global_position = pos0 + Vector3(5, 0, 5)
	saver.load_game()
	await _zone.get_tree().process_frame
	_check(p.global_position.distance_to(pos0) < 1.0, "save/load restores position")


func _test_streaming() -> void:
	var streamer = _zone.get_tree().get_first_node_in_group("streamer")
	_check(streamer != null, "world streamer present")
	if streamer == null:
		return
	var p = _zone.player
	var pos0: Vector3 = p.global_position
	p.global_position = Vector3(220, 0.6, 220)
	# let the streamer queue and build cells (1 per physics frame)
	for i in 60:
		await _zone.get_tree().physics_frame
	var props := _zone.get_tree().get_nodes_in_group("prop")
	_check(props.size() >= 30, "interior props placed (%d)" % props.size())
	var weather := _zone.get_node_or_null("Weather")
	_check(weather != null, "weather system present")
	_check(weather != null and weather.get_child_count() > 20, "cloud layer built")
	var cars := _zone.get_tree().get_nodes_in_group("vehicle")
	_check(cars.size() >= 1, "drivable car present")
	_check(cars.size() >= 1 and cars[0].has_method("interact"), "car is enterable")
	var eb := load("res://scripts/ai/enemy_base.gd")
	var zt: CharacterBody3D = eb.new()
	zt.direct_nav = true
	zt.position = Vector3(5, 0.5, 5)
	_zone.add_child(zt)
	await _zone.get_tree().physics_frame
	_check(zt._anim != null, "zombie rig has AnimationPlayer")
	_check(zt._anim != null and zt._anim.is_playing(), "zombie animation playing")
	zt.queue_free()
	var terrain := _zone.get_node_or_null("Terrain")
	_check(terrain != null, "Terrain3D node exists")
	if terrain:
		var td: Object = terrain.get("data")
		_check(absf(td.get_height(Vector3.ZERO) - (-8.0)) < 0.5,
				"terrain buried under town slab")
		_check(td.get_height(Vector3(300, 0, 300)) > 0.5,
				"dunes rise in the outskirts")
	_check(streamer.cell_count() >= 9, "outskirt cells stream in (got %d)"
			% streamer.cell_count())
	p.global_position = pos0
	for i in 30:
		await _zone.get_tree().physics_frame
