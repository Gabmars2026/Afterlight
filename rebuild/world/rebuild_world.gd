class_name RebuildWorld
extends Node3D
## Clean, asset-driven vertical-slice world. The legacy world remains untouched.

const PropLib := preload("res://scripts/world/prop_lib.gd")
const SlidingDoor := preload("res://scripts/world/sliding_door.gd")

const ROAD_ROOT := "res://assets/kenney/city_roads"
const COMMERCIAL_ROOT := "res://assets/kenney/city_commercial"
const INDUSTRIAL_ROOT := "res://assets/kenney/city_industrial"
const SUBURBAN_ROOT := "res://assets/kenney/city_suburban"

var _ground_mat: StandardMaterial3D
var _wall_mat: StandardMaterial3D
var _road_mat: StandardMaterial3D
var _model_bounds: Dictionary = {}


func build() -> void:
	_make_materials()
	_build_ground()
	_build_road_grid()
	# Building centers are deliberately kept outside the x=0 and horizontal
	# road corridors. Each row occupies the middle of a city block.
	_build_district(COMMERCIAL_ROOT,
			[-28.0, -58.0, -88.0, -118.0, -148.0],
			[-92.0, -28.0, 40.0, 104.0], 9.0)
	_build_district(INDUSTRIAL_ROOT,
			[28.0, 58.0, 88.0, 118.0, 148.0],
			[-92.0, -28.0, 40.0, 104.0], 8.0)
	_build_district(SUBURBAN_ROOT,
			[-160.0, -130.0, -100.0, -70.0, -40.0,
			40.0, 70.0, 100.0, 130.0, 160.0],
			[-158.0, 148.0, 178.0], 8.0)
	_build_enterable_building(Vector3(18, 0.0, 34))
	_build_prop_plaza(Vector3(-30, 0.0, 86))
	_build_street_furniture()


func _make_materials() -> void:
	_ground_mat = StandardMaterial3D.new()
	_ground_mat.albedo_texture = load("res://assets/textures/sand.png")
	_ground_mat.roughness = 1.0
	_ground_mat.uv1_triplanar = true
	_ground_mat.uv1_world_triplanar = true
	_ground_mat.uv1_scale = Vector3.ONE * 0.35
	_wall_mat = StandardMaterial3D.new()
	_wall_mat.albedo_texture = load("res://assets/textures/plaster.png")
	_wall_mat.roughness = 0.92
	_wall_mat.uv1_triplanar = true
	_wall_mat.uv1_world_triplanar = true
	_road_mat = StandardMaterial3D.new()
	_road_mat.albedo_texture = load("res://assets/textures/cobble.png")
	_road_mat.roughness = 0.96
	_road_mat.uv1_triplanar = true
	_road_mat.uv1_world_triplanar = true


func _build_ground() -> void:
	_box(Vector3(390, 2, 390), Vector3(0, -1, 0), _ground_mat, true, "sand")
	# Roads are visual overlays on the one continuous ground collider. Separate
	# raised road colliders created tiny edges that could stop a moving car.
	_box(Vector3(370, 0.02, 10), Vector3(0, 0.01, 10), _road_mat, false, "concrete")
	_box(Vector3(10, 0.02, 370), Vector3(0, 0.01, 0), _road_mat, false, "concrete")
	for z in [-62.0, -122.0, 70.0]:
		_box(Vector3(370, 0.02, 8), Vector3(0, 0.01, z), _road_mat, false, "concrete")
	_build_boundary_walls()


func _build_boundary_walls() -> void:
	# A visible perimeter keeps players and vehicles on the authored map.
	const EDGE := 193.0
	const WALL_HEIGHT := 8.0
	const WALL_THICKNESS := 2.0
	_box(Vector3(390, WALL_HEIGHT, WALL_THICKNESS),
			Vector3(0, WALL_HEIGHT * 0.5, -EDGE), _wall_mat, true, "concrete")
	_box(Vector3(390, WALL_HEIGHT, WALL_THICKNESS),
			Vector3(0, WALL_HEIGHT * 0.5, EDGE), _wall_mat, true, "concrete")
	_box(Vector3(WALL_THICKNESS, WALL_HEIGHT, 386),
			Vector3(-EDGE, WALL_HEIGHT * 0.5, 0), _wall_mat, true, "concrete")
	_box(Vector3(WALL_THICKNESS, WALL_HEIGHT, 386),
			Vector3(EDGE, WALL_HEIGHT * 0.5, 0), _wall_mat, true, "concrete")


