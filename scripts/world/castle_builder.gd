extends Node3D
## Phase 19: the medieval castle north of town. A 30-floor stone keep
## (2 rooms per floor plus the great hall and throne room - 50+ rooms),
## a walled courtyard on a raised plinth, and an underground dungeon
## with cells and fire-breathing dragons. Position this node at the
## castle center; everything is built in local coordinates.

const PropLib := preload("res://scripts/world/prop_lib.gd")
const LootCrateScript := preload("res://scripts/world/loot_crate.gd")
const DragonScript := preload("res://scripts/ai/dragon.gd")

const TOP := 6.0          # plinth top (courtyard level)
const FLOOR_H := 3.2      # keep storey height
const FLOORS := 30
const KEEP := 20.0        # keep footprint
const WALL_T := 0.8

var _stone := StandardMaterial3D.new()
var _dark := StandardMaterial3D.new()
var _wood := StandardMaterial3D.new()


func _ready() -> void:
	_stone.albedo_color = Color(0.56, 0.54, 0.5)
	_stone.roughness = 0.95
	_dark.albedo_color = Color(0.36, 0.34, 0.32)
	_dark.roughness = 1.0
	_wood.albedo_color = Color(0.45, 0.32, 0.18)
	_wood.roughness = 0.9
	_build_plinth()
	_build_curtain()
	_build_keep()
	_build_dungeon()


func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D,
		surface := "concrete") -> StaticBody3D:
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(mi)
	body.add_child(col)
	body.position = pos
	body.set_meta("surface", surface)
	add_child(body)
	return body


func _crate(pos: Vector3) -> void:
	var crate := LootCrateScript.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.8, 0.9)
	bm.material = _wood
	mi.mesh = bm
	mi.position.y = 0.4
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 0.8, 0.9)
	col.shape = shape
	col.position.y = 0.4
	crate.add_child(mi)
	crate.add_child(col)
	crate.position = pos
	crate.set_meta("surface", "wood")
	add_child(crate)


func _torch(pos: Vector3) -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.72, 0.4)
	lamp.light_energy = 1.5
	lamp.omni_range = 9.0
	lamp.position = pos
	add_child(lamp)


func _build_plinth() -> void:
	## Raised stone platform the castle sits on. The top slab has a hole
	## in the courtyard's north-east for the dungeon stairs; the hollow
	## space inside the skirt walls IS the dungeon.
	# Skirt walls down into the dunes
	for side in [-1.0, 1.0]:
		_box(Vector3(56, 28, 2), Vector3(0, TOP - 14.5, side * 27.0), _dark)
		_box(Vector3(2, 28, 52), Vector3(side * 27.0, TOP - 14.5, 0), _dark)
	# Top slab, pieces leaving a 3x6 stair hole at x 14..17, z -14..-8
	_box(Vector3(56, 1, 35), Vector3(0, TOP - 0.5, 10.5), _stone)
	_box(Vector3(56, 1, 6), Vector3(0, TOP - 0.5, -25), _stone)
	_box(Vector3(42, 1, 14), Vector3(-7, TOP - 0.5, -15), _stone)
	_box(Vector3(14, 1, 8), Vector3(21, TOP - 0.5, -18), _stone)
	_box(Vector3(11, 1, 6), Vector3(22.5, TOP - 0.5, -11), _stone)
	_box(Vector3(3, 1, 1), Vector3(15.5, TOP - 0.5, -7.5), _stone)
	# Grand steps up the south face (buried at the bottom, walkable)
	for i in 26:
		var top_y := TOP - 0.5 * i
		var h := top_y + 16.0
		_box(Vector3(12, h, 1.5),
				Vector3(0, top_y - h * 0.5, 28.75 + i * 1.5), _stone)


func _build_curtain() -> void:
	## Courtyard walls on the plinth with a south gate and corner towers.
	var wall_h := 7.0
	var y := TOP + wall_h * 0.5
	# North wall, full; south wall with 6 m gate gap
	_box(Vector3(40, wall_h, 1.2), Vector3(0, y, -20), _stone)
	_box(Vector3(17, wall_h, 1.2), Vector3(-11.5, y, 20), _stone)
	_box(Vector3(17, wall_h, 1.2), Vector3(11.5, y, 20), _stone)
	_box(Vector3(12, 2.0, 1.2), Vector3(0, TOP + 6.0, 20), _stone)
	# East / west walls
	_box(Vector3(1.2, wall_h, 40), Vector3(-20, y, 0), _stone)
	_box(Vector3(1.2, wall_h, 40), Vector3(20, y, 0), _stone)
	# Corner towers
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(5, 13, 5), Vector3(sx * 20, TOP + 6.5, sz * 20), _dark)
	# Courtyard torches by the gate
	_torch(Vector3(-4, TOP + 3.0, 18))
	_torch(Vector3(4, TOP + 3.0, 18))


