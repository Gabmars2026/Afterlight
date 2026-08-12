class_name RebuildWorld
extends Node3D
## Clean, asset-driven vertical-slice world. The legacy world remains untouched.

const PropLib := preload("res://scripts/world/prop_lib.gd")
const SlidingDoor := preload("res://scripts/world/sliding_door.gd")
const ElevatorPanel := preload("res://scripts/world/elevator_panel.gd")
const BuildingPortal := preload("res://scripts/world/building_portal.gd")
const VehicleGaragePortal := preload("res://scripts/world/vehicle_garage_portal.gd")

const ROAD_ROOT := "res://assets/kenney/city_roads"
const COMMERCIAL_ROOT := "res://assets/kenney/city_commercial"
const INDUSTRIAL_ROOT := "res://assets/kenney/city_industrial"
const SUBURBAN_ROOT := "res://assets/kenney/city_suburban"
const DOWNTOWN_ROOT := "res://assets/quaternius/downtown_city"
const POLY_HYDRANT := "res://assets/poly_haven/fire_hydrant/fire_hydrant_1k.gltf"
const FLOOR_HEIGHT := 3.6
const DOOR_WIDTH := 1.9
const DOOR_HEIGHT := 2.55
const STAIR_WIDTH := 1.75
const STAIR_STEPS := 12

var _ground_mat: StandardMaterial3D
var _wall_mat: StandardMaterial3D
var _road_mat: StandardMaterial3D
var _mountain_mat: StandardMaterial3D
var _model_bounds: Dictionary = {}


func build() -> void:
	_make_materials()
	_build_ground()
	_build_road_grid()
	_build_eastern_mountain()
	# Building centers are deliberately kept outside the x=0 and horizontal
	# road corridors. Lots now span the enlarged map instead of clustering only
	# in the original 370 metre centre.
	_build_district(COMMERCIAL_ROOT,
			[-805.0, -565.0, -325.0, -85.0, 155.0],
			[-685.0, -325.0, 35.0, 395.0], 9.0)
	_build_district(INDUSTRIAL_ROOT,
			[-685.0, -445.0, -205.0, 275.0, 515.0],
			[-565.0, -205.0, 275.0, 635.0], 8.0)
	_build_district(SUBURBAN_ROOT,
			[-745.0, -505.0, -265.0, -25.0, 215.0,
			455.0, 695.0, 815.0, 575.0, 335.0],
			[-745.0, 815.0, 515.0], 8.0)
	_build_district(DOWNTOWN_ROOT,
			[-865.0, -625.0, -385.0],
			[755.0], 5.5)
	_build_prop_plaza(Vector3(-30, 0.0, 86))
	_build_street_furniture()
	_build_city_parks()


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
	_mountain_mat = StandardMaterial3D.new()
	_mountain_mat.albedo_color = Color(0.24, 0.31, 0.2)
	_mountain_mat.roughness = 1.0
	_mountain_mat.uv1_triplanar = true
	_mountain_mat.uv1_world_triplanar = true
	_mountain_mat.uv1_scale = Vector3.ONE * 0.08


func _build_ground() -> void:
	_box(Vector3(1950, 2, 1950), Vector3(0, -1, 0), _ground_mat, true, "sand")
	_build_boundary_walls()


func _build_boundary_walls() -> void:
	# A visible perimeter keeps players and vehicles on the authored map.
	const EDGE := 973.0
	const WALL_HEIGHT := 8.0
	const WALL_THICKNESS := 2.0
	_box(Vector3(1950, WALL_HEIGHT, WALL_THICKNESS),
			Vector3(0, WALL_HEIGHT * 0.5, -EDGE), _wall_mat, true, "concrete")
	_box(Vector3(1950, WALL_HEIGHT, WALL_THICKNESS),
			Vector3(0, WALL_HEIGHT * 0.5, EDGE), _wall_mat, true, "concrete")
	_box(Vector3(WALL_THICKNESS, WALL_HEIGHT, 1946),
			Vector3(-EDGE, WALL_HEIGHT * 0.5, 0), _wall_mat, true, "concrete")
	_box(Vector3(WALL_THICKNESS, WALL_HEIGHT, 1946),
			Vector3(EDGE, WALL_HEIGHT * 0.5, 0), _wall_mat, true, "concrete")


