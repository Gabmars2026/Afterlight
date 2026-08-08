class_name GlassPane
extends StaticBody3D
## Breakable window. Shatters (sound + shards) when the player runs/jumps
## into it with enough speed; the opening becomes passable.

var _broken := false


func _ready() -> void:
	add_to_group("breakable_glass")


func break_glass() -> void:
	if _broken:
		return
	_broken = true
	var parent := get_parent()
	# 3D positional shatter sound
	var p := AudioStreamPlayer3D.new()
	p.stream = load("res://assets/audio/glass_break.wav")
	p.unit_size = 8.0
	p.max_distance = 60.0
	p.volume_db = -2.0
	parent.add_child(p)
	p.global_position = global_position
	p.play()
	p.finished.connect(p.queue_free)
	# shards
	var shards := CPUParticles3D.new()
	shards.amount = 40
	shards.one_shot = true
	shards.lifetime = 0.9
	shards.explosiveness = 1.0
	shards.direction = Vector3(0, -0.3, 0)
	shards.spread = 60.0
	shards.initial_velocity_min = 1.0
	shards.initial_velocity_max = 3.5
	shards.gravity = Vector3(0, -9.8, 0)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.06, 0.06)
	shards.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.9, 1.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.6
	shards.mesh.material = mat
	parent.add_child(shards)
	shards.global_position = global_position
	shards.emitting = true
	var t := get_tree().create_timer(1.2)
	t.timeout.connect(shards.queue_free)
	queue_free()