func _build_road_grid() -> void:
	# Kenney tiles sit just above the continuous ground collider.
	for x in range(-18, 19):
		_place_visual(ROAD_ROOT + "/road-straight.glb", Vector3(x * 10.0, 0.02, 10), PI * 0.5, 10.0)
	for z in range(-18, 19):
		_place_visual(ROAD_ROOT + "/road-straight.glb", Vector3(0, 0.02, z * 10.0), 0.0, 10.0)
	for z in [-60.0, -120.0, 70.0]:
		for x in range(-18, 19):
			_place_visual(ROAD_ROOT + "/road-straight.glb", Vector3(x * 10.0, 0.02, z), PI * 0.5, 10.0)
	for z in [-120.0, -60.0, 10.0, 70.0]:
		_place_visual(ROAD_ROOT + "/road-crossroad.glb", Vector3(0, 0.025, z), 0.0, 10.0)


func _build_district(root: String, x_positions: Array,
		z_positions: Array, model_scale: float) -> void:
	var paths := _building_paths(root)
	for index in paths.size():
		var column := index % x_positions.size()
		var row := index / x_positions.size()
		if row >= z_positions.size():
			push_warning("Not enough rebuild lots for %s" % root)
			break
		var pos := Vector3(x_positions[column], 0.0, z_positions[row])
		var yaw := PI if row % 2 == 0 else 0.0
		_place_collidable_model(paths[index], pos, yaw, model_scale, "concrete")


func _building_paths(root: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(root)
	if directory == null:
		push_warning("Missing rebuild asset directory: %s" % root)
		return result
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		if not directory.current_is_dir() and filename.ends_with(".glb") \
				and filename.begins_with("building") \
				and not filename.begins_with("low-detail"):
			result.append(root + "/" + filename)
		filename = directory.get_next()
	directory.list_dir_end()
	result.sort()
	return result


func _build_enterable_building(base: Vector3) -> void:
	var building := Node3D.new()
	building.name = "EnterableWorkshop"
	building.position = base
	add_child(building)
	_box(Vector3(16, 0.3, 12), Vector3(0, 0.15, 0), _wall_mat, true, "wood", building)
	_box(Vector3(16, 4, 0.4), Vector3(0, 2, -5.8), _wall_mat, true, "concrete", building)
	_box(Vector3(0.4, 4, 12), Vector3(-7.8, 2, 0), _wall_mat, true, "concrete", building)
	_box(Vector3(0.4, 4, 12), Vector3(7.8, 2, 0), _wall_mat, true, "concrete", building)
	# Front wall leaves a centered doorway.
	_box(Vector3(6.4, 4, 0.4), Vector3(-4.8, 2, 5.8), _wall_mat, true, "concrete", building)
	_box(Vector3(6.4, 4, 0.4), Vector3(4.8, 2, 5.8), _wall_mat, true, "concrete", building)
	_box(Vector3(16, 0.35, 12), Vector3(0, 4.2, 0), _wall_mat, true, "concrete", building)
	var door := SlidingDoor.new()
	door.slide_offset = Vector3(2.8, 0, 0)
	var door_mesh := MeshInstance3D.new()
	var door_box := BoxMesh.new()
	door_box.size = Vector3(3.0, 3.4, 0.25)
	door_box.material = _road_mat
	door_mesh.mesh = door_box
	door.add_child(door_mesh)
	var door_shape := CollisionShape3D.new()
	var door_collision := BoxShape3D.new()
	door_collision.size = door_box.size
	door_shape.shape = door_collision
	door.add_child(door_shape)
	door.position = Vector3(0, 1.7, 5.8)
	building.add_child(door)
	PropLib.place(building, "Table", Vector3(2.5, 0.3, -1.5), 0.0, 0.8)
	PropLib.place(building, "Chair", Vector3(4.0, 0.3, -1.5), PI, 0.8)
	PropLib.place(building, "Barril", Vector3(-5.5, 0.3, -3.5), 0.0, 0.8)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 3.4, 0)
	light.light_color = Color(1.0, 0.82, 0.62)
	light.light_energy = 1.4
	light.omni_range = 12.0
	building.add_child(light)


