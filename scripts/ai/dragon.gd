extends CharacterBody3D
## Phase 19: dungeon dragon. A hovering beast built from primitives that
## patrols its lair, chases the player on sight and breathes cones of
## fire. Guns hurt it; get too close and you burn.

const SPEED := 4.0
const SIGHT := 26.0
const BREATH_RANGE := 15.0
const BREATH_DAMAGE := 8

var max_health := 420
var health := max_health
var waypoints: Array = []

var _player: Node3D
var _wp := 0
var _t := 0.0
var _breathing := false
var _breath_timer := 3.0
var _damage_tick := 0.0
var _body_mat := StandardMaterial3D.new()
var _wing_l: MeshInstance3D
var _wing_r: MeshInstance3D
var _head: Node3D
var _fire: CPUParticles3D
var _glow: OmniLight3D
var _sfx: AudioStreamPlayer3D
var _flash := 0.0
var _dead := false


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("dragon")
	collision_layer = 4
	collision_mask = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 2.2, 4.6)
	col.shape = shape
	col.position.y = 1.4
	add_child(col)
	_build_mesh()
	_player = get_tree().get_first_node_in_group("player")
	var ws: AudioStreamWAV = load("res://assets/audio/fire_breath.wav")
	if ws:
		ws.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ws.loop_end = ws.data.size() / 2
		_sfx = AudioStreamPlayer3D.new()
		_sfx.stream = ws
		_sfx.unit_size = 8.0
		_sfx.max_distance = 45.0
		add_child(_sfx)


func _build_mesh() -> void:
	_body_mat.albedo_color = Color(0.45, 0.1, 0.08)
	_body_mat.roughness = 0.6
	var horn_mat := StandardMaterial3D.new()
	horn_mat.albedo_color = Color(0.85, 0.8, 0.65)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.6, 0.1)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.5, 0.05)
	eye_mat.emission_energy_multiplier = 2.5
	# Body
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 1.0
	cap.height = 4.2
	cap.material = _body_mat
	body.mesh = cap
	body.rotation.x = PI / 2
	body.position.y = 1.4
	add_child(body)
	# Tail (two tapering segments behind, +z)
	for i in 2:
		var seg := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.55 - i * 0.2, 0.45 - i * 0.15, 1.8)
		sb.material = _body_mat
		seg.mesh = sb
		seg.position = Vector3(0, 1.5 + i * 0.15, 2.8 + i * 1.6)
		seg.rotation.x = -0.15 * (i + 1)
		add_child(seg)
	# Neck + head group (forward, -z)
	_head = Node3D.new()
	_head.position = Vector3(0, 2.0, -2.4)
	add_child(_head)
	var neck := MeshInstance3D.new()
	var nb := BoxMesh.new()
	nb.size = Vector3(0.6, 0.6, 1.6)
	nb.material = _body_mat
	neck.mesh = nb
	neck.position = Vector3(0, -0.2, 0.7)
	neck.rotation.x = 0.35
	_head.add_child(neck)
	var skull := MeshInstance3D.new()
	var kb := BoxMesh.new()
	kb.size = Vector3(0.8, 0.65, 1.1)
	kb.material = _body_mat
	skull.mesh = kb
	_head.add_child(skull)
	var snout := MeshInstance3D.new()
	var snb := BoxMesh.new()
	snb.size = Vector3(0.5, 0.35, 0.7)
	snb.material = _body_mat
	snout.mesh = snb
	snout.position = Vector3(0, -0.1, -0.8)
	_head.add_child(snout)
	for ex in [-0.24, 0.24]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.09
		es.height = 0.18
		es.material = eye_mat
		eye.mesh = es
		eye.position = Vector3(ex, 0.14, -0.5)
		_head.add_child(eye)
	for hx in [-0.28, 0.28]:
		var horn := MeshInstance3D.new()
		var hc := CylinderMesh.new()
		hc.top_radius = 0.02
		hc.bottom_radius = 0.1
		hc.height = 0.55
		hc.material = horn_mat
		horn.mesh = hc
		horn.position = Vector3(hx, 0.42, 0.25)
		horn.rotation.x = -0.5
		_head.add_child(horn)
	# Wings
	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var wb := BoxMesh.new()
		wb.size = Vector3(3.4, 0.12, 2.2)
		wb.material = _body_mat
		wing.mesh = wb
		wing.position = Vector3(side * 2.2, 2.2, 0.2)
		add_child(wing)
		if side < 0:
			_wing_l = wing
		else:
			_wing_r = wing
	# Fire breath particles (from the snout, -z)
	_fire = CPUParticles3D.new()
	_fire.emitting = false
	_fire.amount = 130
	_fire.lifetime = 0.7
	_fire.direction = Vector3(0, -0.25, -1)
	_fire.spread = 9.0
	_fire.initial_velocity_min = 16.0
	_fire.initial_velocity_max = 22.0
	_fire.gravity = Vector3(0, 1.5, 0)
	_fire.scale_amount_min = 0.5
	_fire.scale_amount_max = 1.4
	var fq := QuadMesh.new()
	fq.size = Vector2(0.34, 0.34)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color = Color(1.0, 0.55, 0.1, 0.6)
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fq.material = fm
	_fire.mesh = fq
	_fire.position = Vector3(0, -0.15, -1.0)
	_head.add_child(_fire)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.5, 0.1)
	_glow.light_energy = 0.0
	_glow.omni_range = 12.0
	_glow.position = Vector3(0, 0, -2.5)
	_head.add_child(_glow)


