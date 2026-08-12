class_name Player
extends CharacterBody3D
## AFTERLIGHT first-person player controller.
## Walk, sprint, crouch, CRAWL, slide, jump, vault, mantle, ladders, stamina,
## head bob, surface-based 3D footsteps, exhausted breathing, interaction.
## Builds its own children in code: collider, head, camera, and components.

signal health_changed(current: int, maximum: int)
signal notify(text: String)
signal interaction_prompt(text: String)
signal died

enum Stance { STAND, CROUCH, CRAWL }

const MAX_HEALTH := 100

const WALK_SPEED := 4.6
const SPRINT_SPEED := 7.8
const CROUCH_SPEED := 2.4
const CRAWL_SPEED := 1.4
const SLIDE_START_SPEED := 9.2
const JUMP_VELOCITY := 4.8
const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.12
const VAULT_VELOCITY := 4.3
const LADDER_CLIMB_SPEED := 3.0
const LADDER_REGRAB_DELAY := 0.3
const ACCEL_GROUND := 11.0
const ACCEL_AIR := 3.0
const MOUSE_SENSITIVITY := 0.0022

const STEP_HEIGHT := 0.55
const STEP_RAISE := 0.75
const BOOM_LEN := 3.4
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.15
const CRAWL_HEIGHT := 0.7
const EYE_STAND := 1.62
const EYE_CROUCH := 1.05
const EYE_CRAWL := 0.5
const EYE_SLIDE := 0.72
const BODY_FIT_FLOOR_EPSILON := 0.04
# Quaternius models are authored with their soles at y ~= 0. The previous
# mannequin needed +0.24 m, which made the replacement character hover.
const BODY_VISUAL_Y_OFFSET := 0.0

const SPRINT_DRAIN_PER_SEC := 11.0
const JUMP_COST := 8.0
const SLIDE_COST := 6.0
const WALL_JUMP_COST := 8.0
const HANG_DRAIN_PER_SEC := 4.0
const FALL_HURT_SPEED := 9.0
const ROLL_SAFE_SPEED := 15.0

const STEP_STRIDE_WALK := 2.1
const STEP_STRIDE_SPRINT := 2.7
const STEP_STRIDE_CROUCH := 1.6
const STEP_STRIDE_CRAWL := 1.1

var health: int = MAX_HEALTH
var ui_lock := false  # true while the inventory panel is open
var stance: Stance = Stance.STAND
var is_sliding := false

var head: Node3D
var camera: CameraController
var stamina: StaminaController
var footsteps: FootstepController
var interaction: InteractionController
var weapons: WeaponManager
var inventory: Node
const InventoryScript := preload("res://scripts/items/inventory.gd")

var _gravity: float = 9.8
var _collider: CollisionShape3D
var _capsule: CapsuleShape3D
var _slide_time_left := 0.0
var _slide_dir := Vector3.ZERO
var _was_on_floor := true
var _coyote_left := 0.0
var _jump_buffer_left := 0.0
var _last_fall_speed := 0.0
var _step_distance := 0.0
var _floor_surface := "concrete"
var _ladders := 0
var _ladder_regrab_left := 0.0
var _climb_dist := 0.0
var _mantling := false
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _mantle_t := 0.0
var _vault_cd := 0.0
var _breath: AudioStreamPlayer
var _hurt: AudioStreamPlayer
var _snd_pickup: AudioStreamPlayer
var _snd_bandage: AudioStreamPlayer
var _snd_heart: AudioStreamPlayer
var _third_person := true
var _boom := 0.0
var _tp_weapons: Array[Node3D] = []
var _anim: AnimationPlayer
var _anim_state := ""
var _tp_parts: Array[Node3D] = []
var _last_safe := Vector3(0, 0.5, 8)
var _safe_timer := 0.0
var _heart_cd := 0.0
var _dead := false
var _body: Node3D
var _audio_environments: Array[Dictionary] = []
var _look_pitch := 0.0

var is_hanging := false
var _ledge_y := 0.0
var _ledge_normal := Vector3.ZERO
var _hang_regrab_cd := 0.0
var _shimmy_dist := 0.0
var _last_wall_normal := Vector3.ZERO
var _flow_timer := 0.0
var _snd_grab: AudioStreamPlayer
var _snd_shimmy: AudioStreamPlayer
var _snd_kick: AudioStreamPlayer
var _snd_roll: AudioStreamPlayer