func _build_prop_plaza(origin: Vector3) -> void:
	# Curated medieval assets stay reusable and visible without duplicating files.
	var props := ["Barril", "Battle_Axe", "Chair", "Chope_A", "Chope_B", "Cup",
			"Lamp", "Panel", "Pole", "Rock_1", "Rock_2", "Rock_3", "Seat",
			"Shield", "Signal", "Stone", "Sword", "Table", "Wood_Axe",
			"Wood_Plank_A", "Wood_Plank_B", "Wood_Trunk"]
	for index in props.size():
		var p := origin + Vector3((index % 6) * 4.0, 0.2, (index / 6) * 4.0)
		PropLib.place(self, props[index], p, index * 0.37, 0.75)


func _build_street_furniture() -> void:
	for x in [-50.0, 50.0, 120.0, -120.0]:
		_place_visual(ROAD_ROOT + "/light-curved-double.glb", Vector3(x, 0.12, 4.5), 0.0, 6.0)
		var light := OmniLight3D.new()
		light.position = Vector3(x, 6.0, 4.5)
		light.light_color = Color(1.0, 0.88, 0.68)
		light.light_energy = 0.7
		light.omni_range = 18.0
		add_child(light)
	_place_visual(ROAD_ROOT + "/sign-highway-wide.glb", Vector3(4, 0.12, 17), PI, 6.0)
	_place_visual(ROAD_ROOT + "/construction-barrier.glb", Vector3(10, 0.12, 17), 0.0, 4.0)
	_place_visual(SUBURBAN_ROOT + "/tree-large.glb", Vector3(-12, 0.12, 44), 0.0, 7.0)
	_place_visual(SUBURBAN_ROOT + "/tree-small.glb", Vector3(-20, 0.12, 48), 0.0, 7.0)


func _place_visual(path: String, pos: Vector3, yaw: float, model_scale: float) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("Missing rebuild model: %s" % path)
		return null
	var model := packed.instantiate() as Node3D
	model.position = pos
	model.rotation.y = yaw
	model.scale = Vector3.ONE * model_scale
	add_child(model)
	return model


func _place_collidable_model(path: String, pos: Vector3, yaw: float,
		model_scale: float, surface: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("Missing rebuild model: %s" % path)
		return
	var model := packed.instantiate() as Node3D
	model.scale = Vector3.ONE * model_scale
	var bounds := _bounds_for(path, model)
	var body := StaticBody3D.new()
	# Align the lowest mesh vertex to the terrain instead of assuming every
	# asset has the same origin. This removes the one-metre floating offset.
	body.position = Vector3(pos.x, pos.y - bounds.position.y * model_scale, pos.z)
	body.rotation.y = yaw
	body.set_meta("surface", surface)
	body.add_child(model)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = bounds.size * model_scale
	collision.shape = shape
	collision.position = (bounds.position + bounds.size * 0.5) * model_scale
	body.add_child(collision)
	add_child(body)


func _bounds_for(path: String, model: Node3D) -> AABB:
	if _model_bounds.has(path):
		return _model_bounds[path]
	var result := AABB()
	var first := true
	for child in model.find_children("*", "MeshInstance3D", true):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local_bounds := mesh_instance.transform * mesh_instance.mesh.get_aabb()
		result = local_bounds if first else result.merge(local_bounds)
		first = false
	_model_bounds[path] = result
	return result


func _box(size: Vector3, pos: Vector3, material: Material, collide: bool,
		surface: String, parent: Node3D = null) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	if parent == null:
		parent = self
	parent.add_child(mesh_instance)
	if collide:
		var body := StaticBody3D.new()
		body.set_meta("surface", surface)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		mesh_instance.add_child(body)
	return mesh_instance
