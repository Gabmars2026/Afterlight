extends CharacterBody3D
## Phase 18: a drivable survivor car. Press E to hop in, WASD to drive,
## Space (or E) to get out. Ramming zombies at speed hurts them.

const CarVisual := preload("res://scripts/vehicles/car_visual.gd")

const MAX_FWD := 16.0
const MAX_REV := 6.5
const ENGINE_ACCEL := 8.0
const BRAKE := 22.0
const DRAG := 3.0
const STEER_RATE := 1.9
const IMPACT_COOLDOWN := 0.18
const HEAD_ON_BOUNCE := 0.22
const WHEEL_RADIUS := 0.35
const MAX_VISUAL_STEER := 0.48
const MOUSE_STEER_SENSITIVITY := 0.018
const MOUSE_STEER_RETURN := 1.8

var prompt := "Press E to drive"

var driver: Node3D = null
var _speed := 0.0
var _cam: Camera3D
var _engine: AudioStreamPlayer3D
var _lights: Array = []
var _grace := 0.0
var _saved_layer := 0
var _saved_mask := 0
var _impact_cooldown := 0.0
var _wheel_spin := 0.0
var _visual_steer := 0.0
var _mouse_steer := 0.0
var _wheel_meshes: Array[Dictionary] = []
var _last_safe_position := Vector3.ZERO
var _safe_sample_cooldown := 0.0
var _allow_underground := false
@export var body_size := Vector3(1.9, 1.3, 3.8)
@export var camera_position := Vector3(0, 3.4, 7.8)
@export_enum("Muscle", "NightSky", "Cleo V8", "GT30", "TGR") var visual_kind := 0

const VISUAL_KINDS: Array[String] = [
	"res://addons/M.A.V.S/Vehicle/Muscle/Muscle Car.tscn",
	"res://addons/M.A.V.S/Vehicle/NightSky/NightSky_Body.tscn",
	"res://addons/M.A.V.S/Vehicle/Cleo V8/CleoV8.tscn",
	"res://addons/M.A.V.S/Vehicle/GT30/GT30.tscn",
	"res://addons/M.A.V.S/Vehicle/TGR/TRG.tscn",
]


func _ready() -> void:
	set_process_input(true)
	add_to_group("interactable")
	add_to_group("vehicle")
	collision_layer = 1
	collision_mask = 1 | 4
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = body_size
	col.shape = shape
	col.position.y = 0.72
	add_child(col)
	_build_mesh()
	_engine = AudioStreamPlayer3D.new()
	_engine.stream = load("res://assets/audio/generator_hum.wav")
	_engine.unit_size = 6.0
	_engine.max_distance = 40.0
	add_child(_engine)
	_cam = Camera3D.new()
	_cam.position = camera_position
	_cam.rotation.x = -0.24
	_cam.current = false
	add_child(_cam)
	_last_safe_position = global_position


func _input(event: InputEvent) -> void:
	if driver == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		# Mouse right produces negative steering because positive car yaw is left.
		_mouse_steer = clampf(_mouse_steer
				- motion.relative.x * MOUSE_STEER_SENSITIVITY, -1.0, 1.0)


func _build_mesh() -> void:
	_build_visual()
	for hx in [-0.6, 0.6]:
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(hx, 0.75, -2.0)
		lamp.rotation.x = -0.08
		lamp.light_color = Color(1.0, 0.94, 0.75)
		lamp.light_energy = 0.0
		lamp.spot_range = 26.0
		lamp.spot_angle = 32.0
		add_child(lamp)
		_lights.append(lamp)


func _build_visual() -> void:
	# Selectable models give the clean rebuild a varied drivable vehicle roster.
	var visual := CarVisual.build(VISUAL_KINDS[visual_kind % VISUAL_KINDS.size()])
	visual.name = "Visual"
	visual.position.y = 0.07  # collision box bottom
	add_child(visual)
	for child in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if not mesh.has_meta("car_wheel"):
			continue
		var wheel_name := str(mesh.get_meta("car_wheel"))
		_wheel_meshes.append({
			"mesh": mesh,
			"base_basis": mesh.basis,
			"front": wheel_name.begins_with("LF_") or wheel_name.begins_with("RF_")
		})


func get_prompt() -> String:
	return "" if driver != null else prompt


