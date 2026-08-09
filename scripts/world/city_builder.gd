extends Node3D
## Phase 15: the rest of Meridian Falls. Expands the handcrafted map from
## 90x90 to 150x150 with four districts around the old town, plus the
## city's first underground area - a sewer line under Greenrow park.
##
##   North  (z -75..-45)  MERIDIAN HEIGHTS - office towers, plaza
##   South  (z  45..75)   CANAL DISTRICT   - canal, bridges, warehouses
##   East   (x  45..75)   GREENROW         - ruined park, pond, sewer
##   West   (x -75..-45)  ASHLINE          - burned ruins, feral ground

const LootCrateScript := preload("res://scripts/world/loot_crate.gd")
const PropLib := preload("res://scripts/world/prop_lib.gd")
const InteriorZoneScript := preload("res://scripts/world/interior_zone.gd")

var nav_parent: Node3D            # static geometry -> baked into navmesh
var sand_mat: StandardMaterial3D
var cobble_mat: StandardMaterial3D
var plaster_mat: StandardMaterial3D

var _burn_mat: StandardMaterial3D
var _water_mat: StandardMaterial3D


func build() -> void:
	_burn_mat = StandardMaterial3D.new()
	_burn_mat.albedo_color = Color(0.16, 0.14, 0.13)
	_burn_mat.roughness = 1.0
	_water_mat = StandardMaterial3D.new()
	_water_mat.albedo_color = Color(0.15, 0.3, 0.38, 0.75)
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_mat.roughness = 0.15
	_water_mat.metallic = 0.3

	_ground_ring()
	_roads()
	_meridian_heights()
	_canal_district()
	_greenrow()
	_ashline()
	_sewer()


## ---------------------------------------------------------------- ground
func _ground_ring() -> void:
	# North + south strips (full width)
	_box(Vector3(150, 1, 30), Vector3(0, -0.5, -60), sand_mat)
	# South strip is split around the canal trench (z 66..73)
	_box(Vector3(150, 1, 21), Vector3(0, -0.5, 55.5), sand_mat)
	_box(Vector3(150, 1, 2), Vector3(0, -0.5, 74), sand_mat)
	# Canal bed + water
	_box(Vector3(150, 1, 7), Vector3(0, -3.0, 69.5), sand_mat, Color(0.5, 0.5, 0.48))
	var water := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(150, 0.1, 7)
	wm.material = _water_mat
	water.mesh = wm
	water.position = Vector3(0, -1.3, 69.5)
	add_child(water)
	# Canal walls
	_box(Vector3(150, 2.6, 0.5), Vector3(0, -1.3, 65.8), plaster_mat, Color(0.6, 0.6, 0.58))
	_box(Vector3(150, 2.6, 0.5), Vector3(0, -1.3, 73.2), plaster_mat, Color(0.6, 0.6, 0.58))
	# West strip (full)
	_box(Vector3(30, 1, 90), Vector3(-60, -0.5, 0), sand_mat)
	# East strip - hole at x 50..62, z -2..4 for the sewer shaft
	_box(Vector3(30, 1, 43), Vector3(60, -0.5, -23.5), sand_mat)
	_box(Vector3(30, 1, 41), Vector3(60, -0.5, 24.5), sand_mat)
	_box(Vector3(13, 1, 6), Vector3(68.5, -0.5, 1), sand_mat)
	_box(Vector3(5, 1, 6), Vector3(47.5, -0.5, 1), sand_mat)


func _roads() -> void:
	# Extend the town's two main streets to the new edges
	_box(Vector3(5, 1.04, 30), Vector3(-2, -0.5, -60), cobble_mat)
	_box(Vector3(5, 1.04, 21), Vector3(-2, -0.5, 55.5), cobble_mat)
	_box(Vector3(30, 1.04, 5), Vector3(-60, -0.5, 10), cobble_mat)
	_box(Vector3(30, 1.04, 5), Vector3(60, -0.5, 10), cobble_mat)
	# Bridges over the canal
	_box(Vector3(6, 1.1, 10), Vector3(-2, -0.45, 69.5), cobble_mat)
	_box(Vector3(6, 1.1, 10), Vector3(28, -0.45, 69.5), cobble_mat)


