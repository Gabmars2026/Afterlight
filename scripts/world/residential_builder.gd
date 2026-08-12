extends Node3D
## v1.20.0: SUNSET FLATS. Four compact residential blocks sit on a raised
## mesa north of the NEON DISTRICT. Every block contains exactly 20 homes:
## eight enterable furnished houses plus twelve detailed Kenney suburban
## homes. Wide streets separate the blocks and remain clear for vehicles.

const PropLib := preload("res://scripts/world/prop_lib.gd")

# Kenney City Kit (Suburban) 2.0. Entries retain the source dimensions so
# each model can use a dependable low-cost box collider. A six-times world
# scale keeps even the widest house below the 13 m lot spacing.
const HOUSE_ASSETS := [
	[preload("res://assets/city_kenney_suburban/building-type-a.glb"), Vector3(1.3000, 0.8335, 1.0281)],
	[preload("res://assets/city_kenney_suburban/building-type-b.glb"), Vector3(1.8280, 1.1375, 1.1400)],
	[preload("res://assets/city_kenney_suburban/building-type-c.glb"), Vector3(1.2864, 1.0335, 1.0281)],
	[preload("res://assets/city_kenney_suburban/building-type-d.glb"), Vector3(1.7564, 1.2375, 1.0280)],
	[preload("res://assets/city_kenney_suburban/building-type-e.glb"), Vector3(1.3000, 1.1375, 1.0280)],
	[preload("res://assets/city_kenney_suburban/building-type-f.glb"), Vector3(1.4280, 1.1375, 1.4059)],
	[preload("res://assets/city_kenney_suburban/building-type-g.glb"), Vector3(1.4500, 0.7682, 1.1780)],
	[preload("res://assets/city_kenney_suburban/building-type-h.glb"), Vector3(1.3000, 0.7375, 0.9160)],
	[preload("res://assets/city_kenney_suburban/building-type-i.glb"), Vector3(1.2864, 0.7375, 1.0280)],
	[preload("res://assets/city_kenney_suburban/building-type-j.glb"), Vector3(1.3700, 1.0375, 0.9160)],
	[preload("res://assets/city_kenney_suburban/building-type-k.glb"), Vector3(0.9209, 1.1496, 1.0200)],
	[preload("res://assets/city_kenney_suburban/building-type-l.glb"), Vector3(1.0336, 1.0492, 1.0200)],
	[preload("res://assets/city_kenney_suburban/building-type-m.glb"), Vector3(1.4280, 0.7375, 1.4280)],
	[preload("res://assets/city_kenney_suburban/building-type-n.glb"), Vector3(1.7843, 1.1375, 1.3779)],
	[preload("res://assets/city_kenney_suburban/building-type-o.glb"), Vector3(1.2700, 1.1375, 1.0280)],
	[preload("res://assets/city_kenney_suburban/building-type-p.glb"), Vector3(1.2400, 0.9180, 0.9900)],
	[preload("res://assets/city_kenney_suburban/building-type-q.glb"), Vector3(1.2400, 0.9180, 0.8856)],
	[preload("res://assets/city_kenney_suburban/building-type-r.glb"), Vector3(1.0280, 1.1411, 1.0200)],
	[preload("res://assets/city_kenney_suburban/building-type-s.glb"), Vector3(1.4060, 1.1375, 1.0864)],
	[preload("res://assets/city_kenney_suburban/building-type-t.glb"), Vector3(1.3136, 1.1563, 1.4064)],
	[preload("res://assets/city_kenney_suburban/building-type-u.glb"), Vector3(1.4280, 1.1375, 1.0869)],
]

const HOUSE_SCALE := 6.0
const BLOCK_CENTERS := [
	Vector2(-40.0, -30.0), Vector2(40.0, -30.0),
	Vector2(-40.0, 30.0), Vector2(40.0, 30.0),
]
const LOT_X := [-26.0, -13.0, 0.0, 13.0, 26.0]
const LOT_Z := [-18.0, -6.0, 6.0, 18.0]
const ENTERABLE_SLOTS := [0, 2, 4, 5, 14, 15, 17, 19]

const PALETTE := [
	Color(0.85, 0.72, 0.55), Color(0.78, 0.55, 0.45),
	Color(0.62, 0.68, 0.72), Color(0.82, 0.78, 0.66),
	Color(0.68, 0.58, 0.66), Color(0.58, 0.66, 0.55),
]

var _concrete: StandardMaterial3D
var _asphalt: StandardMaterial3D
var _wall: StandardMaterial3D
var _glow: StandardMaterial3D


func _ready() -> void:
	_concrete = StandardMaterial3D.new()
	_concrete.albedo_color = Color(0.56, 0.54, 0.5)
	_concrete.roughness = 0.95
	_asphalt = StandardMaterial3D.new()
	_asphalt.albedo_color = Color(0.21, 0.21, 0.23)
	_asphalt.roughness = 1.0
	_wall = StandardMaterial3D.new()
	_wall.albedo_color = Color.WHITE
	_wall.roughness = 0.9
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = Color(1.0, 0.9, 0.7)
	_glow.emission_enabled = true
	_glow.emission = Color(1.0, 0.9, 0.7)
	_glow.emission_energy_multiplier = 1.1
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_build_plinth()
	_build_streets()
	_build_residential_blocks()


