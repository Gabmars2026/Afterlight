extends StaticBody3D
## Breakable object (wooden door, weak wall, barricade). Takes damage from
## bullets (and later melee), splinters while damaged, then bursts apart.

var health := 60
var debris_color := Color(0.55, 0.4, 0.25)
var noise_radius := 18.0

var _size := Vector3.ONE
var _hit_snd: AudioStreamPlayer3D
var _mesh: MeshInstance3D


func setup(size: Vector3, tint: Color, hp: int) -> void:
	_size = size
	health = hp
	debris_color = tint.darkened(0.15)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.95
	box.material = mat
	mesh.mesh = box
	_mesh = mesh
	add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	add_child(col)
	set_meta("surface", "wood")


func _ready() -> void:
	_hit_snd = AudioStreamPlayer3D.new()
	_hit_snd.stream = load("res://assets/audio/impact_wood.wav")
	_hit_snd.unit_size = 5.0
	_hit_snd.max_distance = 30.0
	add_child(_hit_snd)


func take_hit(damage: int, point: Vector3) -> void:
	health -= damage
	_hit_snd.pitch_scale = randf_range(0.85, 1.05)
	_hit_snd.play()
	_splinters(point, 8)
	# Damage wobble
	var tween := create_tween()
	tween.tween_property(_mesh, "scale", Vector3(1.03, 0.98, 1.03), 0.05)
	tween.tween_property(_mesh, "scale", Vector3.ONE, 0.1)
	if health <= 0:
		_break_apart()


func _splinters(point: Vector3, count: int) -> void:
	var p := CPUParticles3D.new()
	p.amount = count
	p.lifetime = 0.4
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 55.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -9.8, 0)
	var pm := BoxMesh.new()
	pm.size = Vector3(0.06, 0.02, 0.02)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = debris_color
	pm.material = pmat
	p.mesh = pm
	get_parent().add_child(p)
	p.global_position = point
	p.emitting = true
	var t := get_tree().create_timer(0.8)
	t.timeout.connect(p.queue_free)


func _break_apart() -> void:
	# Loud enough that zombies come to look
	get_tree().call_group("enemies", "hear_noise", global_position, noise_radius)
	var parent := get_parent()
	# Break sound outlives this node
	var snd := AudioStreamPlayer3D.new()
	snd.stream = load("res://assets/audio/wood_break.wav")
	snd.unit_size = 7.0
	snd.max_distance = 45.0
	snd.pitch_scale = randf_range(0.9, 1.1)
	parent.add_child(snd)
	snd.global_position = global_position
	snd.play()
	snd.finished.connect(snd.queue_free)
	# Plank debris burst
	var p := CPUParticles3D.new()
	p.amount = 26
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -9.8, 0)
	var pm := BoxMesh.new()
	pm.size = Vector3(0.16, 0.05, 0.05)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = debris_color
	pm.material = pmat
	p.mesh = pm
	parent.add_child(p)
	p.global_position = global_position
	p.emitting = true
	var t := parent.get_tree().create_timer(1.4)
	t.timeout.connect(p.queue_free)
	queue_free()