func _ready() -> void:
	set_process_input(true)
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	collision_layer = 2
	collision_mask = 1 | 4
	add_to_group("player")

	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.34
	_capsule.height = STAND_HEIGHT
	_collider = CollisionShape3D.new()
	_collider.shape = _capsule
	_collider.position = Vector3(0, STAND_HEIGHT * 0.5, 0)
	add_child(_collider)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, EYE_STAND, 0)
	add_child(head)

	camera = CameraController.new()
	head.add_child(camera)
	camera.setup()
	floor_snap_length = 0.6

	stamina = StaminaController.new()
	add_child(stamina)

	# Start in third-person view (V still switches to first-person)
	_boom = BOOM_LEN

	footsteps = FootstepController.new()
	add_child(footsteps)

	interaction = InteractionController.new()
	camera.add_child(interaction)
	interaction.add_exception(self)
	interaction.focus_changed.connect(func(prompt: String) -> void:
		interaction_prompt.emit(prompt))

	inventory = InventoryScript.new()
	add_child(inventory)
	inventory.add_item("bandage", 1)
	inventory.add_item("ammo_pistol", 24)
	inventory.add_item("ammo_rifle", 30)

	weapons = WeaponManager.new()
	camera.add_child(weapons)
	weapons.setup(self)

	_build_body()
	if _third_person:
		weapons.visible = false
		for part in _tp_parts:
			part.visible = true
	weapons.weapon_switched.connect(func(_i: int) -> void: _sync_tp_weapon())
	weapons.action_played.connect(play_action_anim)
	_sync_tp_weapon()

	_hurt = AudioStreamPlayer.new()
	_hurt.stream = load("res://assets/audio/player_hurt.wav")
	_hurt.volume_db = -4.0
	add_child(_hurt)

	_snd_grab = _make_snd("hand_grab", -6.0)
	_snd_shimmy = _make_snd("hand_shimmy", -12.0)
	_snd_kick = _make_snd("wall_kick", -6.0)
	_snd_roll = _make_snd("roll", -6.0)

	# Heavy breathing when exhausted
	_breath = AudioStreamPlayer.new()
	var bs: AudioStreamWAV = load("res://assets/audio/breath_loop.wav")
	bs.loop_mode = AudioStreamWAV.LOOP_FORWARD
	bs.loop_end = bs.data.size() / 2
	_breath.stream = bs
	_breath.volume_db = -80.0
	add_child(_breath)
	stamina.exhausted_changed.connect(_on_exhausted)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_look_pitch = head.rotation.x


func _input(event: InputEvent) -> void:
	## Mouse look lives in _input (not _unhandled_input) so UI elements can
	## never swallow mouse motion while the cursor is captured.
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
			and not get_tree().paused and not ui_lock:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and not get_tree().paused and not ui_lock:
		var sens := MOUSE_SENSITIVITY * GameSettings.mouse_sensitivity
		var y_dir := 1.0 if GameSettings.invert_y else -1.0
		rotation.y -= event.relative.x * sens
		_look_pitch = clampf(_look_pitch + event.relative.y * sens * y_dir,
				deg_to_rad(-85.0), deg_to_rad(85.0))
		head.rotation.x = _look_pitch


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		interaction.try_interact(self)