## ------------------------------------------------- north: Meridian Heights
func _meridian_heights() -> void:
	# TOWER A (-20,-62): enterable lobby + fire escape to the roof
	var ax := -20.0
	var az := -62.0
	var h := 15.0
	var c := Color(0.55, 0.6, 0.65)
	# Lobby: 4 walls with a south door gap
	_box(Vector3(14, 3.2, 0.4), Vector3(ax, 1.6, az - 6), plaster_mat, c)
	_box(Vector3(0.4, 3.2, 12), Vector3(ax - 7, 1.6, az), plaster_mat, c)
	_box(Vector3(0.4, 3.2, 12), Vector3(ax + 7, 1.6, az), plaster_mat, c)
	_box(Vector3(5.4, 3.2, 0.4), Vector3(ax - 4.3, 1.6, az + 6), plaster_mat, c)
	_box(Vector3(5.4, 3.2, 0.4), Vector3(ax + 4.3, 1.6, az + 6), plaster_mat, c)
	_box(Vector3(3.2, 0.9, 0.4), Vector3(ax, 2.75, az + 6), plaster_mat, c)
	# Lobby props + loot
	_box(Vector3(4, 1.0, 1.2), Vector3(ax, 0.5, az - 3), plaster_mat, Color(0.4, 0.32, 0.28), "wood")
	_crate(Vector3(ax + 5, 0.4, az - 4))
	# Tower body above the lobby
	_box(Vector3(14, h - 3.2, 14), Vector3(ax, 3.2 + (h - 3.2) * 0.5, az), plaster_mat, c.darkened(0.12))
	# Window strips (visual)
	for f in 3:
		_box(Vector3(14.2, 0.7, 14.2), Vector3(ax, 5.6 + f * 3.0, az),
				plaster_mat, Color(0.25, 0.3, 0.38))
	# Fire escape: two-lane switchback staircase up the east face.
	# Even flights climb north->south on the inner lane, odd flights come
	# back on the outer lane; a shared landing joins them at each level.
	var esc := Color(0.35, 0.3, 0.28)
	for k in 5:
		var dk: float = 1.0 if k % 2 == 0 else -1.0
		var lane: float = ax + (7.75 if k % 2 == 0 else 8.95)
		var base := 3.0 * k
		for j in 10:
			_box(Vector3(1.2, 0.32, 1.2),
					Vector3(lane, base + 0.3 * (j + 1) - 0.16, az + dk * (-3.9 + j * 0.867)),
					plaster_mat, esc.darkened(0.05) if j % 2 == 0 else esc.darkened(0.12), "metal")
			if k % 2 == 1 and j % 2 == 0:
				_box(Vector3(0.12, 0.9, 0.8),
						Vector3(ax + 9.61, base + 0.3 * (j + 1) + 0.55,
						az + dk * (-3.9 + j * 0.867)), plaster_mat, esc.darkened(0.2), "metal")
		# Turn landing at the top of this flight (spans both lanes)
		var lz := az + dk * 5.75
		_box(Vector3(2.4, 0.3, 2.5), Vector3(ax + 8.35, base + 2.85, lz), plaster_mat, esc, "metal")
		_box(Vector3(0.12, 1.0, 2.5), Vector3(ax + 9.61, base + 3.5, lz), plaster_mat, esc.darkened(0.2), "metal")
		_box(Vector3(2.6, 1.0, 0.12), Vector3(ax + 8.35, base + 3.5, az + dk * 7.0), plaster_mat, esc.darkened(0.2), "metal")

	# Roof lip + reward
	_box(Vector3(14.6, 0.5, 0.5), Vector3(ax, h + 0.25, az - 7), plaster_mat, c)
	_box(Vector3(14.6, 0.5, 0.5), Vector3(ax, h + 0.25, az + 7), plaster_mat, c)
	_crate(Vector3(ax - 3, h + 0.4, az))

	# TOWER B (18,-62): stepped ledges for climbing practice
	var bx := 18.0
	var bz := -62.0
	var c2 := Color(0.62, 0.55, 0.48)
	_box(Vector3(12, 6, 12), Vector3(bx, 3, bz), plaster_mat, c2)
	_box(Vector3(9, 5, 9), Vector3(bx, 8.5, bz), plaster_mat, c2.darkened(0.1))
	_box(Vector3(6, 4, 6), Vector3(bx, 13, bz), plaster_mat, c2.darkened(0.2))
	_crate(Vector3(bx, 15.4, bz))

	# Plaza between the towers: dry fountain + benches
	_box(Vector3(24, 1.06, 18), Vector3(0, -0.5, -62), cobble_mat)
	_box(Vector3(5, 0.8, 5), Vector3(0, 0.4, -62), plaster_mat, Color(0.6, 0.6, 0.58))
	_box(Vector3(3.4, 0.5, 3.4), Vector3(0, 1.05, -62), plaster_mat, Color(0.45, 0.5, 0.52))
	for bpos in [Vector3(-7, 0.35, -55), Vector3(7, 0.35, -55)]:
		_box(Vector3(3, 0.7, 0.9), bpos, plaster_mat, Color(0.4, 0.32, 0.26), "wood")
	_spawn("screamer", Vector3(-6, 0.1, -66))
	_spawn("shambler", Vector3(8, 0.1, -58))