func _build_keep() -> void:
	## The 30-storey keep. Ground level is a double-height great hall;
	## floors 2-28 hold two rooms each; floor 29 is the throne room.
	## Stairs alternate north/south walls exactly like the apartment.
	var half := KEEP * 0.5
	var inner := half - WALL_T * 0.5

	# --- Great hall (floors 0-1, height 2 * FLOOR_H) ---
	var hall_h := FLOOR_H * 2.0
	# South wall with door gap (3 wide, 3.5 high)
	_box(Vector3(8.5, hall_h, WALL_T), Vector3(-5.75, TOP + hall_h / 2, half), _stone)
	_box(Vector3(8.5, hall_h, WALL_T), Vector3(5.75, TOP + hall_h / 2, half), _stone)
	_box(Vector3(3, hall_h - 3.5, WALL_T),
			Vector3(0, TOP + 3.5 + (hall_h - 3.5) / 2, half), _stone)
	# North wall solid, east/west with slits
	_box(Vector3(KEEP, hall_h, WALL_T), Vector3(0, TOP + hall_h / 2, -half), _stone)
	for side in [-1.0, 1.0]:
		_box(Vector3(WALL_T, hall_h, 9.2), Vector3(side * half, TOP + hall_h / 2, -5.0), _stone)
		_box(Vector3(WALL_T, hall_h, 9.2), Vector3(side * half, TOP + hall_h / 2, 5.0), _stone)
		_box(Vector3(WALL_T, 1.2, 1.6), Vector3(side * half, TOP + hall_h - 0.6, 0.0), _stone)
	# Hall furnishing: long feast table, seats, barrels, trophy wall
	PropLib.place(self, "Table", Vector3(0, TOP, -2), 0.0, 0.8)
	PropLib.place(self, "Table", Vector3(0, TOP, 1.2), 0.0, 0.8)
	for cx in [-1.6, 1.6]:
		PropLib.place(self, "Chair", Vector3(cx, TOP, -2), PI / 2 if cx > 0 else -PI / 2, 1.0)
		PropLib.place(self, "Seat", Vector3(cx, TOP, 1.2), PI / 2 if cx > 0 else -PI / 2, 1.0)
	PropLib.place(self, "Chope_A", Vector3(0.3, TOP + 1.12, -2.2), 0.4, 0.5, false)
	PropLib.place(self, "Chope_B", Vector3(-0.4, TOP + 1.12, 1.0), 1.2, 0.5, false)
	PropLib.place(self, "Barril", Vector3(-8.5, TOP, -8.5), 0.3)
	PropLib.place(self, "Barril", Vector3(-7.2, TOP, -8.7), 1.1)
	PropLib.place(self, "Shield", Vector3(0, TOP + 3.4, -half + 0.55), 0.0, 1.0, false, PI / 2)
	PropLib.place(self, "Sword", Vector3(-1.6, TOP + 3.2, -half + 0.5), 0.0, 1.0, false)
	PropLib.place(self, "Battle_Axe", Vector3(1.6, TOP + 3.2, -half + 0.5), 0.0, 1.0, false)
	PropLib.place(self, "Lamp", Vector3(0, TOP + hall_h - 0.1, 0), 0.0, 1.0, false)
	_torch(Vector3(0, TOP + 4.5, 0))
	_crate(Vector3(8.3, TOP, -8.3))
	_crate(Vector3(7.1, TOP, -8.5))

	# --- Floors 2..29 ---
	for f in range(2, FLOORS):
		var base := TOP + f * FLOOR_H          # slab top of this floor
		var slab_y := base - 0.15
		var stairs_north := f % 2 == 0          # stairs BELOW run along...
		# Slab with stair opening over the incoming flight
		if stairs_north:
			# hole strip along north edge, east half
			_box(Vector3(KEEP, 0.3, KEEP - 2.6), Vector3(0, slab_y, 1.3), _stone)
			_box(Vector3(9.4, 0.3, 2.6), Vector3(-5.3, slab_y, -half + 1.3), _stone)
		else:
			_box(Vector3(KEEP, 0.3, KEEP - 2.6), Vector3(0, slab_y, -1.3), _stone)
			_box(Vector3(9.4, 0.3, 2.6), Vector3(5.3, slab_y, half - 1.3), _stone)
		if f == FLOORS - 1:
			_throne_room(base)
		else:
			_storey_walls(base, f)
		# Stair flight UP from this floor (10 steps, rise 0.32)
		if f < FLOORS - 1:
			var up_north := (f + 1) % 2 == 0
			for i in 10:
				var sx := -4.05 + i * 0.9 if up_north else 4.05 - i * 0.9
				var sz := -inner + 1.0 if up_north else inner - 1.0
				_box(Vector3(0.9, 0.32 * (i + 1), 2.0),
						Vector3(sx, base + 0.16 * (i + 1), sz), _dark)
		if f % 7 == 0:
			_torch(Vector3(0, base + 2.4, 0))
		if f % 5 == 0 and f < FLOORS - 1:
			_crate(Vector3(6.0 if f % 2 == 0 else -6.0, base, 3.0))

	# --- Ground-to-floor-2 stairs (long flight through the hall) ---
	for i in 20:
		_box(Vector3(0.9, 0.32 * (i + 1), 2.0),
				Vector3(-8.55 + i * 0.9, TOP + 0.16 * (i + 1), -inner + 1.0), _dark)

	# --- Roof: battlements at the top ---
	var roof := TOP + FLOORS * FLOOR_H
	_box(Vector3(KEEP, 0.3, KEEP - 2.6), Vector3(0, roof - 0.15, 1.3), _stone)
	_box(Vector3(9.4, 0.3, 2.6), Vector3(-5.3, roof - 0.15, -half + 1.3), _stone)
	for side in [-1.0, 1.0]:
		_box(Vector3(KEEP, 1.4, 0.5), Vector3(0, roof + 0.7, side * (half - 0.25)), _stone)
		_box(Vector3(0.5, 1.4, KEEP), Vector3(side * (half - 0.25), roof + 0.7, 0), _stone)
	_crate(Vector3(0, roof, 5.0))


