extends CharacterBody3D
## Settlement NPC (Phase 10). Wanders near a work spot by day, walks home
## at night, and speaks cycling dialogue lines when you press E.

const WALK_SPEED := 1.7
const GRAVITY := 14.0

var npc_name := "SURVIVOR"
var shirt_color := Color(0.5, 0.42, 0.3)
var work_pos := Vector3.ZERO
var work_radius := 4.0
var home_pos := Vector3.ZERO
var lines: Array = ["..."]

var _line_idx := 0
var _target := Vector3.ZERO
var _wait := 0.0
var _talk_left := 0.0
var _talk_to: Node3D
var _night := false
var _mesh_root: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _walk_phase := 0.0
var _bubble: Label3D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npcs")
	collision_layer = 1
	collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)
	_build_mesh()
	_pick_target()


func setup(nm: String, color: Color, work: Vector3, radius: float,
		home: Vector3, dialogue: Array) -> void:
	npc_name = nm
	shirt_color = color
	work_pos = work
	work_radius = radius
	home_pos = home
	lines = dialogue


func set_night(n: bool) -> void:
	_night = n
	_pick_target()


func get_prompt() -> String:
	return "Press E to talk to %s" % npc_name


func interact(user: Node) -> void:
	get_tree().call_group("quest_listeners", "on_npc_talked", npc_name)
	_talk_left = 4.0
	_talk_to = user as Node3D
	var line: String = lines[_line_idx]
	_line_idx = (_line_idx + 1) % lines.size()
	_bubble.text = line
	_bubble.visible = true


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if _talk_left > 0.0:
		# Stop and face the player while talking
		_talk_left -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		if _talk_to:
			var to := _talk_to.global_position - global_position
			to.y = 0.0
			if to.length() > 0.2:
				rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 8.0 * delta)
		if _talk_left <= 0.0:
			_bubble.visible = false
	elif _wait > 0.0:
		_wait -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		if _wait <= 0.0:
			_pick_target()
	else:
		var to := _target - global_position
		to.y = 0.0
		if to.length() < 0.5:
			_wait = randf_range(2.0, 5.0)
		else:
			var dir := to.normalized()
			velocity.x = dir.x * WALK_SPEED
			velocity.z = dir.z * WALK_SPEED
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 6.0 * delta)
	move_and_slide()
	# Leg swing while walking
	var hspeed := Vector2(velocity.x, velocity.z).length()
	_walk_phase += hspeed * delta * 2.8
	var amp := clampf(hspeed / 2.0, 0.0, 1.0) * 0.45
	_hip_l.rotation.x = sin(_walk_phase) * amp
	_hip_r.rotation.x = -sin(_walk_phase) * amp


func _pick_target() -> void:
	if _night:
		_target = home_pos
	else:
		var a := randf() * TAU
		_target = work_pos + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, work_radius)


func _build_mesh() -> void:
	_mesh_root = Node3D.new()
	add_child(_mesh_root)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.85, 0.68, 0.54)
	skin.roughness = 0.9
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = shirt_color
	cloth.roughness = 1.0
	var pants := StandardMaterial3D.new()
	pants.albedo_color = shirt_color.darkened(0.45)
	pants.roughness = 1.0
	_part(_mesh_root, Vector3(0.34, 0.2, 0.22), Vector3(0, 0.98, 0), pants)
	_part(_mesh_root, Vector3(0.36, 0.34, 0.22), Vector3(0, 1.25, 0), cloth)
	_part(_mesh_root, Vector3(0.42, 0.36, 0.25), Vector3(0, 1.58, 0), cloth)
	_part(_mesh_root, Vector3(0.12, 0.1, 0.12), Vector3(0, 1.8, 0), skin)
	_part(_mesh_root, Vector3(0.26, 0.28, 0.26), Vector3(0, 1.99, 0), skin)
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(0.12, 0.12, 0.14)
	_part(_mesh_root, Vector3(0.045, 0.04, 0.02), Vector3(-0.065, 2.02, -0.135), eye)
	_part(_mesh_root, Vector3(0.045, 0.04, 0.02), Vector3(0.065, 2.02, -0.135), eye)
	# Relaxed arms
	for x in [-0.28, 0.28]:
		var arm := Node3D.new()
		arm.position = Vector3(x, 1.68, 0)
		_part(arm, Vector3(0.12, 0.34, 0.12), Vector3(0, -0.18, 0), cloth)
		_part(arm, Vector3(0.1, 0.3, 0.1), Vector3(0, -0.5, 0), skin)
		_part(arm, Vector3(0.11, 0.1, 0.12), Vector3(0, -0.7, 0), skin)
		_mesh_root.add_child(arm)
	# Legs on hip pivots
	for data in [[-0.12, true], [0.12, false]]:
		var hip := Node3D.new()
		hip.position = Vector3(data[0], 0.92, 0)
		_part(hip, Vector3(0.15, 0.42, 0.16), Vector3(0, -0.21, 0), pants)
		_part(hip, Vector3(0.13, 0.4, 0.14), Vector3(0, -0.62, 0.01), pants)
		_part(hip, Vector3(0.13, 0.09, 0.26), Vector3(0, -0.86, -0.05), pants)
		_mesh_root.add_child(hip)
		if data[1]:
			_hip_l = hip
		else:
			_hip_r = hip
	# Name tag + speech bubble
	var tag := Label3D.new()
	tag.text = npc_name
	tag.position = Vector3(0, 2.35, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 40
	tag.pixel_size = 0.004
	tag.modulate = Color(0.85, 0.95, 0.85)
	tag.outline_size = 8
	add_child(tag)
	_bubble = Label3D.new()
	_bubble.position = Vector3(0, 2.6, 0)
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 34
	_bubble.pixel_size = 0.004
	_bubble.modulate = Color(1, 1, 0.85)
	_bubble.outline_size = 10
	_bubble.width = 420
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.visible = false
	add_child(_bubble)


func _part(parent: Node3D, size: Vector3, pos: Vector3,
		mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mi.mesh = box
	mi.position = pos
	parent.add_child(mi)
