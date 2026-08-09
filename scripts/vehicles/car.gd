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

var prompt := "Press E to drive"

var driver: Node3D = null
var _speed := 0.0
var _cam: Camera3D
var _engine: AudioStreamPlayer3D
var _lights: Array = []
var _grace := 0.0
var _saved_layer := 0
var _saved_mask := 0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("vehicle")
	collision_layer = 1
	collision_mask = 1 | 4
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 1.3, 3.8)
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
	_cam.position = Vector3(0, 3.4, 7.8)
	_cam.rotation.x = -0.24
	_cam.current = false
	add_child(_cam)


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
	# The Muscle Car model from the M.A.V.S pack (meshes only)
	var visual := CarVisual.build(
			"res://addons/M.A.V.S/Vehicle/Muscle/Muscle Car.tscn")
	visual.name = "Visual"
	visual.position.y = 0.07  # collision box bottom
	add_child(visual)


func get_prompt() -> String:
	return "" if driver != null else prompt


func interact(user: Node) -> void:
	if driver != null or not (user is Node3D):
		return
	driver = user
	_saved_layer = driver.collision_layer
	_saved_mask = driver.collision_mask
	driver.collision_layer = 0
	driver.collision_mask = 0
	driver.visible = false
	driver.process_mode = Node.PROCESS_MODE_DISABLED
	_cam.make_current()
	_engine.pitch_scale = 0.7
	_engine.play()
	for l in _lights:
		l.light_energy = 1.6
	_grace = 0.4


func _exit_car() -> void:
	var out := global_position + global_transform.basis.x * 2.2 + Vector3(0, 0.6, 0)
	driver.process_mode = Node.PROCESS_MODE_INHERIT
	driver.visible = true
	driver.collision_layer = _saved_layer
	driver.collision_mask = _saved_mask
	driver.global_position = out
	driver.velocity = Vector3.ZERO
	if driver.get("camera") is Camera3D:
		(driver.get("camera") as Camera3D).make_current()
	driver = null
	_engine.stop()
	for l in _lights:
		l.light_energy = 0.0


func _physics_process(delta: float) -> void:
	if driver != null:
		_grace = maxf(_grace - delta, 0.0)
		if _grace <= 0.0 and (Input.is_action_just_pressed("interact")
				or Input.is_action_just_pressed("jump")):
			_exit_car()
		else:
			_drive(delta)
	else:
		_speed = move_toward(_speed, 0.0, DRAG * delta)
	# Gravity & motion (also lets an empty car settle on slopes)
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -1.0
	var fwd := -global_transform.basis.z
	velocity.x = fwd.x * _speed
	velocity.z = fwd.z * _speed
	move_and_slide()
	# Ram damage + wall scrub
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other != null and other.has_method("take_hit") and absf(_speed) > 5.0:
			other.take_hit(int(absf(_speed) * 5.0), col.get_position())
			_speed *= 0.72
		elif absf(col.get_normal().dot(fwd)) > 0.7:
			_speed = move_toward(_speed, 0.0, 30.0 * delta)


func _drive(delta: float) -> void:
	# Keep the (disabled) player along for the ride so AI and saves track us
	driver.global_position = global_position + Vector3(0, 0.8, 0)
	var throttle := Input.get_action_strength("move_forward") \
			- Input.get_action_strength("move_back")
	var steer := Input.get_action_strength("move_left") \
			- Input.get_action_strength("move_right")
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