## ---------------------------------------------------- south: Canal District
func _canal_district() -> void:
	for wx in [-25.0, 10.0]:
		var wz := 52.0
		var c := Color(0.5, 0.42, 0.36) if wx < 0 else Color(0.42, 0.46, 0.5)
		# Warehouse shell 14x10, big north door gap
		_box(Vector3(14, 5, 0.4), Vector3(wx, 2.5, wz + 5), plaster_mat, c)
		_box(Vector3(0.4, 5, 10), Vector3(wx - 7, 2.5, wz), plaster_mat, c)
		_box(Vector3(0.4, 5, 10), Vector3(wx + 7, 2.5, wz), plaster_mat, c)
		_box(Vector3(4.4, 5, 0.4), Vector3(wx - 4.8, 2.5, wz - 5), plaster_mat, c)
		_box(Vector3(4.4, 5, 0.4), Vector3(wx + 4.8, 2.5, wz - 5), plaster_mat, c)
		_box(Vector3(5.4, 1.6, 0.4), Vector3(wx, 4.2, wz - 5), plaster_mat, c)
		_box(Vector3(14.6, 0.4, 10.6), Vector3(wx, 5.2, wz), plaster_mat, c.darkened(0.25))
		# Crate stacks inside (climbable)
		_box(Vector3(2, 2, 2), Vector3(wx - 4, 1, wz + 2), plaster_mat, Color(0.55, 0.42, 0.3), "wood")
		_box(Vector3(2, 2, 2), Vector3(wx - 1.8, 1, wz + 2), plaster_mat, Color(0.5, 0.38, 0.28), "wood")
		_box(Vector3(2, 2, 2), Vector3(wx - 4, 3, wz + 2), plaster_mat, Color(0.6, 0.45, 0.33), "wood")
		_crate(Vector3(wx + 3, 0.4, wz + 2))
		var zone := InteriorZoneScript.new()
		zone.bus_name = "Interior"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(13, 4.6, 9)
		shape.shape = box
		zone.add_child(shape)
		zone.position = Vector3(wx, 2.4, wz)
		add_child(zone)
		# Phase 16: warehouse clutter from the Medieval Village pack
		PropLib.place(self, "Barril", Vector3(wx + 5.8, 0, wz - 2.5))
		PropLib.place(self, "Barril", Vector3(wx + 5.7, 0, wz - 1.2), 1.1)
		PropLib.place(self, "Barril", Vector3(wx + 5.9, 0, wz + 0.1), 2.4, 0.92)
		PropLib.place(self, "Wood_Trunk", Vector3(wx - 5.5, 0, wz - 3.0), 0.3)
		PropLib.place(self, "Table", Vector3(wx + 2.0, 0, wz - 2.2), 0.15, 0.8)
		PropLib.place(self, "Seat", Vector3(wx + 0.6, 0, wz - 2.2), PI / 2, 0.8)
		PropLib.place(self, "Chope_B", Vector3(wx + 2.1, 1.12, wz - 2.4), 0.8, 0.55, false)
		PropLib.place(self, "Lamp", Vector3(wx, 5.0, wz), 0.0, 1.0, false)
		var wlight := OmniLight3D.new()
		wlight.light_color = Color(1.0, 0.82, 0.6)
		wlight.light_energy = 0.9
		wlight.omni_range = 7.0
		wlight.position = Vector3(wx, 4.1, wz)
		add_child(wlight)
	_crate(Vector3(-2, 0.5, 60))
	_spawn("brute", Vector3(-25, 0.1, 52))
	_spawn("shambler", Vector3(18, 0.1, 60))