func _physics_process(delta: float) -> void:
	_update_heartbeat(delta)
	_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)
	_ladder_regrab_left = maxf(0.0, _ladder_regrab_left - delta)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_left = JUMP_BUFFER_TIME
	if _dead:
		# Dead: no control, just settle to the ground
		if not is_on_floor():
			velocity.y -= _gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		move_and_slide()
		return
	if _mantling:
		_update_mantle(delta)
		return
	if is_hanging:
		_update_hang(delta)
		return
	_vault_cd = maxf(0.0, _vault_cd - delta)
	_hang_regrab_cd = maxf(0.0, _hang_regrab_cd - delta)
	_flow_timer = maxf(0.0, _flow_timer - delta)

	# --- Ladder climbing ---
	if _ladders > 0:
		_ladder_move(delta)
		move_and_slide()
		return

	var on_floor := is_on_floor()
	if on_floor:
		_coyote_left = COYOTE_TIME
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)

	# --- Gravity and landing ---
	if not on_floor:
		velocity.y -= _gravity * delta
		_last_fall_speed = maxf(_last_fall_speed, -velocity.y)
	elif not _was_on_floor:
		if _last_fall_speed > 3.0:
			camera.on_landed(_last_fall_speed)
			footsteps.play_land(_floor_surface, _last_fall_speed > 7.0)
		if _last_fall_speed > FALL_HURT_SPEED:
			if Input.is_action_pressed("crouch") and _last_fall_speed < ROLL_SAFE_SPEED:
				# Landing roll: no damage, keep your momentum
				_snd_roll.play()
				camera.on_landed(_last_fall_speed * 0.6)
				_flow_timer = 1.5
			else:
				take_damage(int((_last_fall_speed - FALL_HURT_SPEED) * 9.0))
				velocity.x *= 0.4
				velocity.z *= 0.4
		_last_fall_speed = 0.0
		_wall_jumps_reset()
	_was_on_floor = on_floor

	# --- Stance state machine (stand / crouch / crawl / slide) ---
	var wants_crouch := Input.is_action_pressed("crouch")
	var sprint_held := Input.is_action_pressed("sprint")
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var clearance := _clearance()
	var can_stand := _body_fits_at(global_position, STAND_HEIGHT)
	var can_crouch := _body_fits_at(global_position, CROUCH_HEIGHT)

	if is_sliding:
		_update_slide(delta)
	elif wants_crouch and on_floor and sprint_held and hspeed > 5.0 and stance == Stance.STAND \
			and Input.is_action_just_pressed("crouch") and stamina.try_spend(SLIDE_COST):
		_start_slide()
	else:
		# Only overhead clearance can force prone. The full capsule fit query can
		# touch floor contact margins and must not lock the player in crawl.
		if clearance < CROUCH_HEIGHT + 0.15:
			stance = Stance.CRAWL          # ceiling too low: forced crawl
		elif wants_crouch:
			if stance == Stance.STAND:
				stance = Stance.CROUCH
			if stance == Stance.CROUCH and on_floor and _low_gap_ahead():
				stance = Stance.CRAWL      # crouched at a low opening: go prone
			elif stance == Stance.CRAWL and can_crouch \
					and not _low_gap_ahead():
				stance = Stance.CROUCH
		else:
			if can_stand:
				stance = Stance.STAND      # room to stand
			elif stance == Stance.CRAWL and can_crouch:
				stance = Stance.CROUCH     # room to at least crouch

	_update_collider(delta)

	# --- Movement ---
	var sprinting := false
	if not is_sliding:
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

		sprinting = sprint_held and stance == Stance.STAND and on_floor \
				and input_dir.y < -0.1 and stamina.can_sprint()
		var target_speed := WALK_SPEED
		match stance:
			Stance.CRAWL:
				target_speed = CRAWL_SPEED
			Stance.CROUCH:
				target_speed = CROUCH_SPEED
			Stance.STAND:
				if sprinting:
					target_speed = SPRINT_SPEED
					stamina.drain(SPRINT_DRAIN_PER_SEC * delta)

		# Flow: chaining parkour moves (vault/roll/wall jump) keeps you faster
		if _flow_timer > 0.0 and sprinting:
			target_speed *= 1.12

		var accel := ACCEL_GROUND if on_floor else ACCEL_AIR
		var target_vel := direction * target_speed
		velocity.x = move_toward(velocity.x, target_vel.x, accel * delta * target_speed)
		velocity.z = move_toward(velocity.z, target_vel.z, accel * delta * target_speed)

		# Buffered/coyote jump: a slightly early or late press still responds.
		# Works from stand, crouch or crawl when there is room to stand.
		if _jump_buffer_left > 0.0 and _coyote_left > 0.0 \
				and (stance == Stance.STAND or can_stand) \
				and stamina.try_spend(JUMP_COST):
			stance = Stance.STAND
			velocity.y = JUMP_VELOCITY
			_jump_buffer_left = 0.0
			_coyote_left = 0.0
			footsteps.play_step(_floor_surface, false, false)

		# Wall jump: airborne, pressing into a wall, alternate walls to climb
		if not on_floor and Input.is_action_just_pressed("jump") and is_on_wall() \
				and stance == Stance.STAND:
			var wn := get_wall_normal()
			if wn.dot(_last_wall_normal) < 0.5 and stamina.try_spend(WALL_JUMP_COST):
				_last_wall_normal = wn
				velocity = wn * 4.6 + Vector3(0, 5.0, 0) \
						+ Vector3(velocity.x, 0, velocity.z) * 0.25
				_snd_kick.play()
				_flow_timer = 1.5

		# Auto-vault low obstacles while sprinting
		if sprinting and on_floor:
			_try_vault()

		# Mantle ledges while airborne, moving forward
		if not on_floor and input_dir.y < -0.1 and velocity.y < 2.0 \
				and stance == Stance.STAND:
			_try_mantle()

		# Ledge grab: catch higher edges mid-air (above mantle reach)
		if not on_floor and input_dir.y < -0.1 and velocity.y < 1.5 \
				and stance == Stance.STAND and not _mantling:
			_try_ledge_grab()

		# Camera motion + footsteps
		camera.update_motion(delta, hspeed, sprinting, on_floor, input_dir.x)
		if on_floor and hspeed > 0.6:
			_step_distance += hspeed * delta
			var stride := STEP_STRIDE_WALK
			if sprinting:
				stride = STEP_STRIDE_SPRINT
			elif stance == Stance.CROUCH:
				stride = STEP_STRIDE_CROUCH
			elif stance == Stance.CRAWL:
				stride = STEP_STRIDE_CRAWL
			if _step_distance >= stride:
				_step_distance = 0.0
				footsteps.play_step(_floor_surface, sprinting, stance != Stance.STAND)
				if sprinting:
					# Sprinting is loud: nearby zombies come to look
					get_tree().call_group("enemies", "hear_noise", global_position, 12.0)
	else:
		camera.update_motion(delta, hspeed, false, on_floor, 0.0)

	_step_up(delta)
	var pre_velocity := velocity
	move_and_slide()
	_update_safety(delta)
	_update_view(delta)
	_update_body(delta)
	_update_floor_surface()
	_check_glass(pre_velocity)


# ---------------------------------------------------------------- stances