func _box(size: Vector3, pos: Vector3, mat: Material, tint := Color.WHITE,
		collide := true, parent: Node3D = null, rot_x := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	if tint == Color.WHITE:
		bm.material = mat
	else:
		var m2: StandardMaterial3D = mat.duplicate()
		m2.albedo_color = tint
		bm.material = m2
	mi.mesh = bm
	mi.position = pos
	mi.rotation.x = rot_x
	if parent == null:
		parent = self
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		sb.add_child(cs)
		mi.add_child(sb)


func _build_plinth() -> void:
	# Raised platform (top at y=1) with skirts down into the dunes
	_box(Vector3(160, 2, 120), Vector3(0, 0, 0), _concrete)
	for side in [[-80.0, 0.0, 0.4, 120.0], [80.0, 0.0, 0.4, 120.0]]:
		_box(Vector3(side[2], 20, side[3]), Vector3(side[0], -10, side[1]),
				_concrete, Color(0.45, 0.44, 0.42))
	for side in [[0.0, -60.0, 160.0, 0.4], [0.0, 60.0, 160.0, 0.4]]:
		_box(Vector3(side[2], 20, side[3]), Vector3(side[0], -10, side[1]),
				_concrete, Color(0.45, 0.44, 0.42))
	# Continuous bridge-ramp from the enlarged mesa onto the downtown plinth.
	# The landing is well inside both slabs so wheel colliders never meet a gap.
	var ramp_length := 27.0
	var ramp_start := 60.0
	var ramp_angle := atan(8.6 / ramp_length)
	_box(Vector3(10, 0.5, ramp_length), Vector3(0, -3.3,
			ramp_start + ramp_length * 0.5), _asphalt, Color.WHITE, true, null,
			ramp_angle)
	for gz in [62.0, 68.0, 74.0, 80.0, 86.0]:
		var surface_y: float = 1.0 - (float(gz) - ramp_start) * 8.6 / ramp_length
		for gx in [-4.4, 4.4]:
			_box(Vector3(0.35, 1.0, 0.35),
					Vector3(gx, surface_y + 0.5, gz),
					_concrete, Color(0.45, 0.44, 0.42))


func _build_streets() -> void:
	# Two broad roads split the mesa into four distinct residential blocks.
	_box(Vector3(150, 0.1, 10), Vector3(0, 1.05, 0), _asphalt, Color.WHITE,
			false)
	_box(Vector3(10, 0.1, 114), Vector3(0, 1.05, 0), _asphalt, Color.WHITE,
			false)
	# A perimeter loop plus one narrow access lane through each packed block.
	for lz in [-56.5, 56.5]:
		_box(Vector3(150, 0.1, 5), Vector3(0, 1.05, lz), _asphalt,
				Color(0.24, 0.24, 0.26), false)
	for lx in [-76.5, 76.5]:
		_box(Vector3(5, 0.1, 108), Vector3(lx, 1.05, 0), _asphalt,
				Color(0.24, 0.24, 0.26), false)
	for block_z in [-30.0, 30.0]:
		for block_x in [-40.0, 40.0]:
			_box(Vector3(66, 0.08, 2.8), Vector3(block_x, 1.055, block_z),
					_asphalt, Color(0.29, 0.29, 0.31), false)
	# Lane markings on the main street
	for i in 9:
		_box(Vector3(1.6, 0.12, 0.4), Vector3(-64.0 + i * 16.0, 1.06, 0),
				_asphalt, Color(0.85, 0.8, 0.3), false)
	# Streetlights at the corners of the main crossing
	for lx in [-30.0, 30.0]:
		for lz in [-5.6, 5.6]:
			_box(Vector3(0.2, 4.4, 0.2), Vector3(lx, 3.2, lz), _asphalt,
					Color(0.3, 0.3, 0.32))
			_box(Vector3(0.5, 0.14, 0.5), Vector3(lx, 5.4, lz), _glow,
					Color.WHITE, false)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.93, 0.75)
	lamp.light_energy = 0.85
	lamp.omni_range = 30.0
	lamp.position = Vector3(0, 7, 0)
	add_child(lamp)


