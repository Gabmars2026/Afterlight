extends Interactable
## Compact elevator control used on every playable upper floor. Interacting
## moves the player to the next floor; the top floor loops back to the lobby.

var destination_floor := 1
var target_local_position := Vector3.ZERO


func _ready() -> void:
	super()
	prompt = "Press E for floor %d" % destination_floor
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.65, 0.48)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.18, 0.24)
	material.metallic = 0.75
	material.emission_enabled = true
	material.emission = Color(0.15, 0.65, 1.0)
	material.emission_energy_multiplier = 1.6
	mesh.material = material
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	add_child(collision)


func interact(user: Node) -> void:
	if not (user is Node3D) or get_parent() == null:
		return
	var destination := (get_parent() as Node3D).to_global(target_local_position)
	(user as Node3D).global_position = destination
	if user is CharacterBody3D:
		(user as CharacterBody3D).velocity = Vector3.ZERO
	if user.has_signal("notify"):
		user.emit_signal("notify", "ELEVATOR: FLOOR %d" % destination_floor)
	super(user)
