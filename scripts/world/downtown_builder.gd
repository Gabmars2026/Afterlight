extends Node3D
## Phase 22: NEON DISTRICT. A downtown plinth east of town with a dozen
## glass towers (60-120 m), neon window strips, streetlights, an avenue
## leading in from the crosstown road, and a street-level bar.

const PropLib := preload("res://scripts/world/prop_lib.gd")

const TOWER_SPECS := [
	# [x, z, width, height, neon color]
	[-48, -34, 16, 74, Color(0.2, 0.9, 1.0)],
	[-20, -40, 18, 96, Color(1.0, 0.45, 0.75)],
	[12, -36, 15, 68, Color(0.6, 1.0, 0.4)],
	[40, -42, 20, 120, Color(0.3, 0.6, 1.0)],
	[52, -14, 14, 62, Color(1.0, 0.7, 0.25)],
	[-52, 16, 15, 82, Color(0.9, 0.4, 1.0)],
	[-26, 30, 17, 104, Color(0.25, 1.0, 0.8)],
	[6, 34, 14, 60, Color(1.0, 0.5, 0.3)],
	[34, 28, 18, 88, Color(0.4, 0.8, 1.0)],
	[54, 44, 15, 72, Color(1.0, 0.85, 0.3)],
	[-8, -14, 12, 64, Color(0.7, 0.9, 1.0)],
	[24, 12, 13, 66, Color(1.0, 0.35, 0.5)],
]

var _concrete: StandardMaterial3D
var _asphalt: StandardMaterial3D
var _glass_dark: StandardMaterial3D


func _ready() -> void:
	_concrete = StandardMaterial3D.new()
	_concrete.albedo_color = Color(0.52, 0.52, 0.55)
	_concrete.roughness = 0.95
	_asphalt = StandardMaterial3D.new()
	_asphalt.albedo_color = Color(0.2, 0.2, 0.22)
	_asphalt.roughness = 1.0
	_glass_dark = StandardMaterial3D.new()
	_glass_dark.albedo_color = Color(0.16, 0.2, 0.28)
	_glass_dark.roughness = 0.35
	_glass_dark.metallic = 0.6
	_build_plinth()
	_build_towers()
	_build_bar()


func _box(size: Vector3, pos: Vector3, mat: Material, tint := Color.WHITE,
		collide := true) -> void:
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
	add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		sb.add_child(cs)
		mi.add_child(sb)


func _neon(size: Vector3, pos: Vector3, color: Color, strength := 1.6) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = strength
	bm.material = m
	mi.mesh = bm
	mi.position = pos
	add_child(mi)


func _build_plinth() -> void:
	# Raised platform with skirt walls hiding the dune transition
	_box(Vector3(150, 2, 150), Vector3(0, 0, 0), _concrete)
	for side in [[-75.0, 0.0, 0.4, 150.0], [75.0, 0.0, 0.4, 150.0]]:
		_box(Vector3(side[2], 20, side[3]), Vector3(side[0], -10, side[1]),
				_concrete, Color(0.42, 0.42, 0.45))
	for side in [[0.0, -75.0, 150.0, 0.4], [0.0, 75.0, 150.0, 0.4]]:
		_box(Vector3(side[2], 20, side[3]), Vector3(side[0], -10, side[1]),
				_concrete, Color(0.42, 0.42, 0.45))
	# Avenue running east-west across the plinth, meeting the west steps
	_box(Vector3(150, 0.1, 9), Vector3(0, 1.05, 0), _asphalt, Color.WHITE, false)
	for i in 6:
		_box(Vector3(1.6, 0.12, 0.5), Vector3(-62.5 + i * 25.0, 1.06, 0),
				_asphalt, Color(0.85, 0.8, 0.3), false)
	# Approach road from the town gate + entry steps up the plinth
	_box(Vector3(66, 1.04, 6), Vector3(-108, -0.5, 0), _asphalt)
	for i in 4:
		_box(Vector3(2.4, 0.25, 6), Vector3(-76.2 + i * 1.2,
				0.16 + i * 0.25, 0), _concrete)
	# Streetlights along the avenue
	for i in 4:
		var lx := -45.0 + i * 30.0
		for lz in [-5.4, 5.4]:
			_box(Vector3(0.22, 4.6, 0.22), Vector3(lx, 3.3, lz), _asphalt,
					Color(0.3, 0.3, 0.32))
			_neon(Vector3(0.5, 0.14, 0.5), Vector3(lx, 5.65, lz),
					Color(1.0, 0.95, 0.8), 1.2)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.93, 0.75)
	lamp.light_energy = 0.9
	lamp.omni_range = 26.0
	lamp.position = Vector3(-15, 7, 0)
	add_child(lamp)