## ---------------------------------------------------------- east: Greenrow
func _greenrow() -> void:
	# Trees
	var spots := [Vector3(50, 0, -30), Vector3(58, 0, -35), Vector3(68, 0, -25),
			Vector3(52, 0, 18), Vector3(66, 0, 22), Vector3(70, 0, 34),
			Vector3(55, 0, 38), Vector3(64, 0, -8)]
	for i in spots.size():
		_tree(spots[i], 2.6 + (i % 3) * 0.7)
	# Pond
	var pond := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 6.0
	pm.bottom_radius = 6.0
	pm.height = 0.1
	pm.material = _water_mat
	pond.mesh = pm
	pond.position = Vector3(62, 0.06, -18)
	add_child(pond)
	# Gazebo: slab + 4 posts + roof
	var gz := Vector3(56, 0, 28)
	_box(Vector3(6, 0.4, 6), gz + Vector3(0, 0.2, 0), plaster_mat, Color(0.5, 0.4, 0.3), "wood")
	for off in [Vector3(-2.5, 0, -2.5), Vector3(2.5, 0, -2.5), Vector3(-2.5, 0, 2.5), Vector3(2.5, 0, 2.5)]:
		_box(Vector3(0.4, 2.8, 0.4), gz + off + Vector3(0, 1.8, 0), plaster_mat, Color(0.45, 0.36, 0.28), "wood")
	_box(Vector3(7, 0.4, 7), gz + Vector3(0, 3.4, 0), plaster_mat, Color(0.35, 0.28, 0.22), "wood")
	_crate(gz + Vector3(0, 0.8, 0))
	# Two small park houses (one-room, enterable)
	_house(Vector3(52, 0, -38), Color(0.75, 0.68, 0.55))
	_house(Vector3(70, 0, 42), Color(0.68, 0.72, 0.6))
	_spawn("climber", Vector3(60, 0.1, 30))
	_spawn("stalker", Vector3(55, 0.1, -25))


## ----------------------------------------------------------- west: Ashline
func _ashline() -> void:
	# Charred ruined shells
	for r in [[-62.0, -30.0, 8.0, 6.0], [-55.0, -10.0, 10.0, 5.0], [-68.0, 20.0, 7.0, 7.0],
			[-52.0, 34.0, 9.0, 5.0]]:
		var rx: float = r[0]
		var rz: float = r[1]
		var w: float = r[2]
		var d: float = r[3]
		_box(Vector3(w, 2.6, 0.4), Vector3(rx, 1.3, rz - d * 0.5), _burn_mat)
		_box(Vector3(0.4, 2.2, d), Vector3(rx - w * 0.5, 1.1, rz), _burn_mat)
		_box(Vector3(w * 0.4, 1.4, 0.4), Vector3(rx + w * 0.2, 0.7, rz + d * 0.5), _burn_mat)
		# Fallen beam
		var beam := _box(Vector3(0.5, 0.5, d * 1.2), Vector3(rx + 1, 1.0, rz), _burn_mat, Color.WHITE, "wood")
		beam.rotation_degrees = Vector3(18, 25, 0)
	# Ash piles
	for p in [Vector3(-58, 0.25, 0), Vector3(-64, 0.2, -18), Vector3(-50, 0.3, 22)]:
		_box(Vector3(3, 0.5, 3), p, plaster_mat, Color(0.22, 0.2, 0.19))
	# Road barricade
	_box(Vector3(2, 1.6, 6), Vector3(-47, 0.8, 10), _burn_mat, Color.WHITE, "metal")
	# Abandoned survivor camp: tent + cold fire + supplies
	var camp := Vector3(-66, 0, 36)
	_box(Vector3(3.4, 0.3, 3), camp + Vector3(0, 0.15, 0), plaster_mat, Color(0.35, 0.38, 0.3), "wood")
	var tent_l := _box(Vector3(0.2, 2.6, 3), camp + Vector3(-1.1, 1.0, 0), plaster_mat, Color(0.45, 0.42, 0.3))
	tent_l.rotation_degrees = Vector3(0, 0, 38)
	var tent_r := _box(Vector3(0.2, 2.6, 3), camp + Vector3(1.1, 1.0, 0), plaster_mat, Color(0.45, 0.42, 0.3))
	tent_r.rotation_degrees = Vector3(0, 0, -38)
	_box(Vector3(1, 0.35, 1), camp + Vector3(0, 0.18, 2.4), _burn_mat)
	_crate(camp + Vector3(2.2, 0.4, 1))
	_crate(camp + Vector3(-2.4, 0.4, 2))
	_spawn("screamer", Vector3(-58, 0.1, -12))
	_spawn("brute", Vector3(-60, 0.1, 14))
	_spawn("hunter", Vector3(-52, 0.1, 30))


