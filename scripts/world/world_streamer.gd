extends Node3D
## Open-world streaming (Phase 12). The handcrafted town covers cells
## (-1..1, -1..1) of a 30 m grid; every other cell is generated on demand
## from a coordinate seed as the player approaches, and unloaded (freed)
## when they move away. At most one cell is built per physics frame, and
## far cells hide their small props (LOD).

const CELL := 30.0
var LOAD_R := 3      # Chebyshev ring of cells kept loaded
var UNLOAD_R := 4    # freed beyond this ring
var DETAIL_R := 2    # small props visible within this ring


func set_view(load_r: int, unload_r: int, detail_r: int) -> void:
	LOAD_R = load_r
	UNLOAD_R = unload_r
	DETAIL_R = detail_r


func cell_count() -> int:
	return _loaded.size()

const LootCrateScript := preload("res://scripts/world/loot_crate.gd")

var player: Node3D
var sand_mat: StandardMaterial3D
var plaster_mat: StandardMaterial3D

var terrain_data: Object = null  # Terrain3DData, set by the zone

var _loaded := {}          # Vector2i -> cell root Node3D
var _queue: Array = []     # cells waiting to be built
var _timer := 0.0


func _ready() -> void:
	add_to_group("streamer")


func _physics_process(delta: float) -> void:
	if player == null:
		return
	# Build at most one queued cell per frame (no hitches)
	if not _queue.is_empty():
		var c: Vector2i = _queue.pop_front()
		if _loaded.has(c) and _loaded[c] == null:
			_loaded[c] = _build_cell(c)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.4
	var pc := Vector2i(roundi(player.global_position.x / CELL),
			roundi(player.global_position.z / CELL))
	# Queue missing cells in range
	for dx in range(-LOAD_R, LOAD_R + 1):
		for dz in range(-LOAD_R, LOAD_R + 1):
			var c := Vector2i(pc.x + dx, pc.y + dz)
			if _is_core(c) or _loaded.has(c):
				continue
			_loaded[c] = null
			_queue.append(c)
	# Unload far cells + LOD toggle for the rest
	for c in _loaded.keys():
		var node = _loaded[c]
		var ring: int = maxi(absi(c.x - pc.x), absi(c.y - pc.y))
		if ring > UNLOAD_R:
			if node != null:
				node.queue_free()
			_loaded.erase(c)
		elif node != null:
			var detail: Node3D = node.get_node_or_null("detail")
			if detail:
				detail.visible = ring <= DETAIL_R


func _is_core(c: Vector2i) -> bool:
	return absi(c.x) <= 2 and absi(c.y) <= 2


func _build_cell(c: Vector2i) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c)
	var root := Node3D.new()
	root.position = Vector3(c.x * CELL, 0, c.y * CELL)
	add_child(root)
	# Terrain3D provides the ground out here - no flat slab needed.
	var detail := Node3D.new()
	detail.name = "detail"
	root.add_child(detail)
	# Rocks
	for i in rng.randi_range(2, 5):
		var size := Vector3(rng.randf_range(0.6, 2.2), rng.randf_range(0.5, 1.6),
				rng.randf_range(0.6, 2.2))
		var pos := _spot(rng, size)
		pos.y = _h(root, pos)
		_slab(detail, size, Vector3(pos.x, pos.y + size.y * 0.25, pos.z), null,
				Color(0.62, 0.58, 0.52).lerp(Color(0.5, 0.47, 0.45), rng.randf()))
	# Debris
	for i in rng.randi_range(1, 3):
		var dsize := Vector3(rng.randf_range(0.3, 0.9), rng.randf_range(0.2, 0.5),
				rng.randf_range(0.3, 0.9))
		var dpos := _spot(rng, dsize)
		dpos.y = _h(root, dpos)
		_slab(detail, dsize, Vector3(dpos.x, dpos.y + dsize.y * 0.35, dpos.z), null,
				Color(0.55, 0.45, 0.35).lerp(Color(0.4, 0.38, 0.36), rng.randf()))
	# Ruined shack (structure stays visible at any distance)
	if rng.randf() < 0.35:
		_shack(root, detail, rng)
	return root


func _shack(root: Node3D, detail: Node3D, rng: RandomNumberGenerator) -> void:
	var w := rng.randf_range(4.5, 6.5)
	var d := rng.randf_range(4.0, 5.5)
	var h := rng.randf_range(2.4, 3.0)
	var pos := _spot(rng, Vector3(w, h, d))
	var base := _h(root, pos)
	var tint := Color(0.83, 0.56, 0.43) if rng.randf() < 0.4 \
			else Color(0.85, 0.8, 0.7)
	tint = tint.darkened(rng.randf_range(0.0, 0.25))
	var missing := rng.randi_range(0, 3)  # one wall collapsed
	# Foundation pad so the walls never float on a dune slope
	_slab(root, Vector3(w + 1.2, 0.7, d + 1.2),
			pos + Vector3(0, base - 0.15, 0), plaster_mat, tint.darkened(0.1))
	if missing != 0:
		_slab(root, Vector3(w, h, 0.3), pos + Vector3(0, base + h * 0.5, -d * 0.5),
				plaster_mat, tint)
	if missing != 1:
		_slab(root, Vector3(w, h, 0.3), pos + Vector3(0, base + h * 0.5, d * 0.5),
				plaster_mat, tint)
	if missing != 2:
		_slab(root, Vector3(0.3, h, d), pos + Vector3(-w * 0.5, base + h * 0.5, 0),
				plaster_mat, tint)
	if missing != 3:
		_slab(root, Vector3(0.3, h, d), pos + Vector3(w * 0.5, base + h * 0.5, 0),
				plaster_mat, tint)
	if rng.randf() < 0.5:
		_slab(root, Vector3(w + 0.6, 0.25, d + 0.6),
				pos + Vector3(0, base + h + 0.12, 0), plaster_mat, tint.darkened(0.2))
	# Supplies hidden inside more often than not
	if rng.randf() < 0.6:
		var crate := LootCrateScript.new()
		crate.position = pos + Vector3(rng.randf_range(-1, 1), base + 0.75,
				rng.randf_range(-1, 1))
		detail.add_child(crate)


## Terrain height at a cell-local offset (world = cell root + local).
func _h(root: Node3D, local: Vector3) -> float:
	if terrain_data == null:
		return 0.0
	var h: float = terrain_data.get_height(Vector3(
			root.position.x + local.x, 0.0, root.position.z + local.z))
	return h if is_finite(h) else 0.0


## Random spot inside the cell, keeping clear of the edges.
func _spot(rng: RandomNumberGenerator, size: Vector3) -> Vector3:
	var m := maxf(size.x, size.z) * 0.5 + 1.5
	return Vector3(rng.randf_range(-CELL * 0.5 + m, CELL * 0.5 - m), 0,
			rng.randf_range(-CELL * 0.5 + m, CELL * 0.5 - m))


func _slab(parent: Node3D, size: Vector3, pos: Vector3,
		mat: StandardMaterial3D, tint := Color.WHITE) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	if mat != null and tint != Color.WHITE:
		var tm := mat.duplicate() as StandardMaterial3D
		tm.albedo_color = tint.lerp(Color(0.92, 0.84, 0.68), 0.22)
		mesh.material = tm
	elif mat != null:
		mesh.material = mat
	else:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.albedo_color = tint.lerp(Color(0.92, 0.84, 0.68), 0.22)
		m.roughness = 1.0
		mesh.material = m
	mi.mesh = mesh
	body.add_child(mi)
	body.set_meta("surface", "concrete")
	parent.add_child(body)