func teleport_vehicle(target: Vector3, target_yaw: float) -> void:
	## Used by garage transitions. Resetting motion prevents a car from shooting
	## through the back wall with the speed it had when entering.
	global_position = target
	global_rotation = Vector3(0.0, target_yaw, 0.0)
	_speed = 0.0
	velocity = Vector3.ZERO
	_visual_steer = 0.0
	_mouse_steer = 0.0
	# Garage interiors intentionally live below the city. Only portal-driven
	# underground positions bypass the mountain under-surface rescue check.
	_allow_underground = target.y < -1.0
	if driver != null:
		_update_driver_mount()


func interact(user: Node) -> void:
	if driver != null or not (user is Node3D):
		return
	driver = user
	_saved_layer = driver.collision_layer
	_saved_mask = driver.collision_mask
	driver.collision_layer = 0
	driver.collision_mask = 0
	driver.visible = _show_driver_while_mounted()
	driver.process_mode = Node.PROCESS_MODE_DISABLED
	if driver.has_method("set_vehicle_pose"):
		driver.set_vehicle_pose(_vehicle_pose_kind())
	_update_driver_mount()
	_cam.make_current()
	_engine.pitch_scale = 0.7
	_engine.play()
	for l in _lights:
		l.light_energy = 1.6
	_grace = 0.4


func _exit_car() -> bool:
	var out: Variant = _find_safe_exit()
	if out == null:
		if driver != null and driver.has_signal("notify"):
			driver.emit_signal("notify", "NO SAFE SPACE TO EXIT")
		return false
	driver.process_mode = Node.PROCESS_MODE_INHERIT
	if driver.has_method("set_vehicle_pose"):
		driver.set_vehicle_pose("")
	driver.visible = true
	driver.collision_layer = _saved_layer
	driver.collision_mask = _saved_mask
	driver.global_position = out
	driver.velocity = Vector3.ZERO
	# Parking brake: an empty car must not keep rolling after the player exits.
	_speed = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	_visual_steer = 0.0
	if driver.get("camera") is Camera3D:
		(driver.get("camera") as Camera3D).make_current()
	driver = null
	_engine.stop()
	for l in _lights:
		l.light_energy = 0.0
	return true


func _find_safe_exit() -> Variant:
	## Try both sides, then the rear and front. The old implementation always
	## placed the player on the right, even if that position was inside a wall,
	## another car, or solid scenery.
	var directions := [global_transform.basis.x, -global_transform.basis.x,
			global_transform.basis.z, -global_transform.basis.z]
	var space := get_world_3d().direct_space_state
	for direction: Vector3 in directions:
		var candidate := global_position + direction.normalized() * 2.4
		var floor_query := PhysicsRayQueryParameters3D.create(
				candidate + Vector3.UP * 2.0, candidate + Vector3.DOWN * 3.0,
				1 | 4)
		floor_query.exclude = [get_rid(), driver.get_rid()]
		var floor_hit := space.intersect_ray(floor_query)
		if floor_hit.is_empty() or floor_hit.normal.y < 0.65:
			continue
		candidate.y = floor_hit.position.y + 0.05
		if _driver_fits_at(candidate):
			return candidate
	return null