## ------------------------------------------------------------- underground
func _sewer() -> void:
	## Shaft opens at x 50..62, z -2..4 in Greenrow; stairs descend east.
	var grime := Color(0.35, 0.4, 0.36)
	# Shaft floor + stairs down (10 steps, 0.42 each)
	_box(Vector3(12, 0.4, 6), Vector3(56, -4.4, 1), plaster_mat, grime)
	for i in 10:
		_box(Vector3(0.62, 0.4, 6), Vector3(50.3 + i * 0.6, -0.2 - i * 0.42, 1),
				plaster_mat, grime.darkened(0.1))
	# Shaft walls (below ground level)
	_box(Vector3(12.4, 4.4, 0.4), Vector3(56, -2.2, -2.1), plaster_mat, grime)
	_box(Vector3(12.4, 4.4, 0.4), Vector3(56, -2.2, 4.1), plaster_mat, grime)
	_box(Vector3(0.4, 4.4, 6.4), Vector3(62.2, -2.2, 1), plaster_mat, grime)
	# Surface guard rail around the hole
	_box(Vector3(12.6, 1.0, 0.3), Vector3(56, 0.5, -2.3), plaster_mat, Color(0.4, 0.35, 0.3), "metal")
	_box(Vector3(12.6, 1.0, 0.3), Vector3(56, 0.5, 4.3), plaster_mat, Color(0.4, 0.35, 0.3), "metal")
	_box(Vector3(0.3, 1.0, 6.6), Vector3(62.3, 0.5, 1), plaster_mat, Color(0.4, 0.35, 0.3), "metal")
	# Tunnel north: x 56..60, z -32..-2, clear height ~3.1
	_box(Vector3(4, 0.4, 30), Vector3(58, -4.4, -17), plaster_mat, grime)
	_box(Vector3(0.4, 4.0, 30), Vector3(56.0, -2.4, -17), plaster_mat, grime.darkened(0.12))
	_box(Vector3(0.4, 4.0, 30), Vector3(60.0, -2.4, -17), plaster_mat, grime.darkened(0.12))
	_box(Vector3(4.8, 0.4, 30), Vector3(58, -0.9, -17), plaster_mat, grime.darkened(0.2))
	# Sludge channel down the middle (visual)
	var sludge := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(1.4, 0.08, 29)
	var slm := StandardMaterial3D.new()
	slm.albedo_color = Color(0.2, 0.3, 0.18, 0.85)
	slm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slm.emission_enabled = true
	slm.emission = Color(0.1, 0.25, 0.08)
	slm.emission_energy_multiplier = 0.4
	sm.material = slm
	sludge.mesh = sm
	sludge.position = Vector3(58, -4.14, -17)
	add_child(sludge)
	# End chamber: x 50..66, z -44..-32
	_box(Vector3(16, 0.4, 12), Vector3(58, -4.4, -38), plaster_mat, grime)
	_box(Vector3(16.4, 4.0, 0.4), Vector3(58, -2.4, -44.2), plaster_mat, grime)
	_box(Vector3(0.4, 4.0, 12), Vector3(49.8, -2.4, -38), plaster_mat, grime)
	_box(Vector3(0.4, 4.0, 12), Vector3(66.2, -2.4, -38), plaster_mat, grime)
	_box(Vector3(6.2, 4.0, 0.4), Vector3(52.8, -2.4, -32), plaster_mat, grime)
	_box(Vector3(6.2, 4.0, 0.4), Vector3(63.2, -2.4, -32), plaster_mat, grime)
	_box(Vector3(16.4, 0.4, 12.8), Vector3(58, -0.9, -38), plaster_mat, grime.darkened(0.2))
	# Big rusted pipes along the chamber wall
	for i in 3:
		var pipe := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.45
		cm.bottom_radius = 0.45
		cm.height = 15.0
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.42, 0.28, 0.2)
		rm.roughness = 0.9
		cm.material = rm
		pipe.mesh = cm
		pipe.rotation_degrees = Vector3(0, 0, 90)
		pipe.position = Vector3(58, -1.6 - i * 1.1, -43.6)
		add_child(pipe)
	# Glowing fungus clusters (the only light down here besides your torch)
	for fpos in [Vector3(56.4, -3.9, -8), Vector3(59.6, -3.9, -22),
			Vector3(51, -3.9, -36), Vector3(64, -3.9, -41)]:
		var f := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.35
		fm.height = 0.5
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(0.5, 0.9, 0.5)
		glow.emission_enabled = true
		glow.emission = Color(0.3, 0.9, 0.35)
		glow.emission_energy_multiplier = 1.6
		fm.material = glow
		f.mesh = fm
		f.position = fpos
		add_child(f)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(0.4, 0.9, 0.45)
		lamp.light_energy = 0.9
		lamp.omni_range = 7.0
		lamp.position = fpos + Vector3(0, 0.6, 0)
		add_child(lamp)
	# Loot guarded by a hunter in the dark
	_crate(Vector3(52, -3.8, -40))
	_crate(Vector3(63, -3.8, -34))
	_spawn("hunter", Vector3(58, -4.0, -38))
	# Tunnel echo bus over the whole underground
	var zone := InteriorZoneScript.new()
	zone.bus_name = "Tunnel"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(18, 4.6, 45)
	shape.shape = box
	zone.add_child(shape)
	zone.position = Vector3(58, -2.4, -21)
	add_child(zone)