func _clearance() -> float:
	## Distance from feet to the ceiling directly above (99 = open sky).
	var from := global_position + Vector3(0, 0.05, 0)
	var to := global_position + Vector3(0, 2.3, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 99.0
	return hit.position.y - global_position.y


func _low_gap_ahead() -> bool:
	## True when facing a crawl-height opening (wall at crouch head height,
	## clear at crawl height).
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_dir.y > -0.1:
		return false
	var fwd := -transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var space := get_world_3d().direct_space_state
	var head_from := global_position + Vector3(0, CROUCH_HEIGHT - 0.1, 0)
	var q1 := PhysicsRayQueryParameters3D.create(head_from, head_from + fwd * 0.9)
	q1.exclude = [get_rid()]
	if space.intersect_ray(q1).is_empty():
		return false
	var low_from := global_position + Vector3(0, 0.35, 0)
	var q2 := PhysicsRayQueryParameters3D.create(low_from, low_from + fwd * 1.2)
	q2.exclude = [get_rid()]
	return space.intersect_ray(q2).is_empty()


func _update_collider(delta: float) -> void:
	var target_height := STAND_HEIGHT
	var target_eye := EYE_STAND
	if is_sliding:
		target_height = CROUCH_HEIGHT
		target_eye = EYE_SLIDE
	elif stance == Stance.CROUCH:
		target_height = CROUCH_HEIGHT
		target_eye = EYE_CROUCH
	elif stance == Stance.CRAWL:
		target_height = CRAWL_HEIGHT
		target_eye = EYE_CRAWL
	_capsule.height = lerpf(_capsule.height, target_height, 12.0 * delta)
	_collider.position.y = _capsule.height * 0.5
	head.position.y = lerpf(head.position.y, target_eye, 12.0 * delta)


# ---------------------------------------------------------------- slide

func _start_slide() -> void:
	is_sliding = true
	stance = Stance.CROUCH
	_slide_time_left = 0.95
	_slide_dir = -transform.basis.z.normalized()
	velocity.x = _slide_dir.x * SLIDE_START_SPEED
	velocity.z = _slide_dir.z * SLIDE_START_SPEED
	footsteps.play_land(_floor_surface, false)


func _update_slide(delta: float) -> void:
	_slide_time_left -= delta
	var decay := 4.2
	velocity.x = move_toward(velocity.x, 0.0, decay * delta * SLIDE_START_SPEED * 0.35)
	velocity.z = move_toward(velocity.z, 0.0, decay * delta * SLIDE_START_SPEED * 0.35)
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if _slide_time_left <= 0.0 or hspeed < 2.2 or not is_on_floor():
		is_sliding = false
		if not Input.is_action_pressed("crouch") \
				and _body_fits_at(global_position, STAND_HEIGHT):
			stance = Stance.STAND


# ---------------------------------------------------------------- parkour

func _try_vault() -> void:
	## Small auto-hop over knee-height obstacles while sprinting.
	if _vault_cd > 0.0:
		return
	var fwd := -transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var space := get_world_3d().direct_space_state
	var knee := global_position + Vector3(0, 0.45, 0)
	var q1 := PhysicsRayQueryParameters3D.create(knee, knee + fwd * 0.95)
	q1.exclude = [get_rid()]
	if space.intersect_ray(q1).is_empty():
		return
	var head_h := global_position + Vector3(0, 1.35, 0)
	var q2 := PhysicsRayQueryParameters3D.create(head_h, head_h + fwd * 1.3)
	q2.exclude = [get_rid()]
	if not space.intersect_ray(q2).is_empty():
		return
	velocity.y = VAULT_VELOCITY
	_vault_cd = 0.7
	_flow_timer = 1.5
	footsteps.play_step(_floor_surface, true, false)


func _try_mantle() -> void:
	## Grab and pull up onto a ledge while airborne.
	var fwd := -transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var space := get_world_3d().direct_space_state
	var chest := global_position + Vector3(0, 1.0, 0)
	var q1 := PhysicsRayQueryParameters3D.create(chest, chest + fwd * 0.9)
	q1.exclude = [get_rid()]
	var wall := space.intersect_ray(q1)
	if wall.is_empty():
		return
	var over: Vector3 = wall.position + fwd * 0.35 + Vector3(0, 1.6, 0)
	var q2 := PhysicsRayQueryParameters3D.create(over, over + Vector3(0, -2.4, 0))
	q2.exclude = [get_rid()]
	var top := space.intersect_ray(q2)
	if top.is_empty():
		return
	if top.normal.y < 0.6:
		return
	var rise: float = top.position.y - global_position.y
	if rise < 0.4 or rise > 1.8:
		return
	var destination: Vector3 = top.position + Vector3(0, 0.05, 0)
	if not _body_fits_at(destination, STAND_HEIGHT):
		return
	_mantle_from = global_position
	_mantle_to = destination
	_mantle_t = 0.0
	_mantling = true
	velocity = Vector3.ZERO
	footsteps.play_step("concrete", false, false)


func _update_mantle(delta: float) -> void:
	_mantle_t += delta / 0.35
	var t := clampf(_mantle_t, 0.0, 1.0)
	var pos := _mantle_from.lerp(_mantle_to, t)
	pos.y += sin(PI * t) * 0.15
	global_position = pos
	camera.update_motion(delta, 0.0, false, false, 0.0)
	if _mantle_t >= 1.0:
		_mantling = false
		var fwd := -transform.basis.z
		fwd.y = 0.0
		velocity = fwd.normalized() * 2.0
		footsteps.play_land(_floor_surface, false)


# ---------------------------------------------------------------- ladders

func enter_ladder() -> void:
	if _ladder_regrab_left > 0.0:
		return
	_ladders += 1


func exit_ladder() -> void:
	_ladders = maxi(0, _ladders - 1)


func _ladder_move(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var climb := -input_dir.y * LADDER_CLIMB_SPEED   # W = up, S = down
	velocity.y = move_toward(velocity.y, climb, 24.0 * delta)
	var side := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)) * 1.6
	velocity.x = move_toward(velocity.x, side.x, 10.0 * delta)
	velocity.z = move_toward(velocity.z, side.z, 10.0 * delta)
	if Input.is_action_just_pressed("jump"):
		var away := transform.basis.z
		away.y = 0.0
		velocity = away.normalized() * 3.0 + Vector3(0, 2.0, 0)
		_ladders = 0
		_ladder_regrab_left = LADDER_REGRAB_DELAY
	_climb_dist += absf(velocity.y) * delta
	if _climb_dist >= 0.75:
		_climb_dist = 0.0
		footsteps.play_ladder()
	camera.update_motion(delta, 0.0, false, false, 0.0)


