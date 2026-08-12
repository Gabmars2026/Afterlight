extends "res://scripts/vehicles/car.gd"
## Lightweight drivable street bike. It deliberately reuses the proven car
## controller (mouse steering, safe exits, impacts and parking brake) while
## providing its own narrow two-wheel visual.

var _rider_visual: Node3D
var _rider_limbs: Dictionary = {}
var _frame_material: StandardMaterial3D


func _init() -> void:
	body_size = Vector3(0.82, 1.45, 2.35)
	camera_position = Vector3(0, 2.55, 5.4)
	prompt = "Press E to ride"


func _show_driver_while_mounted() -> bool:
	# The normal humanoid has no cycling animation. Hide it while mounted and show
	# the purpose-built articulated cyclist created with the bicycle instead.
	return false


func _vehicle_pose_kind() -> String:
	return "motorcycle"


func _driver_mount_offset() -> Vector3:
	# The player node is foot-anchored. Placing that anchor just above the chassis
	# makes the legs straddle the bike while keeping the torso behind the bars.
	# Lower the intact character so the hips meet the seat. This is intentionally
	# conservative until a motorcycle-specific seated animation is imported.
	return Vector3(0.0, -0.12, 0.3)


func _build_visual() -> void:
	var bike := Node3D.new()
	bike.name = "BicycleVisual"
	# Wheel centres are at y=.42 with a .38 radius. Offset the complete visual
	# by -.04 so tyre bottoms touch the same y=0 plane as the body collider.
	bike.position.y = -0.04
	add_child(bike)

	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.08, 0.3, 0.62)
	paint.metallic = 0.45
	paint.roughness = 0.32
	_frame_material = paint
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.025, 0.028, 0.032)
	dark.roughness = 0.72

	# Recognizable diamond bicycle frame, fork, seat and handlebars.
	_add_tube(bike, Vector3(0, 0.46, 0.72), Vector3(0, 0.92, 0.18), 0.055, paint)
	_add_tube(bike, Vector3(0, 0.92, 0.18), Vector3(0, 0.48, -0.65), 0.055, paint)
	_add_tube(bike, Vector3(0, 0.48, -0.65), Vector3(0, 0.46, 0.72), 0.055, paint)
	_add_tube(bike, Vector3(0, 0.46, 0.72), Vector3(0, 0.46, -0.05), 0.05, paint)
	_add_tube(bike, Vector3(0, 0.46, -0.05), Vector3(0, 0.92, 0.18), 0.05, paint)
	_add_tube(bike, Vector3(0, 0.48, -0.65), Vector3(0, 1.14, -0.78), 0.045, dark)
	_add_bike_box(bike, Vector3(0.95, 0.08, 0.08),
			Vector3(0, 1.14, -0.72), dark)
	_add_bike_box(bike, Vector3(0.48, 0.09, 0.25), Vector3(0, 1.02, 0.35), dark)
	_add_tube(bike, Vector3(-0.33, 0.46, 0.0), Vector3(0.33, 0.46, 0.0), 0.035, dark)

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
	_build_cyclist(bike)


func _add_bike_box(parent: Node3D, size: Vector3, pos: Vector3,
		material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	parent.add_child(mesh_instance)


func _add_tube(parent: Node3D, start: Vector3, finish: Vector3, radius: float,
		material: Material) -> MeshInstance3D:
	var tube := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(finish)
	mesh.radial_segments = 10
	mesh.material = material
	tube.mesh = mesh
	parent.add_child(tube)
	_pose_tube(tube, start, finish)
	return tube


func _pose_tube(tube: MeshInstance3D, start: Vector3, finish: Vector3) -> void:
	tube.position = (start + finish) * 0.5
	var direction := finish - start
	tube.basis = Basis.looking_at(direction.normalized(), Vector3.UP) \
			* Basis(Vector3.RIGHT, PI * 0.5)


func _build_cyclist(bike: Node3D) -> void:
	_rider_visual = Node3D.new()
	_rider_visual.name = "AnimatedCyclist"
	_rider_visual.visible = false
	bike.add_child(_rider_visual)
	var hoodie := StandardMaterial3D.new()
	hoodie.albedo_color = Color(0.22, 0.12, 0.38)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.62, 0.42, 0.28)
	_add_bike_box(_rider_visual, Vector3(0.46, 0.62, 0.3),
			Vector3(0, 1.52, 0.2), hoodie)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.17
	sphere.height = 0.34
	sphere.material = skin
	head.mesh = sphere
	head.position = Vector3(0, 1.98, 0.1)
	_rider_visual.add_child(head)
	for limb in ["thigh_l", "shin_l", "thigh_r", "shin_r",
			"arm_l", "forearm_l", "arm_r", "forearm_r"]:
		var material: Material = hoodie if limb.begins_with("arm") else skin
		_rider_limbs[limb] = _add_tube(_rider_visual, Vector3.ZERO,
				Vector3.UP, 0.065, material)
	_update_cyclist_pose()


func _update_cyclist_pose() -> void:
	if _rider_visual == null:
		return
	_rider_visual.visible = driver != null
	var pedal_left := Vector3(-0.2, 0.46 + sin(_wheel_spin) * 0.18,
			cos(_wheel_spin) * 0.18)
	var pedal_right := Vector3(0.2, 0.46 - sin(_wheel_spin) * 0.18,
			-cos(_wheel_spin) * 0.18)
	var hip_l := Vector3(-0.15, 1.34, 0.28)
	var hip_r := Vector3(0.15, 1.34, 0.28)
	_pose_leg("l", hip_l, pedal_left)
	_pose_leg("r", hip_r, pedal_right)
	var hand_l := Vector3(-0.34, 1.16, -0.72)
	var hand_r := Vector3(0.34, 1.16, -0.72)
	_pose_arm("l", Vector3(-0.22, 1.72, 0.08), hand_l)
	_pose_arm("r", Vector3(0.22, 1.72, 0.08), hand_r)


func _pose_leg(side: String, hip: Vector3, foot: Vector3) -> void:
	var knee := (hip + foot) * 0.5 + Vector3(0, 0.05, -0.28)
	_pose_tube(_rider_limbs["thigh_" + side], hip, knee)
	_pose_tube(_rider_limbs["shin_" + side], knee, foot)


func _pose_arm(side: String, shoulder: Vector3, hand: Vector3) -> void:
	var elbow := (shoulder + hand) * 0.5 + Vector3(0, -0.12, 0.05)
	_pose_tube(_rider_limbs["arm_" + side], shoulder, elbow)
	_pose_tube(_rider_limbs["forearm_" + side], elbow, hand)


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
	_update_cyclist_pose()