## ----------------------------------------------------------------- helpers
func _house(pos: Vector3, c: Color) -> void:
	_box(Vector3(7, 2.8, 0.4), pos + Vector3(0, 1.4, -3), plaster_mat, c)
	_box(Vector3(0.4, 2.8, 6), pos + Vector3(-3.5, 1.4, 0), plaster_mat, c)
	_box(Vector3(0.4, 2.8, 6), pos + Vector3(3.5, 1.4, 0), plaster_mat, c)
	_box(Vector3(2.2, 2.8, 0.4), pos + Vector3(-2.4, 1.4, 3), plaster_mat, c)
	_box(Vector3(2.2, 2.8, 0.4), pos + Vector3(2.4, 1.4, 3), plaster_mat, c)
	_box(Vector3(2.6, 0.8, 0.4), pos + Vector3(0, 2.4, 3), plaster_mat, c)
	_box(Vector3(7.6, 0.4, 7), pos + Vector3(0, 3.0, 0), plaster_mat, c.darkened(0.25))
	_crate(pos + Vector3(1.5, 0.4, -1))


func _tree(pos: Vector3, h: float) -> void:
	var trunk := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.35
	cyl.height = h
	col.shape = cyl
	trunk.add_child(col)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.28
	cm.bottom_radius = 0.4
	cm.height = h
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.35, 0.26, 0.18)
	bark.roughness = 1.0
	cm.material = bark
	mi.mesh = cm
	trunk.add_child(mi)
	trunk.position = pos + Vector3(0, h * 0.5, 0)
	trunk.set_meta("surface", "wood")
	nav_parent.add_child(trunk)
	var leaves := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = h * 0.55
	sm.height = h * 0.9
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.3, 0.42, 0.22).lerp(Color(0.5, 0.45, 0.2), randf() * 0.5)
	leaf.roughness = 1.0
	sm.material = leaf
	leaves.mesh = sm
	leaves.position = pos + Vector3(0, h + h * 0.3, 0)
	add_child(leaves)


func _crate(pos: Vector3) -> void:
	var crate := LootCrateScript.new()
	crate.position = pos
	add_child(crate)


func _spawn(_kind: String, _pos: Vector3) -> void:
	pass  # v1.14.0: the city is zombie-free


func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D,
		tint := Color.WHITE, surface := "concrete") -> StaticBody3D:
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var use_mat := mat
	if tint != Color.WHITE:
		use_mat = mat.duplicate()
		use_mat.albedo_color = tint.lerp(Color(0.92, 0.84, 0.68), 0.22)
	mi.material_override = use_mat
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(mi)
	body.add_child(col)
	body.position = pos
	body.set_meta("surface", surface)
	nav_parent.add_child(body)
	return body