func _build_road_grid() -> void:
	# One continuous, flush road grid replaces overlapping GLB road tiles. The
	# old tiles produced the scattered white lane fragments shown by the user.
	for coordinate in range(-840, 841, 120):
		_box(Vector3(1900, 0.012, 18), Vector3(0, 0.006, coordinate),
				_road_mat, false, "concrete")
		_box(Vector3(18, 0.012, 1900), Vector3(coordinate, 0.006, 0),
				_road_mat, false, "concrete")


func _build_eastern_mountain() -> void:
	## A continuous, walkable ridge frames the city like GTA's edge mountains.
	## It occupies the otherwise empty eastern strip, clear of authored lots.
	const GRID_X := 41
	const GRID_Z := 51
	const MIN_X := 580.0
	const MAX_X := 968.0
	const MIN_Z := -390.0
	const MAX_Z := 390.0
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for z_index in GRID_Z:
		var z_ratio := float(z_index) / float(GRID_Z - 1)
		var world_z := lerpf(MIN_Z, MAX_Z, z_ratio)
		for x_index in GRID_X:
			var x_ratio := float(x_index) / float(GRID_X - 1)
			var world_x := lerpf(MIN_X, MAX_X, x_ratio)
			var height := _mountain_height(world_x, world_z)
			vertices.append(Vector3(world_x, height, world_z))
			var sample := 2.0
			var slope_x := _mountain_height(world_x - sample, world_z) \
					- _mountain_height(world_x + sample, world_z)
			var slope_z := _mountain_height(world_x, world_z - sample) \
					- _mountain_height(world_x, world_z + sample)
			normals.append(Vector3(slope_x, sample * 2.0, slope_z).normalized())
			uvs.append(Vector2(x_ratio * 8.0, z_ratio * 8.0))
	for z_index in GRID_Z - 1:
		for x_index in GRID_X - 1:
			var a := z_index * GRID_X + x_index
			var b := a + 1
			var c := a + GRID_X
			var d := c + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _mountain_mat)
	var terrain := MeshInstance3D.new()
	terrain.name = "EasternMountainRidge"
	terrain.mesh = mesh
	add_child(terrain)
	var body := StaticBody3D.new()
	body.set_meta("surface", "grass")
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	terrain.add_child(body)
	_build_mountain_switchback()


func _mountain_height(world_x: float, world_z: float) -> float:
	# Several overlapping elliptical peaks form a massive foothill-to-summit
	# silhouette rather than one symmetric ramp or cone.
	var main_peak := _mountain_peak(world_x, world_z, 845.0, -45.0,
			176.0, 235.0, 166.0)
	var north_peak := _mountain_peak(world_x, world_z, 815.0, 185.0,
			148.0, 175.0, 128.0)
	var south_peak := _mountain_peak(world_x, world_z, 875.0, -245.0,
			132.0, 165.0, 112.0)
	var foothill := _mountain_peak(world_x, world_z, 690.0, 15.0,
			100.0, 300.0, 54.0)
	var height := main_peak + north_peak * 0.68 + south_peak * 0.62 + foothill
	var edge_x := smoothstep(580.0, 640.0, world_x) \
			* (1.0 - smoothstep(940.0, 968.0, world_x))
	var edge_z := smoothstep(-390.0, -345.0, world_z) \
			* (1.0 - smoothstep(345.0, 390.0, world_z))
	var rock_detail := (sin(world_x * 0.052 + world_z * 0.019)
			+ sin(world_z * 0.067) * 0.55) * 5.0 * clampf(height / 80.0, 0.0, 1.0)
	return maxf(0.0, (height + rock_detail) * edge_x * edge_z)


func _mountain_peak(world_x: float, world_z: float, centre_x: float,
		centre_z: float, radius_x: float, radius_z: float,
		height: float) -> float:
	var dx := (world_x - centre_x) / radius_x
	var dz := (world_z - centre_z) / radius_z
	var distance := sqrt(dx * dx + dz * dz)
	var profile := clampf(1.0 - distance, 0.0, 1.0)
	return pow(profile, 1.55) * height


