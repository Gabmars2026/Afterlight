class_name Enemy
extends CharacterBody3D
## Zombie AI: patrols, investigates noises (gunshots, glass), chases on
## sight, attacks in melee. Configured by the spawner (Shambler/Stalker).
## States: PATROL -> INVESTIGATE -> CHASE -> ATTACK -> STAGGER/DEAD.

signal died

enum State { PATROL, INVESTIGATE, CHASE, ATTACK, STAGGER, DEAD }

# --- Configuration (set before add_child; defaults = Shambler) ---
var kind := "shambler"
var max_health := 80
var patrol_speed := 1.1
var chase_speed := 3.3
var _base_chase := -1.0
var _base_vision := -1.0
var attack_damage := 14
var attack_interval := 1.3
var vision_range := 22.0
var vision_angle_deg := 75.0
var body_color := Color(0.45, 0.5, 0.38)

var state: State = State.PATROL
var health := 80

var _player: Node3D
var _agent: NavigationAgent3D
var direct_nav := false
var size_mult := 1.0          # visual scale (brutes tower, screamers hunch)
var attack_reach := 2.2
var is_screamer := false      # shrieks: alerts every zombie in 45 m
var is_brute := false         # huge, slow, knocks the player back
var is_climber := false       # leaps up ledges to reach rooftop campers
var is_night_hunter := false  # dormant by day, terrifying by night
var _scream_cd := 0.0
var _climb_cd := 0.0
var _is_night := false
var _is_rain := false  # streamed outskirts: no navmesh, walk straight lines
var _home := Vector3.ZERO
var _gravity := 9.8
var _investigate_pos := Vector3.ZERO
var _last_seen := Vector3.ZERO
var _seen_timer := 99.0       # time since player last seen
var _vision_accum := 0.0
var _retarget_accum := 0.0
var _wait_timer := 0.0
var _attack_cd := 0.0
var _windup := 0.0
var _stagger_left := 0.0
var _growl_timer := 3.0
var _step_accum := 0.0
var _aggro := false

var _mesh_root: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _walk_phase := 0.0
var _voice: AudioStreamPlayer3D
var _growl_player: AudioStreamPlayer3D
var _steps: AudioStreamPlayer3D

var _growls: Array[AudioStream] = []
var _snd_alert: AudioStream
var _snd_attack: AudioStream
var _snd_hurt: AudioStream
var _snd_scream: AudioStream
var _snd_roar: AudioStream
var _snd_death: AudioStream
var _step_sounds: Array[AudioStream] = []


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	_home = global_position
	health = max_health
	_player = get_tree().get_first_node_in_group("player")

	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position = Vector3(0, 0.875, 0)
	add_child(col)

	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.9
	_agent.path_max_distance = 3.0
	add_child(_agent)

	_build_mesh()
	_load_sounds()
	_growl_timer = randf_range(1.0, 5.0)