func _storey_walls(base: float, f: int) -> void:
	## One keep storey: perimeter walls with arrow slits east/west and a
	## divider wall that splits the floor into two rooms.
	var half := KEEP * 0.5
	var h := FLOOR_H - 0.3
	var y := base + h * 0.5
	_box(Vector3(KEEP, h, WALL_T), Vector3(0, y, -half), _stone)
	_box(Vector3(KEEP, h, WALL_T), Vector3(0, y, half), _stone)
	for side in [-1.0, 1.0]:
		_box(Vector3(WALL_T, h, 9.2), Vector3(side * half, y, -5.0), _stone)
		_box(Vector3(WALL_T, h, 9.2), Vector3(side * half, y, 5.0), _stone)
		_box(Vector3(WALL_T, 0.8, 1.6), Vector3(side * half, base + h - 0.4, 0.0), _stone)
	# Divider along x with a door gap offset per floor
	var gap_x := 4.0 if f % 2 == 0 else -4.0
	var left_w := gap_x - 1.1 + half - WALL_T * 0.5
	var right_w := half - WALL_T * 0.5 - gap_x - 1.1
	if left_w > 0.2:
		_box(Vector3(left_w, h, 0.5),
				Vector3(-half + WALL_T * 0.5 + left_w * 0.5, y, 0), _stone)
	if right_w > 0.2:
		_box(Vector3(right_w, h, 0.5),
				Vector3(half - WALL_T * 0.5 - right_w * 0.5, y, 0), _stone)
	if f % 4 == 0:
		PropLib.place(self, "Barril", Vector3(gap_x * -1.5, base, -6.0), f * 0.7)
	elif f % 4 == 1:
		PropLib.place(self, "Chair", Vector3(gap_x * -1.2, base, 5.5), f * 1.1)
	elif f % 4 == 2:
		PropLib.place(self, "Wood_Trunk", Vector3(gap_x * -1.4, base, -5.5), f * 0.9)


func _throne_room(base: float) -> void:
	## Top floor: one open room with a dais and throne.
	var half := KEEP * 0.5
	var h := FLOOR_H - 0.3
	var y := base + h * 0.5
	_box(Vector3(KEEP, h, WALL_T), Vector3(0, y, -half), _stone)
	_box(Vector3(KEEP, h, WALL_T), Vector3(0, y, half), _stone)
	for side in [-1.0, 1.0]:
		_box(Vector3(WALL_T, h, 9.2), Vector3(side * half, y, -5.0), _stone)
		_box(Vector3(WALL_T, h, 9.2), Vector3(side * half, y, 5.0), _stone)
	_box(Vector3(5, 0.4, 4), Vector3(0, base + 0.2, -6.5), _dark)
	PropLib.place(self, "Chair", Vector3(0, base + 0.4, -7.0), PI)
	PropLib.place(self, "Shield", Vector3(-3.0, base + 2.2, -half + 0.55), 0.0, 1.0, false, PI / 2)
	PropLib.place(self, "Shield", Vector3(3.0, base + 2.2, -half + 0.55), 0.0, 1.0, false, PI / 2)
	PropLib.place(self, "Sword", Vector3(0, base + 2.2, -half + 0.5), 0.0, 1.0, false)
	_torch(Vector3(0, base + 2.5, -4))
	_crate(Vector3(-6.5, base, 6.5))
	_crate(Vector3(-5.3, base, 6.7))
	_crate(Vector3(-6.3, base, 5.3))