func _build_mountain_switchback() -> void:
	## Wide ramp segments provide a reliable car route while the surrounding
	## terrain remains freely climbable on foot.
	var points: Array[Vector3] = [Vector3(590, 0, 300), Vector3(680, 0, 300),
			Vector3(720, 0, 210), Vector3(675, 0, 120),
			Vector3(755, 0, 55), Vector3(720, 0, -40),
			Vector3(800, 0, -105), Vector3(770, 0, -200),
			Vector3(850, 0, -145), Vector3(845, 0, -55)]
	for index in points.size():
		points[index].y = _mountain_height(points[index].x, points[index].z) + 0.45
	for index in points.size() - 1:
		# Subdivision keeps the paved route pressed against curved terrain.
		var start := points[index]
		var finish := points[index + 1]
		for section in 8:
			var from_ratio := float(section) / 8.0
			var to_ratio := float(section + 1) / 8.0
			var from := start.lerp(finish, from_ratio)
			var to := start.lerp(finish, to_ratio)
			from.y = _mountain_height(from.x, from.z) + 0.45
			to.y = _mountain_height(to.x, to.z) + 0.45
			_build_road_ramp(from, to)
	# A broad overlook gives cars room to turn around at the summit.
	var summit_y := _mountain_height(845.0, -55.0) + 0.35
	_box(Vector3(44, 0.45, 34), Vector3(845, summit_y, -55),
			_road_mat, true, "concrete")


func _build_road_ramp(from: Vector3, to: Vector3) -> void:
	var delta := to - from
	var horizontal := Vector2(delta.x, delta.z).length()
	var ramp := _box(Vector3(9.5, 0.45, delta.length()),
			(from + to) * 0.5, _road_mat, true, "concrete")
	ramp.rotation = Vector3(-atan2(delta.y, horizontal),
			atan2(delta.x, delta.z), 0.0)


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
		_build_enterable_lot(paths[index], pos, yaw, model_scale, index)


func _building_paths(root: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(root)
	if directory == null:
		push_warning("Missing rebuild asset directory: %s" % root)
		return result
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		var is_kenney_building := filename.begins_with("building") \
				and not filename.begins_with("low-detail")
		var is_downtown_building := filename.begins_with("b_")
		if not directory.current_is_dir() and filename.ends_with(".glb") \
				and (is_kenney_building or is_downtown_building):
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


func _build_enterable_house(base: Vector3) -> void:
	## A compact furnished starter house with a real doorway and usable door.
	var house := Node3D.new()
	house.name = "EnterableStarterHouse"
	house.position = base
	house.rotation.y = PI * 0.5  # Point the front door toward the nearby road.
	add_child(house)
	_box(Vector3(8, 0.25, 8), Vector3(0, 0.125, 0), _wall_mat, true, "wood", house)
	_box(Vector3(8, 3.4, 0.3), Vector3(0, 1.7, -3.85), _wall_mat, true, "concrete", house)
	_box(Vector3(0.3, 3.4, 8), Vector3(-3.85, 1.7, 0), _wall_mat, true, "concrete", house)
	_box(Vector3(0.3, 3.4, 8), Vector3(3.85, 1.7, 0), _wall_mat, true, "concrete", house)
	# Two front panels and a lintel leave a 1.8 x 2.5 metre entrance.
	_box(Vector3(3.1, 3.4, 0.3), Vector3(-2.45, 1.7, 3.85), _wall_mat, true, "concrete", house)
	_box(Vector3(3.1, 3.4, 0.3), Vector3(2.45, 1.7, 3.85), _wall_mat, true, "concrete", house)
	_box(Vector3(1.8, 0.9, 0.3), Vector3(0, 2.95, 3.85), _wall_mat, true, "concrete", house)
	_box(Vector3(8.5, 0.3, 8.5), Vector3(0, 3.55, 0), _road_mat, true, "wood", house)
	var door := SlidingDoor.new()
	door.slide_offset = Vector3(1.9, 0, 0)
	var door_mesh := MeshInstance3D.new()
	var door_box := BoxMesh.new()
	door_box.size = Vector3(1.75, 2.5, 0.18)
	door_box.material = _road_mat
	door_mesh.mesh = door_box
	door.add_child(door_mesh)
	var door_shape := CollisionShape3D.new()
	var door_collision := BoxShape3D.new()
	door_collision.size = door_box.size
	door_shape.shape = door_collision
	door.add_child(door_shape)
	door.position = Vector3(0, 1.25, 3.85)
	house.add_child(door)
	PropLib.place(house, "Table", Vector3(1.5, 0.25, -1.0), 0.0, 0.65)
	PropLib.place(house, "Chair", Vector3(2.5, 0.25, -1.0), PI, 0.65)
	PropLib.place(house, "Lamp", Vector3(-2.4, 0.25, -2.0), 0.0, 0.65)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.7, 0)
	light.light_color = Color(1.0, 0.78, 0.56)
	light.light_energy = 1.2
	light.omni_range = 8.0
	house.add_child(light)