func _build_towers() -> void:
	var idx := 0
	for spec in TOWER_SPECS:
		_tower(idx, spec)
		idx += 1
	# Antenna on the tallest tower
	_box(Vector3(0.5, 16, 0.5), Vector3(40, 137, -42), _asphalt,
			Color(0.6, 0.2, 0.2))
	_neon(Vector3(0.9, 0.9, 0.9), Vector3(40, 145.5, -42),
			Color(1.0, 0.2, 0.2), 2.5)


func _tower(idx: int, spec: Array) -> void:
	## v1.15.0: every tower is enterable - a front door into a lit
	## lobby, then 20 floors linked by switchback ramps along the
	## back wall. Openings in each slab let the ramps pass through.
	var tx: float = spec[0]
	var tz: float = spec[1]
	var w: float = spec[2]
	var h: float = spec[3]
	var neon: Color = spec[4]
	var t := Node3D.new()
	t.name = "Tower%d" % idx
	t.position = Vector3(tx, 0, tz)
	add_child(t)
	var f := 1.0 if tz <= 0.0 else -1.0  # door faces the avenue
	var H := h + 6.0                     # shell: plinth top to roof
	var wi := w - 1.0                    # interior width
	# Shell: back, sides, front-with-door (3 wide x 3 high)
	_tbox(t, Vector3(w, H, 0.5), Vector3(0, 1 + H * 0.5, -f * (w * 0.5 - 0.25)),
			_glass_dark)
	for sx in [-1.0, 1.0]:
		_tbox(t, Vector3(0.5, H, w - 1), Vector3(sx * (w * 0.5 - 0.25),
				1 + H * 0.5, 0), _glass_dark)
	var pw := (w - 3.0) * 0.5
	for sx in [-1.0, 1.0]:
		_tbox(t, Vector3(pw, H, 0.5), Vector3(sx * (3.0 + pw) * 0.5,
				1 + H * 0.5, f * (w * 0.5 - 0.25)), _glass_dark)
	_tbox(t, Vector3(3.0, H - 3.0, 0.5), Vector3(0, 4 + (H - 3.0) * 0.5,
			f * (w * 0.5 - 0.25)), _glass_dark)
	# Roof cap
	_tbox(t, Vector3(w + 1.2, 2, w + 1.2), Vector3(0, 7 + h + 1, 0),
			_concrete, Color(0.35, 0.35, 0.4))
	# Neon sign over the door
	var sn := MeshInstance3D.new()
	var snm := BoxMesh.new()
	snm.size = Vector3(2.6, 0.4, 0.16)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = neon
	smat.emission_enabled = true
	smat.emission = neon
	smat.emission_energy_multiplier = 2.0
	snm.material = smat
	sn.mesh = snm
	sn.position = Vector3(0, 4.6, f * (w * 0.5 + 0.1))
	t.add_child(sn)
	# 20 floors + switchback ramps in a back stairwell strip
	var fs := (h - 2.0) / 19.0
	var strip := 3.2
	var dm := wi - strip                 # main slab depth
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.95, 0.93, 0.85)
	glow.emission_enabled = true
	glow.emission = Color(0.95, 0.93, 0.85)
	glow.emission_energy_multiplier = 1.1
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in range(1, 21):
		var y := 7.0 + (k - 1) * fs
		var d := 1.0 if (k - 1) % 2 == 0 else -1.0  # ramp below tops out here
		# Main slab (front part of the footprint)
		_tbox(t, Vector3(wi, 0.3, dm), Vector3(0, y - 0.15,
				f * (wi - dm) * 0.5), _concrete, Color(0.45, 0.45, 0.5))
		# Strip slab with a 4.5 m opening at the arrival end
		_tbox(t, Vector3(wi - 4.5, 0.3, strip), Vector3(-d * 2.25, y - 0.15,
				-f * (wi - strip) * 0.5), _concrete, Color(0.45, 0.45, 0.5))
		# Lit ceiling panel under this slab
		var cp := MeshInstance3D.new()
		var cpm := BoxMesh.new()
		cpm.size = Vector3(wi * 0.5, 0.06, wi * 0.4)
		cpm.material = glow
		cp.mesh = cpm
		cp.position = Vector3(0, y - 0.38, f * 1.2)
		t.add_child(cp)
	for k in 20:
		var y0 := 1.0 if k == 0 else 7.0 + (k - 1) * fs
		var y1 := 7.0 + k * fs
		var d := 1.0 if k % 2 == 0 else -1.0        # ascend toward d*X
		var run := w - 6.0
		var rise := y1 - y0
		var L := sqrt(run * run + rise * rise)
		_tbox(t, Vector3(L, 0.25, 3.0),
				Vector3(0, (y0 + y1) * 0.5 + 0.1, -f * (wi - strip) * 0.5),
				_concrete, Color(0.5, 0.5, 0.55), true, d * atan(rise / run))
	# Lobby light so the ground floor reads warm and safe
	var ll := OmniLight3D.new()
	ll.light_color = Color(1.0, 0.93, 0.78)
	ll.light_energy = 0.85
	ll.omni_range = 14.0
	ll.position = Vector3(0, 5.2, 0)
	t.add_child(ll)
	# Lobby furniture
	PropLib.place(t, "Table", Vector3(f * -2.0, 1.05, f * 2.0), 0.4, 1.0)
	PropLib.place(t, "Seat", Vector3(f * -3.2, 1.05, f * 2.6), 1.2, 1.0)
	PropLib.place(t, "Lamp", Vector3(-f * 3.0, 4.4, f * 3.0), 0.0, 1.0)