func _build_dungeon() -> void:
	## Under the courtyard: a torchlit chamber with prison cells and two
	## fire-breathing dragons. Reached by the stairs in the courtyard's
	## north-east corner (hole in the plinth top at x 14..17, z -14..-8).
	var floor_y := -6.0
	_box(Vector3(52, 1, 52), Vector3(0, floor_y - 0.5, 0), _dark)
	# Ceiling below the courtyard slab, with a cutout over the stair
	# switchback shaft (x 11..18, z -24..-8)
	_box(Vector3(52, 0.5, 34), Vector3(0, 0.75, 9), _dark)
	_box(Vector3(52, 0.5, 2), Vector3(0, 0.75, -25), _dark)
	_box(Vector3(37, 0.5, 16), Vector3(-7.5, 0.75, -16), _dark)
	_box(Vector3(8, 0.5, 16), Vector3(22, 0.75, -16), _dark)
	# Switchback stairs: flight 1 north along x 15.5 (TOP down to y 0),
	# landing, then flight 2 back south along x 12.5 (0 down to floor)
	for i in 15:
		var top_y := TOP - 0.4 * (i + 1)
		var h := top_y - floor_y + 0.4
		_box(Vector3(3, h, 0.8),
				Vector3(15.5, top_y - h * 0.5, -8.4 - i * 0.8), _dark)
	_box(Vector3(7, 6.4, 3), Vector3(14.5, floor_y + 6.4 * 0.5 - 0.2, -21.9), _dark)
	for i in 15:
		var top_y := -0.2 - 0.4 * (i + 1)
		var h := top_y - floor_y + 0.4
		_box(Vector3(3, h, 0.8),
				Vector3(12.5, top_y - h * 0.5, -19.6 + i * 0.8), _dark)
	# Shaft walls so you cannot fall off the stairs
	_box(Vector3(0.4, 12, 16), Vector3(11.0, 0.0, -16), _dark)
	_box(Vector3(0.4, 12, 16), Vector3(18.0, 0.0, -16), _dark)
	_box(Vector3(7.4, 12, 0.4), Vector3(14.5, 0.0, -24), _dark)
	# Prison cells along the west wall: stone dividers + bar fronts
	for c in 5:
		var cz := -20.0 + c * 8.0
		_box(Vector3(6, 3.5, 0.4), Vector3(-23, floor_y + 1.75, cz), _stone)
		for b in 4:
			_box(Vector3(0.12, 3.5, 0.12),
					Vector3(-20.2, floor_y + 1.75, cz + 1.2 + b * 1.4), _dark, "metal")
		if c == 2:
			_crate(Vector3(-23.5, floor_y, cz + 3.6))
	_box(Vector3(6, 3.5, 0.4), Vector3(-23, floor_y + 1.75, 20.0), _stone)
	# Torches and loot
	_torch(Vector3(15.5, TOP - 2.0, -12))
	_torch(Vector3(10, floor_y + 3.0, -14))
	_torch(Vector3(-14, floor_y + 3.0, 0))
	_torch(Vector3(10, floor_y + 3.0, 14))
	_crate(Vector3(8.0, floor_y, 16.0))
	_crate(Vector3(-6.0, floor_y, -16.0))
	# The dragons
	var d1: CharacterBody3D = DragonScript.new()
	d1.position = Vector3(-4, floor_y + 2.5, 2)
	d1.waypoints = [Vector3(-14, floor_y + 2.5, -12) + position,
			Vector3(8, floor_y + 2.5, -14) + position,
			Vector3(12, floor_y + 2.5, 12) + position,
			Vector3(-12, floor_y + 2.5, 14) + position]
	add_child(d1)
	var d2: CharacterBody3D = DragonScript.new()
	d2.position = Vector3(6, floor_y + 2.5, -8)
	d2.waypoints = [Vector3(10, floor_y + 2.5, 10) + position,
			Vector3(-12, floor_y + 2.5, -10) + position,
			Vector3(0, floor_y + 2.5, 16) + position]
	add_child(d2)