func _build_enterable_lot(path: String, pos: Vector3, yaw: float,
		model_scale: float, lot_index: int) -> void:
	## Preserve the asset-authored exterior at ground level. Its designed front
	## door is the interaction point for a separate, correctly scaled interior.
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("Missing rebuild model: %s" % path)
		return
	var exterior := packed.instantiate() as Node3D
	var bounds := _bounds_for(path, exterior)
	var exterior_scale := model_scale * 1.65
	# Do not cap the playable interior. The previous 26 x 24 m cap caused large
	# towers to become a small hallway after entering. These dimensions now use
	# the exact scaled exterior footprint.
	var width := maxf(bounds.size.x * exterior_scale, DOOR_WIDTH + 4.0)
	var depth := maxf(bounds.size.z * exterior_scale, 8.0)
	var authored_height := maxf(bounds.size.y * exterior_scale, FLOOR_HEIGHT)
	var floor_count := clampi(int(ceil(authored_height / FLOOR_HEIGHT)), 1, 14)
	var lot := Node3D.new()
	lot.name = "EnterableBuilding_%02d" % lot_index
	lot.position = pos
	lot.rotation.y = yaw
	add_child(lot)
	# Use the original building at its intended size and rest its lowest mesh
	# point on the terrain. Previously this model was a tiny rooftop ornament.
	exterior.scale = Vector3.ONE * exterior_scale
	exterior.position = Vector3(
		-(bounds.position.x + bounds.size.x * 0.5) * exterior_scale,
		-bounds.position.y * exterior_scale,
		-(bounds.position.z + bounds.size.z * 0.5) * exterior_scale)
	lot.add_child(exterior)
	_build_exterior_collision(lot, width, depth, authored_height)

	# Interior rooms live below their matching lot. Door portals make the
	# transition while the exterior remains visually faithful to the asset.
	var interior := Node3D.new()
	interior.name = "PlayableInterior"
	# Keep the ceiling of even the tallest interior safely below terrain.
	interior.position.y = -(floor_count * FLOOR_HEIGHT + 8.0)
	lot.add_child(interior)
	_build_floor_slab(interior, width, depth, 0.0, false)
	for floor_index in floor_count:
		_build_floor_shell(interior, width, depth, floor_index, floor_index == 0)
		_build_room_partitions(interior, width, depth, floor_index)
		_furnish_floor(interior, width, depth, floor_index, lot_index)
		_add_floor_light(interior, width, depth, floor_index)
		if floor_count > 1:
			_add_elevator_panel(interior, width, depth, floor_index, floor_count)
		if floor_index < floor_count - 1:
			_build_stair_flight(interior, width, depth, floor_index)
			_build_floor_slab(interior, width, depth,
					(floor_index + 1) * FLOOR_HEIGHT, true)
	# A solid ceiling closes the top interior floor.
	_box(Vector3(width + 0.35, 0.3, depth + 0.35),
			Vector3(0, floor_count * FLOOR_HEIGHT, 0),
			_road_mat, true, "concrete", interior)
	_add_asset_door_portals(lot, interior, width, depth)
	if path.begins_with(SUBURBAN_ROOT):
		_add_suburban_garage(lot, interior, width, depth)


