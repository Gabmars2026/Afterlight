extends CharacterBody3D
## Phase 20: townsfolk and cops. Civilians stroll the streets; shoot at
## someone and panic spreads - most flee, the brave ones swing back, and
## cops draw guns and hunt you while your WANTED level is up.

const BodyScene := preload("res://Godot/AnimationLibrary_Godot_Standard.glb")

enum State { WANDER, FLEE, FIGHT, DEAD }

const CIV_COLORS := [Color(0.72, 0.6, 0.45), Color(0.5, 0.55, 0.7),
		Color(0.65, 0.45, 0.5), Color(0.55, 0.65, 0.5), Color(0.75, 0.7, 0.55),
		Color(0.6, 0.5, 0.65)]

var is_cop := false
var anchor := Vector3.ZERO
var anchor_radius := 0.0
var brave := false
var health := 60

var state: State = State.WANDER
var _player: Node3D
var _wanted: Node
var _mesh_root: Node3D
var _anim: AnimationPlayer
var _anim_state := ""
var _one_shot_left := 0.0
var _target := Vector3.ZERO
var _wait := 0.0
var _flee_left := 0.0
var _attack_cd := 0.0
var _shoot_cd := 0.0
var _repath := 0.0
var _gravity := 9.8
var _gun: MeshInstance3D
var _flash: OmniLight3D
var _sfx: AudioStreamPlayer3D
var _snd_shot: AudioStream
var _snd_hurt: AudioStream


func _ready() -> void:
	add_to_group("citizens")
	if is_cop:
		add_to_group("cops")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	if is_cop:
		health = 110
		brave = true
	elif randf() < 0.35:
		brave = true
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position = Vector3(0, 0.875, 0)
	add_child(col)
	_player = get_tree().get_first_node_in_group("player")
	_wanted = get_tree().get_first_node_in_group("wanted_manager")
	_build_mesh()
	_snd_shot = load("res://assets/audio/pistol_fire.wav")
	_snd_hurt = load("res://assets/audio/dummy_hit.wav")
	_sfx = AudioStreamPlayer3D.new()
	_sfx.unit_size = 7.0
	_sfx.max_distance = 50.0
	add_child(_sfx)
	_pick_target()


func _build_mesh() -> void:
	_mesh_root = Node3D.new()
	add_child(_mesh_root)
	var rig: Node3D = BodyScene.instantiate()
	rig.rotation.y = PI
	_mesh_root.add_child(rig)
	_anim = rig.find_child("AnimationPlayer", true)
	var mesh: MeshInstance3D = rig.find_child("Mannequin", true)
	if mesh:
		var skin := StandardMaterial3D.new()
		skin.albedo_color = Color(0.12, 0.2, 0.5) if is_cop \
				else CIV_COLORS[randi() % CIV_COLORS.size()]
		skin.roughness = 0.95
		mesh.material_override = skin
	if is_cop:
		# Cap + sidearm so officers read as cops at a glance
		var skel: Skeleton3D = rig.find_child("Skeleton3D", true)
		if skel:
			var head := skel.find_bone("Head")
			if head >= 0:
				var att := BoneAttachment3D.new()
				att.bone_idx = head
				skel.add_child(att)
				var cap_mesh := MeshInstance3D.new()
				var cb := CylinderMesh.new()
				cb.top_radius = 0.13
				cb.bottom_radius = 0.15
				cb.height = 0.1
				var cm := StandardMaterial3D.new()
				cm.albedo_color = Color(0.08, 0.12, 0.3)
				cb.material = cm
				cap_mesh.mesh = cb
				cap_mesh.position.y = 0.14
				att.add_child(cap_mesh)
		_gun = MeshInstance3D.new()
		var gb := BoxMesh.new()
		gb.size = Vector3(0.06, 0.14, 0.34)
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.1, 0.1, 0.1)
		gb.material = gm
		_gun.mesh = gb
		_gun.position = Vector3(0.32, 1.25, -0.3)
		_gun.visible = false
		add_child(_gun)
		_flash = OmniLight3D.new()
		_flash.light_color = Color(1.0, 0.85, 0.5)
		_flash.light_energy = 0.0
		_flash.omni_range = 6.0
		_flash.position = Vector3(0.32, 1.25, -0.55)
		add_child(_flash)


func _play(anim_name: String, blend := 0.25, speed := 1.0) -> void:
	if _anim == null or _anim_state == anim_name:
		return
	_anim_state = anim_name
	_anim.play(anim_name, blend, speed)


func _one_shot(anim_name: String) -> void:
	if _anim == null:
		return
	_anim_state = anim_name
	_anim.play(anim_name, 0.15)
	_one_shot_left = _anim.current_animation_length / \
			maxf(_anim.speed_scale, 0.01)


func _pick_target() -> void:
	if anchor_radius > 0.0:
		_target = anchor + Vector3(randf_range(-anchor_radius, anchor_radius),
				0.0, randf_range(-anchor_radius, anchor_radius))
	else:
		_target = Vector3(randf_range(-66.0, 66.0), 0.1,
				randf_range(-66.0, 66.0))
	_wait = randf_range(2.0, 6.0)


## Gunshots panic nearby civilians and put cops on alert.
func hear_gunshot(pos: Vector3, radius: float) -> void:
	if state == State.DEAD:
		return
	if global_position.distance_to(pos) > radius:
		return
	if is_cop:
		if _wanted and _wanted.heat >= 1.0:
			state = State.FIGHT
	elif state == State.WANDER and not brave:
		_flee_from(pos)