func _build_mesh() -> void:
	_mesh_root = Node3D.new()
	_mesh_root.scale = Vector3.ONE * size_mult
	add_child(_mesh_root)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = body_color.lightened(0.12)
	skin.roughness = 0.9
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = body_color.darkened(0.4)
	cloth.roughness = 1.0
	var pants := StandardMaterial3D.new()
	pants.albedo_color = body_color.darkened(0.55)
	pants.roughness = 1.0

	# --- Pelvis + torso (belly narrower than chest) ---
	_part(_mesh_root, Vector3(0.34, 0.2, 0.22), Vector3(0, 0.98, 0), pants)
	_part(_mesh_root, Vector3(0.36, 0.34, 0.22), Vector3(0, 1.25, 0), cloth)
	_part(_mesh_root, Vector3(0.44, 0.36, 0.26), Vector3(0, 1.58, 0), cloth)

	# --- Neck + head with eyes and jaw ---
	_part(_mesh_root, Vector3(0.12, 0.1, 0.12), Vector3(0, 1.8, 0), skin)
	_part(_mesh_root, Vector3(0.26, 0.28, 0.26), Vector3(0, 1.99, 0), skin)
	_part(_mesh_root, Vector3(0.2, 0.08, 0.06), Vector3(0, 1.88, -0.12), skin)  # jaw
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.9, 0.85, 0.5)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.75, 0.65, 0.2)
	eye_mat.emission_energy_multiplier = 1.4
	_part(_mesh_root, Vector3(0.05, 0.045, 0.02), Vector3(-0.065, 2.02, -0.135), eye_mat)
	_part(_mesh_root, Vector3(0.05, 0.045, 0.02), Vector3(0.065, 2.02, -0.135), eye_mat)

	# --- Arms: shoulder pivot -> upper arm -> bent forearm -> hand ---
	for data in [[-0.28, true], [0.28, false]]:
		var pivot := Node3D.new()
		pivot.position = Vector3(data[0], 1.68, 0)
		_part(pivot, Vector3(0.12, 0.34, 0.12), Vector3(0, -0.18, 0), cloth)
		var elbow := Node3D.new()
		elbow.position = Vector3(0, -0.36, 0)
		elbow.rotation.x = -0.55
		_part(elbow, Vector3(0.1, 0.3, 0.1), Vector3(0, -0.16, 0), skin)
		_part(elbow, Vector3(0.11, 0.1, 0.13), Vector3(0, -0.36, -0.01), skin)  # hand
		pivot.add_child(elbow)
		pivot.rotation.x = -0.5
		_mesh_root.add_child(pivot)
		if data[1]:
			_arm_l = pivot
		else:
			_arm_r = pivot

	# --- Legs: hip pivot -> thigh -> shin -> foot (swing while walking) ---
	for data in [[-0.12, true], [0.12, false]]:
		var hip := Node3D.new()
		hip.position = Vector3(data[0], 0.92, 0)
		_part(hip, Vector3(0.15, 0.42, 0.16), Vector3(0, -0.21, 0), pants)
		_part(hip, Vector3(0.13, 0.4, 0.14), Vector3(0, -0.62, 0.01), pants)
		_part(hip, Vector3(0.13, 0.09, 0.26), Vector3(0, -0.86, -0.05), cloth)  # foot
		_mesh_root.add_child(hip)
		if data[1]:
			_hip_l = hip
		else:
			_hip_r = hip


