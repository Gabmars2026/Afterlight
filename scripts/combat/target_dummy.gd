class_name TargetDummy
extends StaticBody3D
## Shootable training dummy: takes hits with a thump sound and knock-back
## lean, falls over at zero health, then resets after a few seconds.

const MAX_HEALTH := 100

var health := MAX_HEALTH
var _hit_player: AudioStreamPlayer3D
var _body: MeshInstance3D
var _down := false


func _ready() -> void:
	collision_layer = 1
	set_meta("surface", "wood")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.45, 0.3)
	_body = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.28
	mesh.height = 1.5
	mesh.material = mat
	_body.mesh = mesh
	_body.position = Vector3(0, 1.05, 0)
	add_child(_body)
	var head := MeshInstance3D.new()
	var hmesh := SphereMesh.new()
	hmesh.radius = 0.17
	hmesh.height = 0.34
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.72, 0.55, 0.38)
	hmesh.material = hmat
	head.mesh = hmesh
	head.position = Vector3(0, 1.98, 0)
	add_child(head)
	var post := MeshInstance3D.new()
	var pmesh := CylinderMesh.new()
	pmesh.top_radius = 0.06
	pmesh.bottom_radius = 0.08
	pmesh.height = 0.6
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.35, 0.3, 0.25)
	pmesh.material = pmat
	post.mesh = pmesh
	post.position = Vector3(0, 0.15, 0)
	add_child(post)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 2.1
	shape.shape = cap
	shape.position = Vector3(0, 1.1, 0)
	add_child(shape)
	_hit_player = AudioStreamPlayer3D.new()
	_hit_player.stream = load("res://assets/audio/dummy_hit.wav")
	_hit_player.unit_size = 6.0
	_hit_player.max_distance = 40.0
	add_child(_hit_player)


func take_hit(damage: int, _point: Vector3) -> void:
	if _down:
		return
	health -= damage
	_hit_player.pitch_scale = randf_range(0.9, 1.1)
	_hit_player.play()
	var tween := create_tween()
	if health <= 0:
		_down = true
		tween.tween_property(self, "rotation:x", deg_to_rad(84.0), 0.4) \
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		get_tree().create_timer(4.0).timeout.connect(_reset)
	else:
		tween.tween_property(self, "rotation:x", deg_to_rad(9.0), 0.07)
		tween.tween_property(self, "rotation:x", 0.0, 0.22)


func _reset() -> void:
	if not is_inside_tree():
		return
	health = MAX_HEALTH
	_down = false
	var tween := create_tween()
	tween.tween_property(self, "rotation:x", 0.0, 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
