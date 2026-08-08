class_name Player
extends CharacterBody3D
## AFTERLIGHT first-person player controller (Phase 1).
## Walk, sprint, crouch, slide, jump, stamina, head bob, footsteps, interaction.
## Builds its own children in code: collider, head, camera, and component nodes.

signal health_changed(current: int, maximum: int)
signal interaction_prompt(text: String)

const MAX_HEALTH := 100

const WALK_SPEED := 4.6
const SPRINT_SPEED := 7.8
const CROUCH_SPEED := 2.4
const SLIDE_START_SPEED := 9.2
const JUMP_VELOCITY := 4.8
const ACCEL_GROUND := 11.0
const ACCEL_AIR := 3.0
const MOUSE_SENSITIVITY := 0.0022

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.15
const EYE_STAND := 1.62
const EYE_CROUCH := 1.05
const EYE_SLIDE := 0.72

const SPRINT_DRAIN_PER_SEC := 11.0
const JUMP_COST := 8.0
const SLIDE_COST := 6.0

const STEP_STRIDE_WALK := 2.1
const STEP_STRIDE_SPRINT := 2.7

var health: int = MAX_HEALTH
var is_crouching := false
var is_sliding := false

var head: Node3D
var camera: CameraController
var stamina: StaminaController
var footsteps: FootstepController
var interaction: InteractionController

var _gravity: float = 9.8
var _collider: CollisionShape3D
var _capsule: CapsuleShape3D
var _slide_time_left := 0.0
var _slide_dir := Vector3.ZERO
var _was_on_floor := true
var _last_fall_speed := 0.0
var _step_distance := 0.0


func _ready() -> void:
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.35
	_capsule.height = STAND_HEIGHT
	_collider = CollisionShape3D.new()
	_collider.shape = _capsule
	_collider.position = Vector3(0, STAND_HEIGHT * 0.5, 0)
	add_child(_collider)

	head = Node3D.new()
	head.position = Vector3(0, EYE_STAND, 0)
	add_child(head)

	camera = CameraController.new()
	head.add_child(camera)
	camera.setup()

	stamina = StaminaController.new()
	add_child(stamina)

	footsteps = FootstepController.new()
	add_child(footsteps)

	interaction = InteractionController.new()
	camera.add_child(interaction)
	interaction.add_exception(self)
	interaction.focus_changed.connect(func(prompt: String) -> void:
		interaction_prompt.emit(prompt))

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("interact"):
		interaction.try_interact(self)


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	# --- Gravity and landing ---
	if not on_floor:
		velocity.y -= _gravity * delta
		_last_fall_speed = maxf(_last_fall_speed, -velocity.y)
	elif not _was_on_floor:
		if _last_fall_speed > 3.0:
			camera.on_landed(_last_fall_speed)
			footsteps.play_land(_last_fall_speed > 7.0)
		_last_fall_speed = 0.0
	_was_on_floor = on_floor

	# --- Crouch / slide state ---
	var wants_crouch := Input.is_action_pressed("crouch")
	var sprint_held := Input.is_action_pressed("sprint")
	var hspeed := Vector2(velocity.x, velocity.z).length()

	if is_sliding:
		_update_slide(delta)
	elif wants_crouch and on_floor and sprint_held and hspeed > 5.0 \
			and Input.is_action_just_pressed("crouch") and stamina.try_spend(SLIDE_COST):
		_start_slide()
	elif wants_crouch and on_floor:
		is_crouching = true
	elif is_crouching and _can_stand():
		is_crouching = false

	_update_collider(delta)

	# --- Movement ---
	if not is_sliding:
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

		var sprinting := sprint_held and not is_crouching and on_floor \
				and input_dir.y < -0.1 and stamina.can_sprint()
		var target_speed := WALK_SPEED
		if is_crouching:
			target_speed = CROUCH_SPEED
		elif sprinting:
			target_speed = SPRINT_SPEED
			stamina.drain(SPRINT_DRAIN_PER_SEC * delta)

		var accel := ACCEL_GROUND if on_floor else ACCEL_AIR
		var target_vel := direction * target_speed
		velocity.x = move_toward(velocity.x, target_vel.x, accel * delta * target_speed)
		velocity.z = move_toward(velocity.z, target_vel.z, accel * delta * target_speed)

		if on_floor and Input.is_action_just_pressed("jump") and not is_crouching \
				and stamina.try_spend(JUMP_COST):
			velocity.y = JUMP_VELOCITY

		# Camera motion + footsteps
		camera.update_motion(delta, hspeed, sprinting, on_floor, input_dir.x)
		if on_floor and hspeed > 0.8:
			_step_distance += hspeed * delta
			var stride := STEP_STRIDE_SPRINT if sprinting else STEP_STRIDE_WALK
			if _step_distance >= stride:
				_step_distance = 0.0
				footsteps.play_step(sprinting)
	else:
		camera.update_motion(delta, hspeed, false, on_floor, 0.0)

	move_and_slide()


func _start_slide() -> void:
	is_sliding = true
	is_crouching = true
	_slide_time_left = 0.95
	_slide_dir = -transform.basis.z.normalized()
	velocity.x = _slide_dir.x * SLIDE_START_SPEED
	velocity.z = _slide_dir.z * SLIDE_START_SPEED
	footsteps.play_land(false)


func _update_slide(delta: float) -> void:
	_slide_time_left -= delta
	var decay := 4.2
	velocity.x = move_toward(velocity.x, 0.0, decay * delta * SLIDE_START_SPEED * 0.35)
	velocity.z = move_toward(velocity.z, 0.0, decay * delta * SLIDE_START_SPEED * 0.35)
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if _slide_time_left <= 0.0 or hspeed < 2.2 or not is_on_floor():
		is_sliding = false
		if not Input.is_action_pressed("crouch") and _can_stand():
			is_crouching = false


func _update_collider(delta: float) -> void:
	var target_height := STAND_HEIGHT
	var target_eye := EYE_STAND
	if is_sliding:
		target_height = CROUCH_HEIGHT
		target_eye = EYE_SLIDE
	elif is_crouching:
		target_height = CROUCH_HEIGHT
		target_eye = EYE_CROUCH
	_capsule.height = lerpf(_capsule.height, target_height, 12.0 * delta)
	_collider.position.y = _capsule.height * 0.5
	head.position.y = lerpf(head.position.y, target_eye, 12.0 * delta)


func _can_stand() -> bool:
	var from := global_position + Vector3(0, CROUCH_HEIGHT - 0.1, 0)
	var to := global_position + Vector3(0, STAND_HEIGHT + 0.05, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func take_damage(amount: int) -> void:
	health = maxi(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