func _driver_fits_at(candidate: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	for child in driver.get_children():
		if not (child is CollisionShape3D) or child.shape == null or child.disabled:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = child.shape
		query.transform = Transform3D(Basis.IDENTITY, candidate) * child.transform
		query.collision_mask = 1 | 4
		query.exclude = [get_rid(), driver.get_rid()]
		if not space.intersect_shape(query, 1).is_empty():
			return false
	return true


func _physics_process(delta: float) -> void:
	# A trimesh edge can occasionally be crossed at speed. Never leave the
	# player trapped beneath the world: remember stable grounded positions and
	# recover the complete vehicle/driver pair if it drops below the map.
	_safe_sample_cooldown = maxf(0.0, _safe_sample_cooldown - delta)
	var manual_recovery: bool = driver != null \
			and Input.is_action_just_pressed("unstuck")
	var beneath_mountain := global_position.x > 510.0 \
			and absf(global_position.z) < 730.0 \
			and global_position.y < -1.0 and not _allow_underground
	var trapped_beside_road: bool = not _allow_underground \
			and _mountain_trap_recovery_needed()
	if manual_recovery or global_position.y < -8.0 or beneath_mountain \
			or trapped_beside_road \
			or (not _allow_underground and _has_mountain_overhead()):
		_recover_from_fall()
		return
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	if driver != null:
		_grace = maxf(_grace - delta, 0.0)
		if _grace <= 0.0 and (Input.is_action_just_pressed("interact")
				or Input.is_action_just_pressed("jump")):
			_exit_car()
		else:
			_drive(delta)
	else:
		_speed = move_toward(_speed, 0.0, BRAKE * delta)
		_visual_steer = move_toward(_visual_steer, 0.0, 4.0 * delta)
	# Gravity & motion (also lets an empty car settle on slopes)
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -1.0
	var fwd := -global_transform.basis.z
	velocity.x = fwd.x * _speed
	velocity.z = fwd.z * _speed
	_animate_wheels(delta)
	move_and_slide()
	var valid_surface_height := global_position.y > -0.5 \
			or global_position.x <= 510.0 or _allow_underground
	if is_on_floor() and valid_surface_height \
			and _safe_sample_cooldown <= 0.0 and absf(velocity.y) < 3.0:
		_last_safe_position = global_position
		_safe_sample_cooldown = 0.35
	# Ram damage + wall scrub
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if _impact_cooldown > 0.0:
			continue
		if other != null and other.has_method("take_hit") and absf(_speed) > 5.0:
			other.take_hit(int(absf(_speed) * 5.0), col.get_position())
			_speed *= 0.78
			_impact_cooldown = IMPACT_COOLDOWN
		else:
			_apply_impact_response(col.get_normal(), fwd)


func _recover_from_fall() -> void:
	# Never recover to another point beneath the mountain. This fixed entrance
	# fallback remains usable even if an earlier bad frame overwrote safe state.
	var rebuild_world: Node = get_tree().get_first_node_in_group("rebuild_world")
	var use_mountain_road: bool = rebuild_world != null \
			and rebuild_world.has_method("mountain_road_recovery_transform") \
			and global_position.x > 500.0
	if use_mountain_road:
		global_transform = rebuild_world.mountain_road_recovery_transform(
				global_position)
		_last_safe_position = global_position
	else:
		if _last_safe_position.x > 510.0 and _last_safe_position.y < -0.5:
			_last_safe_position = Vector3(500.0, 0.3, 300.0)
		if _last_safe_position.x > 510.0 \
				and _has_mountain_overhead_at(_last_safe_position):
			_last_safe_position = Vector3(500.0, 0.3, 300.0)
		global_position = _last_safe_position + Vector3.UP * 1.2
	_speed = 0.0
	velocity = Vector3.ZERO
	_visual_steer = 0.0
	_mouse_steer = 0.0
	_safe_sample_cooldown = 1.0
	_allow_underground = false
	if driver != null:
		_update_driver_mount()
		if driver.has_signal("notify"):
			driver.emit_signal("notify", "VEHICLE RECOVERED TO MOUNTAIN ROAD" \
					if use_mountain_road else "VEHICLE RECOVERED TO SAFE GROUND")


func _mountain_trap_recovery_needed() -> bool:
	var rebuild_world: Node = get_tree().get_first_node_in_group("rebuild_world")
	return rebuild_world != null \
			and rebuild_world.has_method("mountain_trap_recovery_needed") \
			and rebuild_world.mountain_trap_recovery_needed(global_position)


func _has_mountain_overhead() -> bool:
	return _has_mountain_overhead_at(global_position)


func _has_mountain_overhead_at(position: Vector3) -> bool:
	## Detect the mountain shell above a vehicle even when it fell into a pocket
	## whose elevation is still positive. This closes the gap left by Y-only
	## recovery without affecting garages, which explicitly allow underground.
	if position.x <= 520.0 or absf(position.z) >= 720.0:
		return false
	# Do not rescue vehicles that are correctly supported by the mountain road.
	# Its route intentionally has terrain above portions of the switchback.
	var down_query := PhysicsRayQueryParameters3D.create(
			position + Vector3.UP * 0.4, position + Vector3.DOWN * 4.0, 1)
	down_query.exclude = [get_rid()]
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(down_query)
	if not floor_hit.is_empty():
		var floor_collider: Object = floor_hit.get("collider")
		if floor_collider != null and floor_collider.has_meta("surface") \
				and str(floor_collider.get_meta("surface")) == "concrete":
			return false
	var query := PhysicsRayQueryParameters3D.create(
			position + Vector3.UP * 1.0, position + Vector3.UP * 260.0, 1)
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _apply_impact_response(normal: Vector3, forward: Vector3) -> void:
	if absf(_speed) < 0.5:
		return
	var travel_sign := 1.0 if _speed >= 0.0 else -1.0
	var travel_direction := forward * travel_sign
	# Only react when velocity points into the surface. Using abs(dot) made the
	# same obstacle bounce the vehicle again while reversing away from it.
	var into_surface := -normal.dot(travel_direction)
	if into_surface <= 0.05:
		return
	var alignment := clampf(into_surface, 0.0, 1.0)
	if alignment > 0.72:
		# A direct crash gives a short physical-feeling rebound instead of
		# deleting all momentum while the body remains pressed into the wall.
		_speed = -travel_sign * clampf(absf(_speed) * HEAD_ON_BOUNCE, 0.8, 3.5)
	else:
		# move_and_slide() handles the sideways deflection. Retain most speed
		# on a scrape and lose more as the impact approaches head-on.
		_speed *= lerpf(0.96, 0.75, alignment / 0.72)
	_impact_cooldown = IMPACT_COOLDOWN


func _drive(delta: float) -> void:
	# Keep the (disabled) player along for the ride so AI and saves track us
	_update_driver_mount()
	var throttle := Input.get_action_strength("move_forward") \
			- Input.get_action_strength("move_back")
	# Physical-key fallback keeps reverse available if an older project.godot has
	# a stale move_back action with no S-key event.
	if Input.is_physical_key_pressed(KEY_S):
		throttle = -1.0
	var keyboard_steer := Input.get_action_strength("move_left") \
			- Input.get_action_strength("move_right")
	var steer := _mouse_steer if absf(keyboard_steer) < 0.05 else keyboard_steer
	_mouse_steer = move_toward(_mouse_steer, 0.0,
			MOUSE_STEER_RETURN * delta)
	_visual_steer = move_toward(_visual_steer, steer * MAX_VISUAL_STEER, 4.5 * delta)
	if throttle > 0.05:
		if _speed < -0.5:
			_speed = move_toward(_speed, 0.0, BRAKE * delta)
		else:
			_speed = move_toward(_speed, MAX_FWD, ENGINE_ACCEL * delta)
	elif throttle < -0.05:
		if _speed > 0.5:
			_speed = move_toward(_speed, 0.0, BRAKE * delta)
		else:
			_speed = move_toward(_speed, -MAX_REV, ENGINE_ACCEL * 0.7 * delta)
	else:
		_speed = move_toward(_speed, 0.0, DRAG * delta)
	var turn_authority := clampf(absf(_speed) / 7.0, 0.0, 1.0)
	var dir := 1.0 if _speed >= 0.0 else -1.0
	rotation.y += steer * STEER_RATE * turn_authority * dir * delta
	_engine.pitch_scale = 0.7 + absf(_speed) / MAX_FWD * 0.85


func _show_driver_while_mounted() -> bool:
	## Cars hide the player inside their enclosed cabin. Open vehicles override
	## this and keep the third-person character visible.
	return false


func _vehicle_pose_kind() -> String:
	return "car"


func _driver_mount_offset() -> Vector3:
	return Vector3(0, 0.8, 0)


func _update_driver_mount() -> void:
	if driver == null:
		return
	driver.global_position = global_transform * _driver_mount_offset()
	driver.global_rotation = Vector3(0.0, global_rotation.y, 0.0)


func _animate_wheels(delta: float) -> void:
	## Roll every tyre from actual vehicle speed and yaw only the front tyres.
	_wheel_spin = fposmod(_wheel_spin + (_speed / WHEEL_RADIUS) * delta, TAU)
	for wheel in _wheel_meshes:
		var mesh := wheel["mesh"] as MeshInstance3D
		var base: Basis = wheel["base_basis"]
		var is_front: bool = wheel["front"]
		var steer_basis := Basis(Vector3.UP, _visual_steer if is_front else 0.0)
		mesh.basis = steer_basis * base * Basis(Vector3.RIGHT, _wheel_spin)