func _add_suburban_garage(lot: Node3D, interior: Node3D,
		width: float, depth: float) -> void:
	## The Kenney houses use an authored garage door on the right of the facade.
	## A transition preserves that exterior while providing a genuinely usable,
	## car-sized bay beside the full house interior.
	const GARAGE_WIDTH := 7.2
	const GARAGE_DEPTH := 12.0
	const GARAGE_HEIGHT := 3.4
	var garage_x := width * 0.5 + GARAGE_WIDTH * 0.5 + 1.2
	var garage := Node3D.new()
	garage.name = "DriveableGarage"
	garage.position = Vector3(garage_x, 0.0, 0.0)
	interior.add_child(garage)
	_box(Vector3(GARAGE_WIDTH, 0.24, GARAGE_DEPTH),
			Vector3(0, 0.12, 0), _road_mat, true, "concrete", garage)
	_box(Vector3(GARAGE_WIDTH, 0.28, GARAGE_DEPTH),
			Vector3(0, GARAGE_HEIGHT, 0), _road_mat, true, "concrete", garage)
	_box(Vector3(GARAGE_WIDTH, GARAGE_HEIGHT, 0.3),
			Vector3(0, GARAGE_HEIGHT * 0.5, -GARAGE_DEPTH * 0.5),
			_wall_mat, true, "concrete", garage)
	_box(Vector3(0.3, GARAGE_HEIGHT, GARAGE_DEPTH),
			Vector3(-GARAGE_WIDTH * 0.5, GARAGE_HEIGHT * 0.5, 0),
			_wall_mat, true, "concrete", garage)
	_box(Vector3(0.3, GARAGE_HEIGHT, GARAGE_DEPTH),
			Vector3(GARAGE_WIDTH * 0.5, GARAGE_HEIGHT * 0.5, 0),
			_wall_mat, true, "concrete", garage)
	# Keep the inner front open so a parked car and its driver have clearance.
	var inside_car_marker := Marker3D.new()
	inside_car_marker.position = Vector3(0, 0.15, -1.5)
	garage.add_child(inside_car_marker)
	var outside_car_marker := Marker3D.new()
	outside_car_marker.position = Vector3(width * 0.28, 0.15, depth * 0.5 + 5.0)
	lot.add_child(outside_car_marker)
	var exterior_entry := VehicleGaragePortal.new()
	exterior_entry.destination = inside_car_marker
	exterior_entry.destination_yaw = lot.global_rotation.y
	exterior_entry.position = Vector3(width * 0.28, 1.25, depth * 0.5 + 0.9)
	lot.add_child(exterior_entry)
	var garage_exit := VehicleGaragePortal.new()
	garage_exit.destination = outside_car_marker
	garage_exit.destination_yaw = lot.global_rotation.y
	garage_exit.position = Vector3(0, 1.25, GARAGE_DEPTH * 0.5 - 0.3)
	garage.add_child(garage_exit)
	# A person can leave the parked car and walk directly into the house.
	var house_marker := Marker3D.new()
	house_marker.position = Vector3(width * 0.5 - 2.0, 0.3, 0)
	interior.add_child(house_marker)
	var garage_marker := Marker3D.new()
	garage_marker.position = Vector3(0, 0.3, -3.0)
	garage.add_child(garage_marker)
	var into_house := BuildingPortal.new()
	into_house.prompt = "Press E to enter house"
	into_house.destination = house_marker
	into_house.position = Vector3(-GARAGE_WIDTH * 0.5 + 0.18, 1.3, -3.0)
	garage.add_child(into_house)
	var into_garage := BuildingPortal.new()
	into_garage.prompt = "Press E to enter garage"
	into_garage.destination = garage_marker
	into_garage.position = Vector3(width * 0.5 - 0.18, 1.3, 0)
	interior.add_child(into_garage)
	var light := OmniLight3D.new()
	light.position = Vector3(0, GARAGE_HEIGHT - 0.4, 0)
	light.light_energy = 1.35
	light.omni_range = 11.0
	garage.add_child(light)


func _build_exterior_collision(lot: Node3D, width: float, depth: float,
		height: float) -> void:
	# Invisible collision follows the authored shell and leaves the designed
	# centered front door clear for its interaction portal.
	var collision_height := maxf(height, DOOR_HEIGHT + 0.5)
	_collision_box(lot, Vector3(width, collision_height, 0.35),
			Vector3(0, collision_height * 0.5, -depth * 0.5))
	_collision_box(lot, Vector3(0.35, collision_height, depth),
			Vector3(-width * 0.5, collision_height * 0.5, 0))
	_collision_box(lot, Vector3(0.35, collision_height, depth),
			Vector3(width * 0.5, collision_height * 0.5, 0))
	var side_width := (width - DOOR_WIDTH) * 0.5
	var side_offset := (DOOR_WIDTH + side_width) * 0.5
	_collision_box(lot, Vector3(side_width, collision_height, 0.35),
			Vector3(-side_offset, collision_height * 0.5, depth * 0.5))
	_collision_box(lot, Vector3(side_width, collision_height, 0.35),
			Vector3(side_offset, collision_height * 0.5, depth * 0.5))
	_collision_box(lot, Vector3(DOOR_WIDTH, collision_height - DOOR_HEIGHT, 0.35),
			Vector3(0, DOOR_HEIGHT + (collision_height - DOOR_HEIGHT) * 0.5,
			depth * 0.5))


