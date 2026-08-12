extends "res://scripts/vehicles/car.gd"
## Lightweight drivable street bike. It deliberately reuses the proven car
## controller (mouse steering, safe exits, impacts and parking brake) while
## providing its own narrow two-wheel visual.


func _init() -> void:
	body_size = Vector3(0.82, 1.45, 2.35)
	camera_position = Vector3(0, 2.55, 5.4)
	prompt = "Press E to ride"


func _show_driver_while_mounted() -> bool:
	# A motorcycle has no cabin: keep the player's clothed third-person body on
	# the bike instead of inheriting the car controller's hidden driver.
	return true


func _vehicle_pose_kind() -> String:
	return "motorcycle"


func _driver_mount_offset() -> Vector3:
	# The player node is foot-anchored. Placing that anchor just above the chassis
	# makes the legs straddle the bike while keeping the torso behind the bars.
	return Vector3(0.0, 0.58, 0.28)


func _build_visual() -> void:
	var bike := Node3D.new()
	bike.name = "MotorcycleVisual"
	# Wheel centres are at y=.42 with a .38 radius. Offset the complete visual
	# by -.04 so tyre bottoms touch the same y=0 plane as the body collider.
	bike.position.y = -0.04
	add_child(bike)

	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.72, 0.08, 0.055)
	paint.metallic = 0.55
	paint.roughness = 0.28
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.025, 0.028, 0.032)
	dark.roughness = 0.72

	_add_bike_box(bike, Vector3(0.62, 0.34, 1.25),
			Vector3(0, 0.72, -0.05), paint)
	_add_bike_box(bike, Vector3(0.48, 0.16, 0.66),
			Vector3(0, 1.02, 0.36), dark)
	_add_bike_box(bike, Vector3(0.95, 0.08, 0.08),
			Vector3(0, 1.14, -0.72), dark)
	_add_bike_box(bike, Vector3(0.1, 0.62, 0.1),
			Vector3(0, 0.72, -0.78), dark)

	for data in [[Vector3(0, 0.42, -0.92), true],
			[Vector3(0, 0.42, 0.92), false]]:
		var wheel := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.38
		cylinder.bottom_radius = 0.38
		cylinder.height = 0.16
		cylinder.radial_segments = 20
		cylinder.material = dark
		wheel.mesh = cylinder
		wheel.position = data[0]
		wheel.rotation.z = PI * 0.5
		bike.add_child(wheel)
		_wheel_meshes.append({
			"mesh": wheel,
			"base_basis": wheel.basis,
			"front": data[1],
		})


func _add_bike_box(parent: Node3D, size: Vector3, pos: Vector3,
		material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	parent.add_child(mesh_instance)


func _animate_wheels(delta: float) -> void:
	# The bike cylinders are turned 90 degrees from the source car wheels. Spin
	# them around the vehicle's X axle before applying their base orientation;
	# using the inherited post-multiply made them rotate sideways like propellers.
	_wheel_spin = fposmod(_wheel_spin + (_speed / WHEEL_RADIUS) * delta, TAU)
	for wheel in _wheel_meshes:
		var mesh := wheel["mesh"] as MeshInstance3D
		var base: Basis = wheel["base_basis"]
		var is_front: bool = wheel["front"]
		var steer_basis := Basis(Vector3.UP,
				_visual_steer if is_front else 0.0)
		mesh.basis = steer_basis * Basis(Vector3.RIGHT, _wheel_spin) * base