func _part(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mi.mesh = box
	mi.position = pos
	parent.add_child(mi)


func _load_sounds() -> void:
	for i in range(1, 4):
		_growls.append(load("res://assets/audio/zombie_growl_%d.wav" % i))
	_snd_alert = load("res://assets/audio/zombie_alert.wav")
	_snd_attack = load("res://assets/audio/zombie_attack.wav")
	_snd_hurt = load("res://assets/audio/zombie_hurt.wav")
	if is_screamer:
		_snd_scream = load("res://assets/audio/screamer_scream.wav")
	if is_brute:
		_snd_roar = load("res://assets/audio/brute_roar.wav")
	_snd_death = load("res://assets/audio/zombie_death.wav")
	for i in range(1, 5):
		_step_sounds.append(load("res://assets/audio/step_%d.wav" % i))

	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 7.0
	_voice.max_distance = 55.0
	_voice.position = Vector3(0, 1.6, 0)
	add_child(_voice)
	_growl_player = AudioStreamPlayer3D.new()
	_growl_player.unit_size = 6.0
	_growl_player.max_distance = 40.0
	_growl_player.position = Vector3(0, 1.6, 0)
	add_child(_growl_player)
	_steps = AudioStreamPlayer3D.new()
	_steps.unit_size = 4.5
	_steps.max_distance = 28.0
	_steps.volume_db = -10.0
	_steps.pitch_scale = 0.8
	add_child(_steps)


func _special_behaviors(delta: float) -> void:
	_climb_cd = maxf(0.0, _climb_cd - delta)
	if state != State.CHASE and state != State.ATTACK:
		return
	if is_screamer:
		_scream_cd -= delta
		if _scream_cd <= 0.0 and _player_alive():
			_scream_cd = 8.0
			_voice.stream = _snd_scream
			_voice.pitch_scale = randf_range(0.95, 1.1)
			_voice.play()
			get_tree().call_group("enemies", "hear_noise",
					_player.global_position, 45.0)
	if is_climber and _climb_cd <= 0.0 and is_on_floor() and _player_alive():
		var dy := _player.global_position.y - global_position.y
		var flat := _player.global_position - global_position
		flat.y = 0.0
		if dy > 1.4 and flat.length() < 5.5:
			_climb_cd = 3.0
			velocity = flat.normalized() * chase_speed * 0.9
			velocity.y = 9.5


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta

	_attack_cd = maxf(0.0, _attack_cd - delta)
	_seen_timer += delta
	_growl_timer -= delta
	if _growl_timer <= 0.0:
		_growl_timer = randf_range(4.0, 9.0)
		if not _growl_player.playing:
			_growl_player.stream = _growls[randi() % _growls.size()]
			_growl_player.pitch_scale = randf_range(0.85, 1.1)
			_growl_player.play()

	# Vision check ~5x/sec
	_vision_accum += delta
	if _vision_accum >= 0.2:
		_vision_accum = 0.0
		if _can_see_player():
			_last_seen = _player.global_position
			_seen_timer = 0.0
			if state != State.CHASE and state != State.ATTACK:
				_begin_chase()

	match state:
		State.PATROL:
			_do_patrol(delta)
		State.INVESTIGATE:
			_do_investigate(delta)
		State.CHASE:
			_do_chase(delta)
		State.ATTACK:
			_do_attack(delta)
		State.STAGGER:
			_stagger_left -= delta
			velocity.x = 0.0
			velocity.z = 0.0
			if _stagger_left <= 0.0:
				state = State.CHASE if _aggro else State.PATROL

	_special_behaviors(delta)
	move_and_slide()
	_animate(delta)


func _player_alive() -> bool:
	return _player != null and is_instance_valid(_player) and _player.get("health") > 0


func _can_see_player() -> bool:
	if not _player_alive():
		return false
	var to_player: Vector3 = _player.global_position - global_position
	if to_player.length() > vision_range:
		return false
	var facing := -_mesh_root.global_transform.basis.z
	var flat := Vector3(to_player.x, 0, to_player.z).normalized()
	if facing.angle_to(flat) > deg_to_rad(vision_angle_deg):
		return false
	var from := global_position + Vector3(0, 1.6, 0)
	var to: Vector3 = _player.global_position + Vector3(0, 1.2, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == _player


## Called via get_tree().call_group("enemies", "hear_noise", pos, radius).
func hear_noise(pos: Vector3, radius: float) -> void:
	if state == State.DEAD or state == State.CHASE or state == State.ATTACK:
		return
	if _is_rain:
		radius *= 0.6
	if global_position.distance_to(pos) <= radius:
		_investigate_pos = pos
		state = State.INVESTIGATE
		_wait_timer = 0.0
		_agent.target_position = pos


func _begin_chase() -> void:
	state = State.CHASE
	if not _aggro:
		_aggro = true
		# Pack behavior: nearby zombies come to look
		get_tree().call_group("enemies", "hear_noise", global_position, 12.0)
		_voice.stream = _snd_roar if is_brute else _snd_alert
		_voice.pitch_scale = randf_range(0.9, 1.1)
		_voice.play()


func _do_patrol(delta: float) -> void:
	_wait_timer -= delta
	if _agent.is_navigation_finished():
		if _wait_timer <= 0.0:
			_wait_timer = randf_range(2.0, 5.0)
			var angle := randf() * TAU
			var target := _home + Vector3(cos(angle), 0, sin(angle)) * randf_range(3.0, 9.0)
			_agent.target_position = target
		_stop_walk(delta)
	else:
		_walk_towards(delta, patrol_speed)


func _do_investigate(delta: float) -> void:
	if _agent.is_navigation_finished():
		_wait_timer += delta
		_stop_walk(delta)
		if _wait_timer > 3.0:
			state = State.PATROL
			_wait_timer = 0.0
	else:
		_walk_towards(delta, patrol_speed * 1.8)


func _do_chase(delta: float) -> void:
	if not _player_alive():
		state = State.PATROL
		return
	_retarget_accum += delta
	if _retarget_accum >= 0.3:
		_retarget_accum = 0.0
		_agent.target_position = _player.global_position if _seen_timer < 1.0 else _last_seen
	# Lost the player for too long -> go look at last seen spot
	if _seen_timer > 7.0:
		_investigate_pos = _last_seen
		state = State.INVESTIGATE
		_agent.target_position = _investigate_pos
		return
	var dist: float = global_position.distance_to(_player.global_position)
	if dist < 1.7 and _seen_timer < 0.6:
		state = State.ATTACK
		_windup = 0.0
		return
	_walk_towards(delta, chase_speed)


func _do_attack(delta: float) -> void:
	if not _player_alive():
		state = State.PATROL
		return
	velocity.x = 0.0
	velocity.z = 0.0
	var to_player: Vector3 = _player.global_position - global_position
	var dist := to_player.length()
	if dist > 2.2:
		state = State.CHASE
		return
	# Face the player
	var yaw := atan2(-to_player.x, -to_player.z)
	_mesh_root.rotation.y = lerp_angle(_mesh_root.rotation.y, yaw, 10.0 * delta)
	if _attack_cd > 0.0:
		return
	_windup += delta
	# Wind-up: arms raise, then strike
	var raise := clampf(_windup / 0.35, 0.0, 1.0)
	_arm_l.rotation.x = -0.5 - raise * 1.2
	_arm_r.rotation.x = -0.5 - raise * 1.2
	if _windup >= 0.35:
		_windup = 0.0
		_attack_cd = attack_interval
		_voice.stream = _snd_attack
		_voice.pitch_scale = randf_range(0.9, 1.15)
		_voice.play()
		_arm_l.rotation.x = 0.3
		_arm_r.rotation.x = 0.3
		if dist < attack_reach:
			_player.take_damage(attack_damage)
			if is_brute:
				var shove := _player.global_position - global_position
				shove.y = 0.0
				_player.velocity += shove.normalized() * 8.0 + Vector3.UP * 3.5


func _walk_towards(delta: float, speed: float) -> void:
	var next := _agent.target_position if direct_nav \
			else _agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		_stop_walk(delta)
		return
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	var yaw := atan2(-dir.x, -dir.z)
	_mesh_root.rotation.y = lerp_angle(_mesh_root.rotation.y, yaw, 8.0 * delta)
	# Footsteps
	_step_accum += speed * delta
	if _step_accum >= 0.85:
		_step_accum = 0.0
		if not _steps.playing:
			_steps.stream = _step_sounds[randi() % _step_sounds.size()]
			_steps.play()


func _stop_walk(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 0.5)
	velocity.z = move_toward(velocity.z, 0.0, 0.5)


func _animate(delta: float) -> void:
	if state == State.ATTACK or state == State.DEAD:
		return
	# Shuffling arm sway while moving
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var t := Time.get_ticks_msec() / 1000.0
	var sway := sin(t * 5.0 + float(get_instance_id() % 10)) * clampf(hspeed / 3.0, 0.0, 1.0)
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -0.5 + sway * 0.25, 6.0 * delta)
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -0.5 - sway * 0.25, 6.0 * delta)
	# Shambling leg swing
	_walk_phase += hspeed * delta * 2.6
	var amp := clampf(hspeed / 3.0, 0.0, 1.0) * 0.5
	_hip_l.rotation.x = sin(_walk_phase) * amp
	_hip_r.rotation.x = -sin(_walk_phase) * amp