func _add_asset_door_portals(lot: Node3D, interior: Node3D,
		width: float, depth: float) -> void:
	var outside_marker := Marker3D.new()
	outside_marker.position = Vector3(0, 0.3, depth * 0.5 + 1.35)
	lot.add_child(outside_marker)
	var inside_marker := Marker3D.new()
	inside_marker.position = Vector3(0, 0.3, depth * 0.5 - 1.25)
	interior.add_child(inside_marker)
	var enter := BuildingPortal.new()
	enter.prompt = "Press E to enter"
	enter.destination = inside_marker
	# Asset doors are not consistently centered: hospitals, shops, factories,
	# houses, and towers place them at different points across the façade. A
	# façade-wide interaction plane ensures the authored entrance is usable on
	# every generated building while still sending the player to its own rooms.
	enter.interaction_size = Vector3(maxf(width - 0.7, DOOR_WIDTH),
			DOOR_HEIGHT, 0.45)
	enter.position = Vector3(0, DOOR_HEIGHT * 0.5, depth * 0.5 + 0.12)
	lot.add_child(enter)
	var exit := BuildingPortal.new()
	exit.prompt = "Press E to exit"
	exit.destination = outside_marker
	exit.position = Vector3(0, DOOR_HEIGHT * 0.5, depth * 0.5 - 0.12)
	interior.add_child(exit)


