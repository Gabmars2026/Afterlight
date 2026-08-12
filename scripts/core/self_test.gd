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
	var castle := _zone.get_node_or_null("Castle")
	_check(castle != null, "castle present")
	_check(castle != null and castle.get_child_count() > 300, "castle fully built")
	var dragons := _zone.get_tree().get_nodes_in_group("dragon")
	_check(dragons.size() == 2, "two dungeon dragons")
	_check(dragons.size() > 0 and dragons[0].has_method("take_hit"), "dragons can be shot")
	var civs := _zone.get_tree().get_nodes_in_group("citizens")
	_check(civs.size() >= 18, "townsfolk spawned")
	_check(_zone.get_tree().get_nodes_in_group("cops").size() >= 4, "police on patrol")
	_check(_zone.get_node_or_null("WantedManager") != null, "wanted system active")
	_check(_zone.get_tree().get_nodes_in_group("traffic").size() >= 6, "traffic on the streets")
	var dt := _zone.get_node_or_null("Downtown")
	_check(dt != null, "NEON DISTRICT built")
	_check(dt != null and dt.get_node_or_null("BarLight") != null, "the bar is lit")
	var t0 := dt.get_node_or_null("Tower0") if dt else null
	_check(t0 != null, "towers are individual nodes")
	_check(t0 != null and t0.get_child_count() >= 80,
			"tower has 20 floors of interior")
	_check(_zone.get_tree().get_nodes_in_group("city_asset").size() >= 30,
			"downtown has dense detailed commercial blocks")
	var rd := _zone.get_node_or_null("Residential")
	_check(rd != null, "SUNSET FLATS district exists")
	var homes := _zone.get_tree().get_nodes_in_group("residential_house")
	var detailed_homes := _zone.get_tree().get_nodes_in_group("suburban_asset_house")
	var enterable_homes := _zone.get_tree().get_nodes_in_group("enterable_house")
	_check(homes.size() == 80, "80 homes fill SUNSET FLATS")
	_check(detailed_homes.size() == 48, "48 detailed Kenney houses placed")
	_check(enterable_homes.size() == 32, "32 enterable houses retained")
	var block_counts: Array[int] = rd.block_house_counts() if rd else []
	_check(block_counts == [20, 20, 20, 20],
			"each of four residential blocks has exactly 20 homes")
	_check(rd != null and rd.has_method("driving_grid_clear")
			and rd.driving_grid_clear(), "residential driving grid stays clear")
	var pl := _zone.get_tree().get_first_node_in_group("player")
	_check(pl != null and pl.find_child("OutfitHat", true, false) != null,
			"the survivor wears a cap")
	var dressed := 0
	for cz in _zone.get_tree().get_nodes_in_group("citizens"):
		if cz.find_child("OutfitVest", true, false) != null \
				or cz.find_child("OutfitShorts", true, false) != null:
			dressed += 1
	_check(dressed == 0, "no boxes strapped to citizens")
	_check(_zone.find_child("LightningBolt", true, false) != null,
			"lightning bolt rigged for rainstorms")
	var flora := _zone.get_node_or_null("Flora")
	_check(flora != null and flora.palms >= 40,
			"palm trees rise from the dunes")
	var gt: MultiMeshInstance3D = flora.get_node_or_null("GrassTufts") \
			if flora else null
	_check(gt != null and gt.multimesh.instance_count >= 800,
			"grass carpets the outskirts")
	var fr := _zone.get_node_or_null("Frontier")
	_check(fr != null, "frontier built (ocean + mountains)")
	var peaks := 0
	if fr:
		for c in fr.get_children():
			if c is MeshInstance3D and c.get_child_count() > 0 \
					and c.mesh is CylinderMesh:
				peaks += 1
	_check(peaks >= 4, "climbable mountains have collision")
	_check(fr != null and fr.has_method("driving_pass_clear")
			and fr.driving_pass_clear(), "mountain driving pass stays clear")
	var tcars := _zone.get_tree().get_nodes_in_group("traffic")
	var modeled := 0
	for tc in tcars:
		var vis := tc.get_node_or_null("Visual")
		if vis and vis.get_child_count() >= 4:
			modeled += 1
	_check(modeled >= 6, "traffic uses real car models")
	_check(_zone.get_tree().get_nodes_in_group("enemies").is_empty(),
			"streets are zombie-free")
	var steal_ok := tcars.size() > 0
	for tc2 in tcars:
		if not tc2.has_method("interact"):
			steal_ok = false
	_check(steal_ok, "any traffic car can be carjacked")
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