## Called by WeaponManager raycast hits (and later, melee).
func take_hit(damage: int, _point: Vector3) -> void:
	if state == State.DEAD:
		return
	health -= damage
	_voice.stream = _snd_hurt
	_voice.pitch_scale = randf_range(0.85, 1.1)
	_voice.play()
	# Getting shot alerts the zombie to your position
	if _player_alive():
		_last_seen = _player.global_position
		_seen_timer = 0.0
		_begin_chase()
	if health <= 0:
		_die()
	else:
		state = State.STAGGER
		_stagger_left = 0.28
		var tween := create_tween()
		tween.tween_property(_mesh_root, "rotation:x", -0.12, 0.08)
		tween.tween_property(_mesh_root, "rotation:x", 0.0, 0.18)


func _die() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 1
	_voice.stream = _snd_death
	_voice.pitch_scale = randf_range(0.9, 1.1)
	_voice.play()
	var tween := create_tween()
	tween.tween_property(_mesh_root, "rotation:x", deg_to_rad(-88.0), 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(4.0)
	tween.tween_property(_mesh_root, "position:y", -1.2, 2.0)
	tween.tween_callback(queue_free)
	get_tree().call_group("quest_listeners", "on_enemy_killed")
	died.emit()


func set_night(night: bool) -> void:
	_is_night = night
	_apply_senses()


func set_rain(raining: bool) -> void:
	## Rain muffles sight a little - and hearing a lot.
	_is_rain = raining
	_apply_senses()


func _apply_senses() -> void:
	## Bases are captured on first call so repeated flips never compound.
	if _base_chase < 0.0:
		_base_chase = chase_speed
		_base_vision = vision_range
	if is_night_hunter:
		chase_speed = _base_chase * (1.9 if _is_night else 0.65)
		vision_range = (_base_vision * 2.1 if _is_night else 5.0) \
				* (0.8 if _is_rain else 1.0)
	else:
		chase_speed = _base_chase * (1.35 if _is_night else 1.0)
		vision_range = _base_vision * (1.45 if _is_night else 1.0) \
				* (0.8 if _is_rain else 1.0)