# ---------------------------------------------------------------- audio/world

func enter_audio_environment(zone_id: int, bus_name: String) -> void:
	## Keep a stack so leaving one of two overlapping rooms does not
	## incorrectly reset audio to outdoors while still inside the other.
	exit_audio_environment(zone_id)
	_audio_environments.append({"id": zone_id, "bus": bus_name})
	_apply_audio_environment()


func exit_audio_environment(zone_id: int) -> void:
	for i in range(_audio_environments.size() - 1, -1, -1):
		if _audio_environments[i]["id"] == zone_id:
			_audio_environments.remove_at(i)
	_apply_audio_environment()


func set_audio_environment(bus_name: String) -> void:
	## Backward-compatible direct setter for older world objects.
	_set_audio_bus(bus_name)


func _apply_audio_environment() -> void:
	var bus_name: String = "Master"
	if not _audio_environments.is_empty():
		bus_name = String(_audio_environments.back()["bus"])
	_set_audio_bus(bus_name)


func _set_audio_bus(bus_name: String) -> void:
	footsteps.set_bus(bus_name)
	if weapons:
		weapons.set_bus(bus_name)


func _body_fits_at(feet_position: Vector3, body_height: float) -> bool:
	## Full capsule query used before scripted moves such as mantling.
	## A ray can miss beams and corners that would overlap the player's body.
	var shape := CapsuleShape3D.new()
	shape.radius = _capsule.radius
	# Keep the test capsule slightly inside the requested volume. A capsule
	# placed exactly at foot level overlaps the floor's physics margin and
	# falsely reports that standing/crouching is blocked on open ground.
	shape.height = maxf(shape.radius * 2.0,
			body_height - BODY_FIT_FLOOR_EPSILON * 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,
			feet_position + Vector3.UP * body_height * 0.5)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _update_floor_surface() -> void:
	var from := global_position + Vector3(0, 0.2, 0)
	var to := global_position + Vector3(0, -1.2, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider is Node:
		_floor_surface = hit.collider.get_meta("surface", "concrete")


func _check_glass(pre_velocity: Vector3) -> void:
	if pre_velocity.length() < 3.0:
		return
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider and collider.is_in_group("breakable_glass"):
			collider.break_glass()
			velocity = pre_velocity   # carry momentum through the window


func _on_exhausted(is_exhausted: bool) -> void:
	var tw := create_tween()
	if is_exhausted:
		_breath.play()
		tw.tween_property(_breath, "volume_db", -8.0, 0.6)
	else:
		tw.tween_property(_breath, "volume_db", -80.0, 1.4)
		tw.tween_callback(_breath.stop)


func _update_heartbeat(delta: float) -> void:
	## Below 30 HP your own pulse thumps - faster the closer you are to death.
	if health >= 30 or health <= 0:
		return
	_heart_cd -= delta
	if _heart_cd > 0.0:
		return
	_heart_cd = lerpf(0.55, 1.0, float(health) / 30.0)
	if _snd_heart == null:
		_snd_heart = _make_snd("heartbeat", -6.0)
	_snd_heart.pitch_scale = 1.0
	_snd_heart.play()


func take_damage(amount: int) -> void:
	if _dead:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	_hurt.pitch_scale = randf_range(0.9, 1.1)
	_hurt.play()
	if health <= 0:
		_dead = true
		if weapons:
			weapons.visible = false
		died.emit()


func heal(amount: int) -> void:
	if _dead:
		return
	health = mini(MAX_HEALTH, health + amount)
	health_changed.emit(health, MAX_HEALTH)


## Called by loot crates and world pickups. Returns how many were stored.
func pickup(id: String, count: int) -> int:
	var leftover: int = inventory.add_item(id, count)
	var got := count - leftover
	if got > 0:
		if _snd_pickup == null:
			_snd_pickup = _make_snd("pickup", -6.0)
		_snd_pickup.play()
		var label: String = inventory.DEFS[id]["label"]
		notify.emit("+ %d %s" % [got, label] if got > 1 else "+ %s" % label)
	else:
		notify.emit("INVENTORY FULL")
	return got


## Called by the inventory UI when a slot is clicked.
func use_inventory_slot(slot: int) -> void:
	var it = inventory.slots[slot]
	if it == null or _dead:
		return
	var id: String = it["id"]
	if id == "bandage":
		if health >= MAX_HEALTH:
			notify.emit("HEALTH ALREADY FULL")
			return
		heal(35)
		if _snd_bandage == null:
			_snd_bandage = _make_snd("bandage_use", -4.0)
		_snd_bandage.play()
		inventory.consume(slot, 1)
		notify.emit("BANDAGED  +35 HP")
	elif inventory.DEFS[id].get("melee", false):
		weapons.equip_melee(slot)
		notify.emit("%s EQUIPPED" % inventory.DEFS[id]["label"])
	elif id.begins_with("ammo_"):
		notify.emit("USED AUTOMATICALLY WHEN RELOADING")
	else:
		notify.emit("CRAFTING MATERIAL - USE THE CRAFT LIST ON THE RIGHT")


## Called by the crafting UI.
func craft_recipe(recipe_idx: int) -> void:
	var fail: String = inventory.craft(recipe_idx)
	if fail != "":
		notify.emit(fail)
		return
	var r: Dictionary = inventory.RECIPES[recipe_idx]
	if _snd_pickup == null:
		_snd_pickup = _make_snd("pickup", -6.0)
	_snd_pickup.play()
	notify.emit("CRAFTED %s" % inventory.DEFS[r["id"]]["label"])


# ---------------------------------------------------------------- body

func _step_up(delta: float) -> void:
	## Walk straight up stairs and low ledges (no jumping needed).
	## Method: raise a ghost copy of the body, slide it forward as far as
	## physics allows, then drop it onto whatever is below. If that landing
	## is a step-sized rise onto a walkable surface, teleport there.
	if not is_on_floor():
		return
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length_squared() < 0.04:
		return
	var fwd := flat.normalized()
	var probe := 0.45 + maxf(flat.length() * delta, 0.1)
	var params := PhysicsTestMotionParameters3D.new()
	var res := PhysicsTestMotionResult3D.new()
	# 1) Is something actually blocking us at ground level?
	params.from = global_transform
	params.motion = fwd * probe
	if not PhysicsServer3D.body_test_motion(get_rid(), params, res):
		return
	# 2) From raised height, how far forward can we travel?
	params.from = global_transform.translated(Vector3.UP * STEP_RAISE)
	var blocked := PhysicsServer3D.body_test_motion(get_rid(), params, res)
	var fwd_travel: Vector3 = res.get_travel() if blocked else params.motion
	fwd_travel.y = 0.0
	if fwd_travel.length() < 0.08:
		return  # a real wall
	# 3) Drop down onto the step surface. The full forward travel can leave
	# the capsule clipping the corner of the NEXT step, so try a few
	# distances and take the first clean landing.
	var max_fwd := fwd_travel.length()
	for frac in [1.0, 0.85, 0.7, 0.55, 0.4]:
		var dist: float = max_fwd * frac
		if dist < 0.08:
			continue
		var step_fwd := fwd * dist
		params.from = global_transform.translated(Vector3.UP * STEP_RAISE + step_fwd)
		params.motion = Vector3.DOWN * STEP_RAISE
		if not PhysicsServer3D.body_test_motion(get_rid(), params, res):
			continue  # nothing to land on at this distance
		var rise := STEP_RAISE + res.get_travel().y
		if rise < 0.04 or rise > STEP_HEIGHT:
			continue
		if res.get_collision_normal().y < 0.7:
			continue  # corner or steep slope - try a shorter hop
		global_position += step_fwd + Vector3.UP * (rise + 0.02)
		return


func _update_safety(delta: float) -> void:
	## Remember the last solid ground; if you ever fall out of the world,
	## climb back instead of falling forever.
	_safe_timer -= delta
	var valid_surface_height := global_position.y > -0.5 \
			or global_position.x <= 510.0
	if is_on_floor() and _safe_timer <= 0.0 and valid_surface_height:
		_safe_timer = 0.5
		_last_safe = global_position
	var beneath_mountain := global_position.x > 510.0 \
			and absf(global_position.z) < 730.0 \
			and global_position.y < -1.0 and global_position.y > -10.0
	if global_position.y < -30.0 or beneath_mountain:
		if _last_safe.x > 510.0 and _last_safe.y < -0.5:
			_last_safe = Vector3(500.0, 0.3, 300.0)
		global_position = _last_safe + Vector3(0, 0.6, 0)
		velocity = Vector3.ZERO
		notify.emit("YOU CRAWL BACK TO SOLID GROUND")


func _update_view(delta: float) -> void:
	## First/third person toggle (V) with a collision-aware camera boom.
	if Input.is_action_just_pressed("toggle_view"):
		_third_person = not _third_person
		weapons.visible = not _third_person
		for part in _tp_parts:
			part.visible = _third_person
		_sync_tp_weapon()
	_boom = lerpf(_boom, BOOM_LEN if _third_person else 0.0, 10.0 * delta)
	if _boom < 0.05:
		camera.position = Vector3.ZERO
		interaction.target_position = Vector3(0, 0, -interaction.REACH)
		return
	# Pull the camera in when a wall is behind the player
	var want_local := Vector3(0.4, 0.25, _boom)
	var want_global := head.global_transform * want_local
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(head.global_position, want_global, 1)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	var f := 1.0
	if not hit.is_empty():
		f = maxf(head.global_position.distance_to(hit.position) - 0.25, 0.0) \
				/ head.global_position.distance_to(want_global)
	camera.position = want_local * f
	interaction.target_position = Vector3(0, 0, -(interaction.REACH + _boom * f))
	# Hide the body if the camera got pushed right up against the head
	_body.visible = f > 0.35


func _build_body() -> void:
	## Third-person body: fully clothed CC0 Quaternius character.
	_body = Node3D.new()
	add_child(_body)
	var rig_scene: PackedScene = load("res://assets/characters/quaternius_modular_men/glTF/Casual_Hoodie.gltf")
	var rig := rig_scene.instantiate() as Node3D
	rig.position.y = BODY_VISUAL_Y_OFFSET
	rig.rotation.y = PI  # model faces +Z; the player moves toward -Z
	_body.add_child(rig)
	_anim = rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_configure_body_animation_loops()
	_play_body_animation("Idle_Neutral", 0.0)
	_anim_state = "Idle_Neutral"
	var skel: Skeleton3D = rig.find_child("Skeleton3D", true, false)
	# Weapon models attached to the right hand bone
	var att := BoneAttachment3D.new()
	skel.add_child(att)
	att.bone_name = "Wrist.R"
	var holder := Node3D.new()
	holder.position = Vector3(0, 0.07, 0.02)
	holder.rotation = Vector3(PI / 2, 0, 0)
	att.add_child(holder)
	var gunmetal := StandardMaterial3D.new()
	gunmetal.albedo_color = Color(0.15, 0.15, 0.17)
	gunmetal.metallic = 0.6
	gunmetal.roughness = 0.5
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.23, 0.19, 0.14)
	wood.roughness = 0.9
	var tp_pistol := Node3D.new()
	holder.add_child(tp_pistol)
	_tp_box(tp_pistol, Vector3(0.055, 0.1, 0.28), Vector3(0, 0.05, -0.1), gunmetal)
	_tp_box(tp_pistol, Vector3(0.05, 0.13, 0.075), Vector3(0, -0.04, 0.02), gunmetal)
	_tp_weapons.append(tp_pistol)
	var tp_rifle := Node3D.new()
	holder.add_child(tp_rifle)
	_tp_box(tp_rifle, Vector3(0.06, 0.1, 0.55), Vector3(0, 0.05, -0.18), gunmetal)
	_tp_box(tp_rifle, Vector3(0.05, 0.08, 0.18), Vector3(0, 0.02, 0.2), wood)
	_tp_box(tp_rifle, Vector3(0.045, 0.14, 0.055), Vector3(0, -0.05, -0.05), gunmetal)
	_tp_weapons.append(tp_rifle)
	var tp_pipe := Node3D.new()
	holder.add_child(tp_pipe)
	_tp_box(tp_pipe, Vector3(0.05, 0.05, 0.62), Vector3(0, 0.02, -0.2), gunmetal)
	_tp_weapons.append(tp_pipe)
	_tp_parts.append(rig)
	for part in _tp_parts:
		part.visible = false