func _flee_from(pos: Vector3) -> void:
	state = State.FLEE
	_flee_left = randf_range(8.0, 14.0)
	var away := global_position - pos
	away.y = 0.0
	if away.length() < 0.5:
		away = Vector3(randf() - 0.5, 0, randf() - 0.5)
	_target = global_position + away.normalized() * 45.0


func take_hit(damage: int, point: Vector3) -> void:
	if state == State.DEAD:
		return
	if point.y > global_position.y + 1.45:
		damage *= 3
	health -= damage
	_sfx.stream = _snd_hurt
	_sfx.play()
	if _wanted:
		_wanted.add_heat(0.6 if not is_cop else 1.2)
	if health <= 0:
		_die()
		return
	if brave:
		state = State.FIGHT
	else:
		_flee_from(_player.global_position if _player else global_position)
	if not is_cop:
		get_tree().call_group("citizens", "hear_gunshot", global_position, 25.0)


func _die() -> void:
	state = State.DEAD
	if _wanted:
		_wanted.add_heat(1.0 if not is_cop else 2.0)
	_one_shot("Death01")
	collision_layer = 0
	collision_mask = 1
	if _flash:
		_flash.light_energy = 0.0
	var tw := create_tween()
	tw.tween_interval(15.0)
	tw.tween_property(_mesh_root, "position:y", -1.6, 2.0)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		if not is_on_floor():
			velocity.y -= _gravity * delta
			move_and_slide()
		return
	_one_shot_left = maxf(_one_shot_left - delta, 0.0)
	if not is_on_floor():
		velocity.y -= _gravity * delta

	# Cops join the hunt whenever heat is up and the player is close
	if is_cop and state != State.FIGHT and _wanted and _wanted.heat >= 1.0 \
			and _player and global_position.distance_to(
			_player.global_position) < 70.0:
		state = State.FIGHT
	if is_cop and state == State.FIGHT and _wanted and _wanted.heat < 0.5:
		state = State.WANDER
	if _gun:
		_gun.visible = state == State.FIGHT

	match state:
		State.WANDER:
			_do_wander(delta)
		State.FLEE:
			_do_flee(delta)
		State.FIGHT:
			_do_fight(delta)
	move_and_slide()
	if is_on_wall() and state != State.FIGHT:
		_repath -= delta
		if _repath <= 0.0:
			_repath = 1.0
			if state == State.WANDER:
				_pick_target()
			else:
				_target += Vector3(randf_range(-14, 14), 0, randf_range(-14, 14))


func _walk_towards(delta: float, speed: float) -> bool:
	## Returns true when close to the target. Direct steering, no navmesh.
	var to_t := _target - global_position
	to_t.y = 0.0
	if to_t.length() < 1.2:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		return true
	var dir := to_t.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_mesh_root.rotation.y = lerp_angle(_mesh_root.rotation.y,
			atan2(-dir.x, -dir.z), 8.0 * delta)
	return false


func _do_wander(delta: float) -> void:
	if _wait > 0.0 and global_position.distance_to(_target) < 1.5:
		_wait -= delta
		velocity.x = 0
		velocity.z = 0
		if _one_shot_left <= 0.0:
			_play("Idle", 0.3, 0.9)
		if _wait <= 0.0:
			_pick_target()
		return
	if _walk_towards(delta, 1.5):
		_wait = randf_range(2.0, 6.0)
	elif _one_shot_left <= 0.0:
		_play("Walk", 0.25, 1.0)


func _do_flee(delta: float) -> void:
	_flee_left -= delta
	if _flee_left <= 0.0:
		state = State.WANDER
		_pick_target()
		return
	_walk_towards(delta, 4.4)
	if _one_shot_left <= 0.0:
		_play("Jog_Fwd", 0.2, 1.2)


func _do_fight(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		state = State.WANDER
		return
	var ppos: Vector3 = _player.global_position
	var d := global_position.distance_to(ppos)
	if d > 80.0:
		state = State.WANDER if is_cop else state
		_pick_target()
		return
	_target = ppos
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_shoot_cd = maxf(_shoot_cd - delta, 0.0)
	var dir := ppos - global_position
	dir.y = 0.0
	if dir.length() > 0.1:
		_mesh_root.rotation.y = lerp_angle(_mesh_root.rotation.y,
				atan2(-dir.x, -dir.z), 8.0 * delta)
	if is_cop and d > 4.0 and d < 26.0 and _shoot_cd <= 0.0 and _sees_player():
		# Stop and fire the sidearm
		velocity.x = 0
		velocity.z = 0
		_shoot_cd = randf_range(1.5, 2.3)
		_flash.light_energy = 2.5
		var tw := create_tween()
		tw.tween_interval(0.08)
		tw.tween_callback(func() -> void: _flash.light_energy = 0.0)
		_sfx.stream = _snd_shot
		_sfx.play()
		# Cops miss a fair bit, especially at range
		if randf() > clampf(d / 30.0, 0.25, 0.75) \
				and _player.has_method("take_damage"):
			_player.take_damage(4)
		if _one_shot_left <= 0.0:
			_play("Idle", 0.1, 1.0)
		return
	if d <= 2.1:
		velocity.x = 0
		velocity.z = 0
		if _attack_cd <= 0.0:
			_attack_cd = 1.2
			_one_shot("Punch_Cross" if randf() < 0.5 else "Punch_Jab")
			if _player.has_method("take_damage"):
				_player.take_damage(6 if is_cop else 4)
		return
	var speed := 5.0 if is_cop else 4.2
	_walk_towards(delta, speed)
	if _one_shot_left <= 0.0:
		_play("Jog_Fwd", 0.2, 1.25)


func _sees_player() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
			global_position + Vector3(0, 1.5, 0),
			_player.global_position + Vector3(0, 1.2, 0), 1)
	return space.intersect_ray(q).is_empty()