func _build_residential_blocks() -> void:
	var global_house_idx := 0
	var asset_idx := 0
	for block_idx in BLOCK_CENTERS.size():
		var center: Vector2 = BLOCK_CENTERS[block_idx]
		var block := Node3D.new()
		block.name = "ResidentialBlock_%02d" % (block_idx + 1)
		block.position = Vector3(center.x, 0.0, center.y)
		block.add_to_group("residential_block")
		add_child(block)
		var facing := 1.0 if center.y < 0.0 else -1.0
		var lot_idx := 0
		for local_z in LOT_Z:
			for local_x in LOT_X:
				var lot_pos := Vector3(local_x, 0.0, local_z)
				if lot_idx in ENTERABLE_SLOTS:
					_house(block, global_house_idx, lot_pos, facing)
				else:
					_asset_house(block, global_house_idx, asset_idx, lot_pos,
							facing)
					asset_idx += 1
				global_house_idx += 1
				lot_idx += 1


func _asset_house(block: Node3D, house_idx: int, asset_idx: int,
		pos: Vector3, facing: float) -> void:
	var spec: Array = HOUSE_ASSETS[asset_idx % HOUSE_ASSETS.size()]
	var packed: PackedScene = spec[0]
	var source_size: Vector3 = spec[1]
	var house := Node3D.new()
	house.name = "House%02d" % house_idx
	house.position = pos + Vector3(0, 1.1, 0)
	house.rotation.y = 0.0 if facing > 0.0 else PI
	house.add_to_group("residential_house")
	house.add_to_group("suburban_asset_house")
	block.add_child(house)
	var model := packed.instantiate()
	model.scale = Vector3.ONE * HOUSE_SCALE
	house.add_child(model)
	var body := StaticBody3D.new()
	body.name = "HouseCollision"
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(source_size.x * HOUSE_SCALE * 0.9,
			source_size.y * HOUSE_SCALE, source_size.z * HOUSE_SCALE * 0.88)
	cs.shape = shape
	cs.position.y = source_size.y * HOUSE_SCALE * 0.5
	body.add_child(cs)
	house.add_child(body)


func _house(block: Node3D, idx: int, pos: Vector3, f: float) -> void:
	var h := Node3D.new()
	h.name = "House%02d" % idx
	h.position = pos
	h.add_to_group("residential_house")
	h.add_to_group("enterable_house")
	block.add_child(h)
	var tint: Color = PALETTE[idx % PALETTE.size()]
	var roof_tint := Color(0.32, 0.26, 0.24)
	# Floor slab
	_box(Vector3(9, 0.3, 8), Vector3(0, 1.15, 0), _concrete,
			Color(0.5, 0.42, 0.36), true, h)
	# Back wall + side walls (3 m tall, on the slab at y 1.3)
	_box(Vector3(9, 3, 0.35), Vector3(0, 2.8, -f * 3.82), _wall, tint, true, h)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.35, 3, 8), Vector3(sx * 4.32, 2.8, 0), _wall, tint,
				true, h)
	# Front wall: two panels + lintel around a 1.6 x 2.4 door
	for sx in [-1.0, 1.0]:
		_box(Vector3(3.7, 3, 0.35), Vector3(sx * 2.65, 2.8, f * 3.82), _wall,
				tint, true, h)
	_box(Vector3(1.6, 0.6, 0.35), Vector3(0, 4.0, f * 3.82), _wall, tint,
			true, h)
	# Warm window on each front panel (visual)
	for sx in [-1.0, 1.0]:
		_box(Vector3(1.4, 1.1, 0.1), Vector3(sx * 2.65, 2.9, f * 4.05),
				_glow, Color.WHITE, false, h)
	# Flat roof with a small overhang
	_box(Vector3(9.8, 0.3, 8.8), Vector3(0, 4.45, 0), _concrete, roof_tint,
			true, h)
	# Lit ceiling panel + furniture inside
	_box(Vector3(4.5, 0.06, 3.5), Vector3(0, 4.1, 0), _glow, Color.WHITE,
			false, h)
	PropLib.place(h, "Table", Vector3(-1.6, 1.35, -f * 1.2), 0.3, 0.9)
	PropLib.place(h, "Seat", Vector3(-2.6, 1.35, -f * 0.2), 1.1, 0.9)
	if idx % 3 == 0:
		PropLib.place(h, "Barril", Vector3(2.8, 1.35, -f * 2.2), 0.0, 0.9)
	if idx % 4 == 0:
		PropLib.place(h, "Panel", Vector3(3.2, 1.35, f * 2.0), -f * 0.4, 0.9)


func block_house_counts() -> Array[int]:
	var counts: Array[int] = []
	for child in get_children():
		if not child.is_in_group("residential_block"):
			continue
		var count := 0
		for lot in child.get_children():
			if lot.is_in_group("residential_house"):
				count += 1
		counts.append(count)
	return counts


func driving_grid_clear() -> bool:
	## Every house leaves enough room for its widest possible footprint beside
	## the two central vehicle roads and the outer loop.
	for house in get_tree().get_nodes_in_group("residential_house"):
		if not is_ancestor_of(house):
			continue
		var p := to_local(house.global_position)
		if absf(p.x) <= 11.0 or absf(p.z) <= 11.0:
			return false
		if absf(p.x) + 6.0 >= 74.0 or absf(p.z) + 5.0 >= 54.0:
			return false
	return true