func _make_snd(res: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://assets/audio/%s.wav" % res)
	p.volume_db = db
	add_child(p)
	return p


func _wall_jumps_reset() -> void:
	_last_wall_normal = Vector3.ZERO


# ---------------------------------------------------------------- ledge hang

func _try_ledge_grab() -> void:
	## Catch a ledge that is too high to mantle (hands above head) and hang.
	if _hang_regrab_cd > 0.0:
		return
	var fwd := -transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var space := get_world_3d().direct_space_state
	var high := global_position + Vector3(0, 1.5, 0)
	var q1 := PhysicsRayQueryParameters3D.create(high, high + fwd * 0.9)
	q1.exclude = [get_rid()]
	var wall := space.intersect_ray(q1)
	if wall.is_empty() or absf(wall.normal.y) > 0.4:
		return
	var over: Vector3 = wall.position + fwd * 0.3 + Vector3(0, 1.15, 0)
	var q2 := PhysicsRayQueryParameters3D.create(over, over + Vector3(0, -1.35, 0))
	q2.exclude = [get_rid()]
	var top := space.intersect_ray(q2)
	if top.is_empty() or top.normal.y < 0.6:
		return
	var rise: float = top.position.y - global_position.y
	if rise < 1.85 or rise > 2.6:
		return
	is_hanging = true
	velocity = Vector3.ZERO
	_ledge_y = top.position.y
	var n: Vector3 = wall.normal
	n.y = 0.0
	_ledge_normal = n.normalized()
	var wall_point: Vector3 = wall.position
	global_position = Vector3(wall_point.x, _ledge_y - 1.85, wall_point.z) \
			+ _ledge_normal * 0.42
	_shimmy_dist = 0.0
	_snd_grab.play()
	interaction_prompt.emit("SPACE / W  climb up      A / D  shimmy      CTRL  drop")


func _update_hang(delta: float) -> void:
	velocity = Vector3.ZERO
	camera.update_motion(delta, 0.0, false, false, 0.0)
	if not stamina.drain(HANG_DRAIN_PER_SEC * delta):
		_release_hang()
		return
	# Drop
	if Input.is_action_just_pressed("crouch") \
			or Input.is_action_just_pressed("move_back"):
		_release_hang()
		return
	# Climb up
	if Input.is_action_just_pressed("jump") \
			or Input.is_action_just_pressed("move_forward"):
		var stand: Vector3 = global_position - _ledge_normal * 0.6
		stand.y = _ledge_y + 0.05
		var q := PhysicsRayQueryParameters3D.create(
				stand + Vector3(0, 0.25, 0), stand + Vector3(0, 1.6, 0))
		q.exclude = [get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			is_hanging = false
			_mantle_from = global_position
			_mantle_to = stand
			_mantle_t = 0.0
			_mantling = true
			interaction_prompt.emit("")
			_snd_grab.play()
		return
	# Shimmy sideways along the ledge
	var side := Input.get_axis("move_left", "move_right")
	if absf(side) < 0.2:
		return
	var right := transform.basis.x
	var tangent := (right - _ledge_normal * right.dot(_ledge_normal))
	tangent.y = 0.0
	if tangent.length() < 0.05:
		return
	tangent = tangent.normalized()
	var next_pos := global_position + tangent * side * 1.1 * delta
	# The wall and ledge must continue at the new spot
	var space := get_world_3d().direct_space_state
	var from := next_pos + Vector3(0, 1.5, 0)
	var q1 := PhysicsRayQueryParameters3D.create(from, from - _ledge_normal * 0.9)
	q1.exclude = [get_rid()]
	var wall := space.intersect_ray(q1)
	if wall.is_empty():
		return
	var over: Vector3 = wall.position - _ledge_normal * 0.3 + Vector3(0, 1.15, 0)
	var q2 := PhysicsRayQueryParameters3D.create(over, over + Vector3(0, -1.35, 0))
	q2.exclude = [get_rid()]
	var top := space.intersect_ray(q2)
	if top.is_empty() or absf(top.position.y - _ledge_y) > 0.3:
		return
	global_position = Vector3(wall.position.x, _ledge_y - 1.85, wall.position.z) \
			+ _ledge_normal * 0.42
	_shimmy_dist += 1.1 * delta
	if _shimmy_dist >= 0.55:
		_shimmy_dist = 0.0
		_snd_shimmy.play()


func _release_hang() -> void:
	is_hanging = false
	_hang_regrab_cd = 0.5
	velocity = _ledge_normal * 1.6
	interaction_prompt.emit("")


func _tp_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)


func _sync_tp_weapon() -> void:
	if weapons == null:
		return
	var cur := weapons.current_index()
	for i in _tp_weapons.size():
		_tp_weapons[i].visible = _third_person and i == cur


func _update_body(delta: float) -> void:
	# Feet stay planted at the node origin; crouch/crawl posture comes from
	# the rig's Crouch animations instead of sinking the whole mesh.
	_body.visible = true
	_body.position.y = 0.0
	if _anim == null or not _third_person:
		return
	# One-shot actions (shoot/reload/swing) finish before locomotion resumes
	if _anim_state in ["Gun_Shoot", "Idle_Gun_Shoot", "Interact", "Sword_Slash", "Punch_Right"] \
			and _anim.is_playing():
		return
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var next := ""
	var anim_scale := 1.0
	if not is_on_floor():
		next = "Idle_Neutral"
	elif stance != Stance.STAND:
		next = "Walk" if hspeed > 0.3 else "Idle_Neutral"
		if hspeed > 0.3:
			anim_scale = clampf(hspeed / CROUCH_SPEED, 0.7, 1.4)
	elif hspeed > (WALK_SPEED + SPRINT_SPEED) * 0.5:
		next = "Run"
		anim_scale = clampf(hspeed / SPRINT_SPEED, 0.8, 1.3)
	elif hspeed > WALK_SPEED * 0.72:
		next = "Run"
		anim_scale = clampf(hspeed / WALK_SPEED, 0.8, 1.35)
	elif hspeed > 0.3:
		next = "Walk"
		anim_scale = clampf(hspeed / (WALK_SPEED * 0.6), 0.7, 1.4)
	elif weapons != null and weapons.current_index() == 2:
		next = "Idle_Sword"
	elif weapons != null and weapons.current_index() >= 0:
		next = "Idle_Gun"
	else:
		next = "Idle_Neutral"
	if next != _anim_state:
		_anim_state = next
		_play_body_animation(next, 0.25)
	_anim.speed_scale = anim_scale


func play_action_anim(anim_name: String) -> void:
	## Full-body one-shot (shoot/reload/melee) when roughly stationary.
	if _anim == null or not _third_person:
		return
	if Vector2(velocity.x, velocity.z).length() > 1.2 or not is_on_floor():
		return
	var mapped := {
		"Pistol_Shoot": "Gun_Shoot",
		"Pistol_Reload": "Interact",
		"Sword_Attack": "Sword_Slash",
		"Punch_Cross": "Punch_Right",
	}.get(anim_name, anim_name) as String
	if not _anim.has_animation(mapped):
		if _find_body_animation(mapped) == &"":
			return
	_anim_state = mapped
	_anim.speed_scale = 1.0
	_play_body_animation(mapped, 0.1)


func _play_body_animation(animation_name: String, blend := 0.2) -> void:
	var resolved := _find_body_animation(animation_name)
	if resolved != &"":
		_anim.play(resolved, blend)


func _find_body_animation(animation_name: String) -> StringName:
	## Godot may prefix imported glTF clips with a library/model name.
	if _anim == null:
		return &""
	if _anim.has_animation(animation_name):
		return StringName(animation_name)
	for available in _anim.get_animation_list():
		var full_name := String(available)
		if full_name.ends_with("/" + animation_name) \
				or full_name.ends_with("|" + animation_name) \
				or full_name.ends_with(":" + animation_name):
			return available
	return &""


func _configure_body_animation_loops() -> void:
	# These glTF clips do not carry Godot's conventional "_Loop" suffix, so
	# mark locomotion explicitly or it plays once and the character glides.
	var looping_animations: Array[String] = ["Idle", "Idle_Neutral",
			"Idle_Gun", "Idle_Sword", "Walk", "Run", "Run_Back",
			"Run_Left", "Run_Right"]
	for animation_name in looping_animations:
		var resolved := _find_body_animation(animation_name)
		if resolved != &"":
			_anim.get_animation(resolved).loop_mode = Animation.LOOP_LINEAR