func take_hit(damage: int, point: Vector3) -> void:
	if _dead:
		return
	# Headshots count double on a dragon
	if point.y > global_position.y + 1.7 and point.distance_to(
			_head.global_position) < 1.6:
		damage *= 2
	health -= damage
	_flash = 0.15
	_body_mat.albedo_color = Color(0.9, 0.3, 0.25)
	if health <= 0:
		_die()


func _die() -> void:
	_dead = true
	_breathing = false
	_fire.emitting = false
	_glow.light_energy = 0.0
	if _sfx and _sfx.playing:
		_sfx.stop()
	collision_layer = 0
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", PI * 0.45, 1.2)
	tw.parallel().tween_property(self, "position:y", position.y - 1.0, 1.2)
	tw.tween_interval(2.0)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	# Wing flap
	var flap := sin(_t * 6.0) * 0.55
	_wing_l.rotation.z = -flap
	_wing_r.rotation.z = flap
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_body_mat.albedo_color = Color(0.45, 0.1, 0.08)

	var sees := false
	var ppos := Vector3.ZERO
	if _player and is_instance_valid(_player):
		ppos = _player.global_position
		var d := global_position.distance_to(ppos)
		if d < SIGHT:
			var space := get_world_3d().direct_space_state
			var q := PhysicsRayQueryParameters3D.create(
					_head.global_position, ppos + Vector3(0, 0.9, 0), 1)
			sees = space.intersect_ray(q).is_empty()

	# Move: chase the player when seen, otherwise patrol waypoints
	var target := global_position
	if sees:
		target = ppos
	elif waypoints.size() > 0:
		target = waypoints[_wp]
		if global_position.distance_to(target) < 2.0:
			_wp = (_wp + 1) % waypoints.size()
			target = waypoints[_wp]
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() > (6.0 if sees else 1.0):
		var dir := to_target.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		var want := atan2(dir.x, dir.z) + PI
		rotation.y = lerp_angle(rotation.y, want, 3.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
		if sees:
			var dir2 := (ppos - global_position).normalized()
			rotation.y = lerp_angle(rotation.y,
					atan2(dir2.x, dir2.z) + PI, 3.0 * delta)
	# Hover bob
	velocity.y = sin(_t * 1.7) * 0.6
	move_and_slide()
	# Aim the head (and so the fire) at the player when seen
	if sees:
		var aim := ppos + Vector3(0, 0.8, 0)
		if _head.global_position.distance_to(aim) > 1.0:
			_head.look_at(aim, Vector3.UP)
	else:
		_head.rotation = _head.rotation.lerp(Vector3.ZERO, 4.0 * delta)

	# Fire breath cycle
	_breath_timer -= delta
	if _breathing:
		if _breath_timer <= 0.0 or not sees:
			_set_breathing(false)
			_breath_timer = randf_range(2.2, 3.4)
		else:
			_burn_check(delta, ppos)
	elif sees and _breath_timer <= 0.0 \
			and global_position.distance_to(ppos) < BREATH_RANGE:
		_set_breathing(true)
		_breath_timer = 2.6


func _set_breathing(on: bool) -> void:
	_breathing = on
	_fire.emitting = on
	_glow.light_energy = 2.2 if on else 0.0
	if _sfx:
		if on:
			_sfx.play()
		elif _sfx.playing:
			_sfx.stop()


func _burn_check(delta: float, ppos: Vector3) -> void:
	_damage_tick -= delta
	if _damage_tick > 0.0:
		return
	var mouth := _head.global_position
	var fwd := -_head.global_transform.basis.z
	var to_p := ppos + Vector3(0, 0.8, 0) - mouth
	if to_p.length() < BREATH_RANGE and fwd.angle_to(to_p.normalized()) < 0.45:
		if _player.has_method("take_damage"):
			_player.take_damage(BREATH_DAMAGE)
		_damage_tick = 0.5