func _tbox(parent: Node3D, size: Vector3, pos: Vector3, mat: Material,
		tint := Color.WHITE, collide := true, rot_z := 0.0) -> void:
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
	mi.rotation.z = rot_z
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		sb.add_child(cs)
		mi.add_child(sb)


func _build_bar() -> void:
	# THE LAST CALL - street-level bar north of the avenue
	var bx := -30.0
	var bz := 12.0
	var floor_y := 1.0
	var wall := Color(0.3, 0.24, 0.2)
	_box(Vector3(16, 0.8, 12), Vector3(bx, floor_y - 0.2, bz + 5),
			_concrete, Color(0.32, 0.26, 0.22))
	# Walls with a south-facing door gap
	_box(Vector3(16, 4, 0.4), Vector3(bx, floor_y + 2, bz + 11), _concrete, wall)
	_box(Vector3(0.4, 4, 12), Vector3(bx - 8, floor_y + 2, bz + 5), _concrete, wall)
	_box(Vector3(0.4, 4, 12), Vector3(bx + 8, floor_y + 2, bz + 5), _concrete, wall)
	_box(Vector3(6.2, 4, 0.4), Vector3(bx - 4.9, floor_y + 2, bz - 1), _concrete, wall)
	_box(Vector3(6.2, 4, 0.4), Vector3(bx + 4.9, floor_y + 2, bz - 1), _concrete, wall)
	_box(Vector3(3.6, 1.2, 0.4), Vector3(bx, floor_y + 3.4, bz - 1), _concrete, wall)
	_box(Vector3(16.8, 0.4, 12.8), Vector3(bx, floor_y + 4.2, bz + 5),
			_concrete, Color(0.22, 0.18, 0.15))
	# Neon sign over the door
	_neon(Vector3(5.0, 0.8, 0.3), Vector3(bx, floor_y + 4.9, bz - 1.1),
			Color(1.0, 0.3, 0.55), 2.2)
	# Counter: two prop tables end to end, barrels + shelf behind
	PropLib.place(self, "Table", Vector3(bx - 1.6, floor_y + 0.2, bz + 7.4), 0.0, 0.8)
	PropLib.place(self, "Table", Vector3(bx + 1.6, floor_y + 0.2, bz + 7.4), 0.0, 0.8)
	PropLib.place(self, "Chope_A", Vector3(bx - 1.9, floor_y + 1.05, bz + 7.3), 0.6, 0.5)
	PropLib.place(self, "Chope_B", Vector3(bx + 0.4, floor_y + 1.05, bz + 7.5), 2.4, 0.5)
	PropLib.place(self, "Cup", Vector3(bx + 2.2, floor_y + 1.05, bz + 7.2), 1.1, 0.6)
	for i in 3:
		PropLib.place(self, "Barril", Vector3(bx - 5.5 + i * 1.6,
				floor_y + 0.2, bz + 10.0), 0.4 * i, 0.9)
	# Bar stools facing the counter
	for i in 4:
		PropLib.place(self, "Seat", Vector3(bx - 3.4 + i * 2.2,
				floor_y + 0.2, bz + 5.6), PI, 0.75)
	# Corner table for patrons
	PropLib.place(self, "Table", Vector3(bx + 5.4, floor_y + 0.2, bz + 2.4), 0.4, 0.7)
	PropLib.place(self, "Chair", Vector3(bx + 4.2, floor_y + 0.2, bz + 1.8), 1.9, 0.9)
	PropLib.place(self, "Seat", Vector3(bx + 6.4, floor_y + 0.2, bz + 3.2), -1.2, 0.75)
	# Hanging lantern + warm light
	PropLib.place(self, "Lamp", Vector3(bx, floor_y + 4.2, bz + 6), 0.0, 1.0, false)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.72, 0.42)
	glow.light_energy = 1.5
	glow.omni_range = 11.0
	glow.position = Vector3(bx, floor_y + 3.4, bz + 5)
	glow.name = "BarLight"
	add_child(glow)
