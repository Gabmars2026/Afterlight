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
const VAULT_VELOCITY := 4.3
const LADDER_CLIMB_SPEED := 3.0
const ACCEL_GROUND := 11.0
const ACCEL_AIR := 3.0
const MOUSE_SENSITIVITY := 0.0022

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.15
const CRAWL_HEIGHT := 0.7
const EYE_STAND := 1.62
const EYE_CROUCH := 1.05
const EYE_CRAWL := 0.5
const EYE_SLIDE := 0.72

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
var _last_fall_speed := 0.0
var _step_distance := 0.0
var _floor_surface := "concrete"
var _ladders := 0
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
var _dead := false
var _body: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _leg_phase := 0.0

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

	stamina = StaminaController.new()
	add_child(stamina)

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


func _input(event: InputEvent) -> void:
	## Mouse look lives in _input (not _unhandled_input) so UI elements can
	## never swallow mouse motion while the cursor is captured.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and not get_tree().paused:
		var sens := MOUSE_SENSITIVITY * GameSettings.mouse_sensitivity
		var y_dir := 1.0 if GameSettings.invert_y else -1.0
		rotate_y(-event.relative.x * sens)
		head.rotate_x(event.relative.y * sens * y_dir)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
			and not get_tree().paused and not ui_lock:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("interact"):
		interaction.try_interact(self)


func _physics_process(delta: float) -> void:
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

	if is_sliding:
		_update_slide(delta)
	elif wants_crouch and on_floor and sprint_held and hspeed > 5.0 and stance == Stance.STAND \
			and Input.is_action_just_pressed("crouch") and stamina.try_spend(SLIDE_COST):
		_start_slide()
	else:
		if clearance < CROUCH_HEIGHT + 0.15:
			stance = Stance.CRAWL          # ceiling too low: forced crawl
		elif wants_crouch:
			if stance == Stance.STAND:
				stance = Stance.CROUCH
			if stance == Stance.CROUCH and on_floor and _low_gap_ahead():
				stance = Stance.CRAWL      # crouched at a low opening: go prone
			elif stance == Stance.CRAWL and clearance >= CROUCH_HEIGHT + 0.15 \
					and not _low_gap_ahead():
				stance = Stance.CROUCH
		else:
			if clearance >= STAND_HEIGHT + 0.1:
				stance = Stance.STAND      # room to stand
			elif stance == Stance.CRAWL and clearance >= CROUCH_HEIGHT + 0.15:
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

		# Jump (standing only)
		if on_floor and Input.is_action_just_pressed("jump") and stance == Stance.STAND \
				and stamina.try_spend(JUMP_COST):
			velocity.y = JUMP_VELOCITY
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

	var pre_velocity := velocity
	move_and_slide()
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
		if not Input.is_action_pressed("crouch") and _clearance() >= STAND_HEIGHT + 0.1:
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
	_mantle_from = global_position
	_mantle_to = top.position + Vector3(0, 0.05, 0)
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
	_climb_dist += absf(velocity.y) * delta
	if _climb_dist >= 0.75:
		_climb_dist = 0.0
		footsteps.play_ladder()
	camera.update_motion(delta, 0.0, false, false, 0.0)


# ---------------------------------------------------------------- audio/world

func set_audio_environment(bus_name: String) -> void:
	## Called by InteriorZone: "Interior"/"Tunnel" = reverberant buses.
	footsteps.set_bus(bus_name)
	if weapons:
		weapons.set_bus(bus_name)


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

func _build_body() -> void:
	## First-person body v2: pelvis, torso, jointed legs with shins and
	## boots - visible when you look down.
	_body = Node3D.new()
	add_child(_body)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.3, 0.33, 0.38)
	cloth.roughness = 1.0
	var pants := StandardMaterial3D.new()
	pants.albedo_color = Color(0.22, 0.24, 0.27)
	pants.roughness = 1.0
	var boots := StandardMaterial3D.new()
	boots.albedo_color = Color(0.16, 0.13, 0.1)
	boots.roughness = 0.95

	var chest := MeshInstance3D.new()
	var cmesh := BoxMesh.new()
	cmesh.size = Vector3(0.4, 0.34, 0.24)
	cmesh.material = cloth
	chest.mesh = cmesh
	chest.position = Vector3(0, 1.32, 0.05)
	_body.add_child(chest)

	var belly := MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(0.34, 0.28, 0.2)
	bmesh.material = cloth
	belly.mesh = bmesh
	belly.position = Vector3(0, 1.06, 0.05)
	_body.add_child(belly)

	var pelvis := MeshInstance3D.new()
	var pmesh := BoxMesh.new()
	pmesh.size = Vector3(0.36, 0.18, 0.21)
	pmesh.material = pants
	pelvis.mesh = pmesh
	pelvis.position = Vector3(0, 0.9, 0.04)
	_body.add_child(pelvis)

	for data in [[-0.11, true], [0.11, false]]:
		var pivot := Node3D.new()
		pivot.position = Vector3(data[0], 0.86, 0.04)
		# Thigh
		var thigh := MeshInstance3D.new()
		var tmesh := BoxMesh.new()
		tmesh.size = Vector3(0.15, 0.44, 0.16)
		tmesh.material = pants
		thigh.mesh = tmesh
		thigh.position = Vector3(0, -0.2, 0)
		pivot.add_child(thigh)
		# Shin
		var shin := MeshInstance3D.new()
		var smesh := BoxMesh.new()
		smesh.size = Vector3(0.13, 0.42, 0.14)
		smesh.material = pants
		shin.mesh = smesh
		shin.position = Vector3(0, -0.61, 0.01)
		pivot.add_child(shin)
		# Boot
		var foot := MeshInstance3D.new()
		var fmesh := BoxMesh.new()
		fmesh.size = Vector3(0.14, 0.1, 0.27)
		fmesh.material = boots
		foot.mesh = fmesh
		foot.position = Vector3(0, -0.83, -0.05)
		pivot.add_child(foot)
		_body.add_child(pivot)
		if data[1]:
			_leg_l = pivot
		else:
			_leg_r = pivot


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


func _update_body(delta: float) -> void:
	# Body follows crouch height; hidden while crawling (no prone rig yet)
	_body.visible = stance != Stance.CRAWL
	_body.position.y = head.position.y - EYE_STAND
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor():
		_leg_phase += hspeed * delta * 2.4
		var amp := clampf(hspeed / SPRINT_SPEED, 0.0, 1.0) * 0.6
		_leg_l.rotation.x = sin(_leg_phase) * amp
		_leg_r.rotation.x = -sin(_leg_phase) * amp
	else:
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.35, 6.0 * delta)
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, 0.15, 6.0 * delta)