func _collision_box(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.set_meta("surface", "concrete")
	body.position = pos
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _build_floor_shell(lot: Node3D, width: float, depth: float,
		floor_index: int, entrance: bool) -> void:
	var floor_y := floor_index * FLOOR_HEIGHT
	var wall_y := floor_y + 0.22 + FLOOR_HEIGHT * 0.5
	_box(Vector3(width, FLOOR_HEIGHT, 0.3), Vector3(0, wall_y, -depth * 0.5),
			_wall_mat, true, "concrete", lot)
	_box(Vector3(0.3, FLOOR_HEIGHT, depth), Vector3(-width * 0.5, wall_y, 0),
			_wall_mat, true, "concrete", lot)
	_box(Vector3(0.3, FLOOR_HEIGHT, depth), Vector3(width * 0.5, wall_y, 0),
			_wall_mat, true, "concrete", lot)
	if not entrance:
		_box(Vector3(width, FLOOR_HEIGHT, 0.3), Vector3(0, wall_y, depth * 0.5),
				_wall_mat, true, "concrete", lot)
		return
	var side_width := (width - DOOR_WIDTH) * 0.5
	var side_offset := (DOOR_WIDTH + side_width) * 0.5
	_box(Vector3(side_width, FLOOR_HEIGHT, 0.3),
			Vector3(-side_offset, wall_y, depth * 0.5),
			_wall_mat, true, "concrete", lot)
	_box(Vector3(side_width, FLOOR_HEIGHT, 0.3),
			Vector3(side_offset, wall_y, depth * 0.5),
			_wall_mat, true, "concrete", lot)
	_box(Vector3(DOOR_WIDTH, FLOOR_HEIGHT - DOOR_HEIGHT, 0.3),
			Vector3(0, floor_y + 0.22 + DOOR_HEIGHT
			+ (FLOOR_HEIGHT - DOOR_HEIGHT) * 0.5, depth * 0.5),
			_wall_mat, true, "concrete", lot)
	_add_building_door(lot, depth, floor_y)


func _build_room_partitions(lot: Node3D, width: float, depth: float,
		floor_index: int) -> void:
	## Four proper rooms per floor around a three-metre central hallway. Wall
	## gaps form open doorways so rooms remain navigable without extra prompts.
	var floor_y := floor_index * FLOOR_HEIGHT
	var wall_y := floor_y + 0.22 + FLOOR_HEIGHT * 0.5
	const HALL_HALF := 1.65
	const ROOM_DOOR := 1.5
	var segment := (depth - ROOM_DOOR * 2.0) / 3.0
	var hall_walls: Array[float] = [-HALL_HALF, HALL_HALF]
	for x in hall_walls:
		for segment_index in 3:
			var z := -depth * 0.5 + segment * 0.5 \
					+ segment_index * (segment + ROOM_DOOR)
			_box(Vector3(0.22, FLOOR_HEIGHT, segment), Vector3(x, wall_y, z),
					_wall_mat, true, "concrete", lot)
	# Divide the left and right wings into front/back rooms. The hallway itself
	# remains open from the entrance to the stairs and elevator.
	var wing_width := width * 0.5 - HALL_HALF
	_box(Vector3(wing_width, FLOOR_HEIGHT, 0.22),
			Vector3(-HALL_HALF - wing_width * 0.5, wall_y, 0),
			_wall_mat, true, "concrete", lot)
	var right_divider_width := maxf(0.5, wing_width - STAIR_WIDTH - 1.0)
	_box(Vector3(right_divider_width, FLOOR_HEIGHT, 0.22),
			Vector3(HALL_HALF + right_divider_width * 0.5, wall_y, 0),
			_wall_mat, true, "concrete", lot)


func _add_building_door(lot: Node3D, depth: float, floor_y: float) -> void:
	var door := SlidingDoor.new()
	door.slide_offset = Vector3(DOOR_WIDTH + 0.15, 0, 0)
	var door_mesh := MeshInstance3D.new()
	var door_box := BoxMesh.new()
	door_box.size = Vector3(DOOR_WIDTH - 0.08, DOOR_HEIGHT, 0.18)
	door_box.material = _road_mat
	door_mesh.mesh = door_box
	door.add_child(door_mesh)
	var door_shape := CollisionShape3D.new()
	var door_collision := BoxShape3D.new()
	door_collision.size = door_box.size
	door_shape.shape = door_collision
	door.add_child(door_shape)
	door.position = Vector3(0, floor_y + 0.22 + DOOR_HEIGHT * 0.5, depth * 0.5)
	lot.add_child(door)


func _build_floor_slab(lot: Node3D, width: float, depth: float,
		floor_y: float, stair_opening: bool) -> void:
	if not stair_opening:
		_box(Vector3(width, 0.22, depth), Vector3(0, floor_y + 0.11, 0),
				_wall_mat, true, "wood", lot)
		return
	var open_width := STAIR_WIDTH + 0.25
	var open_depth := minf(5.0, depth - 1.0)
	var right_strip := 0.3
	var main_width := width - open_width - right_strip
	_box(Vector3(main_width, 0.22, depth),
			Vector3(-width * 0.5 + main_width * 0.5, floor_y + 0.11, 0),
			_wall_mat, true, "wood", lot)
	_box(Vector3(right_strip, 0.22, depth),
			Vector3(width * 0.5 - right_strip * 0.5, floor_y + 0.11, 0),
			_wall_mat, true, "wood", lot)
	var end_depth := (depth - open_depth) * 0.5
	var open_x := width * 0.5 - right_strip - open_width * 0.5
	_box(Vector3(open_width, 0.22, end_depth),
			Vector3(open_x, floor_y + 0.11, -depth * 0.5 + end_depth * 0.5),
			_wall_mat, true, "wood", lot)
	_box(Vector3(open_width, 0.22, end_depth),
			Vector3(open_x, floor_y + 0.11, depth * 0.5 - end_depth * 0.5),
			_wall_mat, true, "wood", lot)


func _build_stair_flight(lot: Node3D, width: float, depth: float,
		floor_index: int) -> void:
	var run_length := minf(5.0, depth - 1.0)
	var tread := run_length / STAIR_STEPS
	var rise := FLOOR_HEIGHT / STAIR_STEPS
	var stair_x := width * 0.5 - 0.3 - (STAIR_WIDTH + 0.25) * 0.5
	var base_y := floor_index * FLOOR_HEIGHT + 0.22
	for step_index in STAIR_STEPS:
		_box(Vector3(STAIR_WIDTH, rise, tread + 0.04),
				Vector3(stair_x,
				base_y + rise * (step_index + 0.5),
				-run_length * 0.5 + tread * (step_index + 0.5)),
				_road_mat, true, "concrete", lot)


func _add_elevator_panel(lot: Node3D, width: float, depth: float,
		floor_index: int, floor_count: int) -> void:
	var panel := ElevatorPanel.new()
	var target_floor := (floor_index + 1) % floor_count
	panel.destination_floor = target_floor + 1
	panel.target_local_position = Vector3(0, target_floor * FLOOR_HEIGHT + 0.3, 0)
	panel.position = Vector3(-width * 0.5 + 0.24,
			floor_index * FLOOR_HEIGHT + 1.25, depth * 0.5 - 1.1)
	lot.add_child(panel)


func _furnish_floor(lot: Node3D, width: float, depth: float,
		floor_index: int, lot_index: int) -> void:
	var y := floor_index * FLOOR_HEIGHT + 0.25
	var turn := lot_index * 0.31 + floor_index * 0.47
	# One furniture group in each room makes every floor read as a real building
	# rather than a single oversized empty chamber.
	var room_positions: Array[Vector3] = [Vector3(-width * 0.3, y, -depth * 0.25),
			Vector3(width * 0.3, y, -depth * 0.25),
			Vector3(-width * 0.3, y, depth * 0.25),
			Vector3(width * 0.3, y, depth * 0.25)]
	for room_pos in room_positions:
		PropLib.place(lot, "Table", room_pos, turn, 0.55)
		PropLib.place(lot, "Chair", room_pos + Vector3(1.15, 0, 0.7),
				PI + turn, 0.55)
	# Explicit type is required because indexing an untyped literal Array
	# returns Variant and strict GDScript cannot infer `:=` from it.
	var accent: String = ["Lamp", "Barril", "Seat", "Wood_Plank_A"][floor_index % 4]
	PropLib.place(lot, accent, Vector3(width * 0.28, y, depth * 0.32),
			-turn, 0.5)
	# Extra groups give homes recognizable living, dining, and bedroom zones.
	if width > 10.0 and depth > 10.0:
		PropLib.place(lot, "Seat", Vector3(-width * 0.25, y, depth * 0.34),
				-turn, 0.75)
		PropLib.place(lot, "Seat", Vector3(-width * 0.25 + 1.8, y,
				depth * 0.34), PI - turn, 0.75)
		PropLib.place(lot, "Panel", Vector3(width * 0.25, y,
				-depth * 0.34), turn, 0.6)


func _add_floor_light(lot: Node3D, width: float, depth: float,
		floor_index: int) -> void:
	var light := OmniLight3D.new()
	light.position = Vector3(0, floor_index * FLOOR_HEIGHT + 2.8, 0)
	light.light_color = Color(1.0, 0.8, 0.62)
	light.light_energy = 1.0
	light.omni_range = maxf(width, depth)
	lot.add_child(light)


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
	# Keep large furniture beyond the five-metre road edge and out of the
	# intersection sightline. The sign faces traffic from the east shoulder.
	# Roadside wayfinding: close enough to read from traffic, but fully outside
	# the five-metre driving lane and clear of the workshop wall.
	_place_visual(ROAD_ROOT + "/sign-highway-wide.glb", Vector3(10, 0.02, 20), PI, 6.0)
	_place_visual(ROAD_ROOT + "/construction-barrier.glb", Vector3(12, 0.02, 25), 0.0, 4.0)
	_place_visual(SUBURBAN_ROOT + "/tree-large.glb", Vector3(-12, 0.0, 44), 0.0, 7.0)
	_place_visual(SUBURBAN_ROOT + "/tree-small.glb", Vector3(-20, 0.0, 48), 0.0, 7.0)
	for x in [-54.0, 54.0, -174.0, 174.0]:
		_place_visual(POLY_HYDRANT, Vector3(x, 0.0, 12.0), 0.0, 1.0)


func _build_city_parks() -> void:
	## Small planted public spaces break up the dense city without introducing
	## terrain mounds or blocking the road grid.
	var park_centres: Array[Vector3] = [Vector3(-180, 0, 180),
			Vector3(180, 0, -180), Vector3(420, 0, 420)]
	for centre in park_centres:
		var grass := StandardMaterial3D.new()
		grass.albedo_color = Color(0.22, 0.46, 0.2)
		grass.roughness = 1.0
		_box(Vector3(42, 0.04, 42), centre + Vector3(0, 0.02, 0),
				grass, false, "grass")
		for offset in [Vector3(-14, 0, -14), Vector3(14, 0, -14),
				Vector3(-14, 0, 14), Vector3(14, 0, 14)]:
			_place_visual(SUBURBAN_ROOT + "/tree-small.glb",
					centre + offset, 0.0, 5.5)
		PropLib.place(self, "Seat", centre + Vector3(-5, 0.2, 0),
				PI * 0.5, 0.8)
		PropLib.place(self, "Seat", centre + Vector3(5, 0.2, 0),
				-PI * 0.5, 0.8)


func _place_visual(path: String, pos: Vector3, yaw: float, model_scale: float) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("Missing rebuild model: %s" % path)
		return null
	var model := packed.instantiate() as Node3D
	var bounds := _bounds_for(path, model)
	# Imported origins vary. Ground the actual lowest mesh point after scaling;
	# otherwise a small source offset becomes a large floating gap on trees.
	model.position = Vector3(pos.x, pos.y - bounds.position.y * model_scale, pos.z)
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
