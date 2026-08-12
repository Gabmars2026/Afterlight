extends Node3D
## v1.16.0: SUNSET FLATS. A residential district on a raised plinth
## north of the NEON DISTRICT: a main street, side lanes, a connector
## down to downtown, and 32 small enterable houses - each with a door,
## a lit room, and furniture. Palette varies house to house. The whole
## district rides a mesa plinth 8.6 m above downtown, clear of the dunes.

const PropLib := preload("res://scripts/world/prop_lib.gd")

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
	_build_houses()


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
	_box(Vector3(140, 2, 80), Vector3(0, 0, 0), _concrete)
	for side in [[-70.0, 0.0, 0.4, 80.0], [70.0, 0.0, 0.4, 80.0]]:
		_box(Vector3(side[2], 20, side[3]), Vector3(side[0], -10, side[1]),
				_concrete, Color(0.45, 0.44, 0.42))
	for side in [[0.0, -40.0, 140.0, 0.4], [0.0, 40.0, 140.0, 0.4]]:
		_box(Vector3(side[2], 20, side[3]), Vector3(side[0], -10, side[1]),
				_concrete, Color(0.45, 0.44, 0.42))
	# Ramp road down to the NEON DISTRICT plinth (the district sits on
	# a mesa above the dunes; downtown's plinth top is 8.6 m lower)
	_box(Vector3(8, 0.5, 26.6), Vector3(0, -4.15, 52.5), _asphalt,
			Color.WHITE, true, null, 0.331)
	for gz in [41.5, 47.0, 52.5, 58.0, 63.5]:
		for gx in [-4.4, 4.4]:
			_box(Vector3(0.35, 1.0, 0.35),
					Vector3(gx, -3.9 - (gz - 41.5) * 0.344, gz),
					_concrete, Color(0.45, 0.44, 0.42))


func _build_streets() -> void:
	# Main street east-west, cross street north-south
	_box(Vector3(130, 0.1, 8), Vector3(0, 1.05, 0), _asphalt, Color.WHITE,
			false)
	_box(Vector3(8, 0.1, 76), Vector3(0, 1.05, 0), _asphalt, Color.WHITE,
			false)
	# Side lanes serving the outer rows
	for lz in [-22.0, 22.0]:
		_box(Vector3(130, 0.1, 5), Vector3(0, 1.05, lz), _asphalt,
				Color(0.24, 0.24, 0.26), false)
	# Lane markings on the main street
	for i in 8:
		_box(Vector3(1.6, 0.12, 0.4), Vector3(-56.0 + i * 16.0, 1.06, 0),
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


func _build_houses() -> void:
	var idx := 0
	# Rows face the main street (z=+-13) and the side lanes (z=+-31)
	for rz in [-13.0, 13.0, -31.0, 31.0]:
		var f := 1.0 if rz < 0.0 else -1.0  # door faces the street
		for hx in [-60.0, -44.0, -28.0, -12.0, 12.0, 28.0, 44.0, 60.0]:
			_house(idx, Vector3(hx, 0, rz), f)
			idx += 1


func _house(idx: int, pos: Vector3, f: float) -> void:
	var h := Node3D.new()
	h.name = "House%d" % idx
	h.position = pos
	add_child(h)
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
