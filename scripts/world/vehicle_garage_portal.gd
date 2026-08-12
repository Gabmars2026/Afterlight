class_name VehicleGaragePortal
extends Area3D
## Automatic transition volume for cars at asset-authored garage doors.

var destination: Node3D
var destination_yaw := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.6, 2.5, 1.5)
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if destination == null or not body.is_in_group("vehicle"):
		return
	if body.has_meta("garage_portal_lock"):
		return
	body.set_meta("garage_portal_lock", true)
	if body.has_method("teleport_vehicle"):
		body.teleport_vehicle(destination.global_position, destination_yaw)
	else:
		body.global_position = destination.global_position
	get_tree().create_timer(1.0).timeout.connect(
			func() -> void:
				if is_instance_valid(body):
					body.remove_meta("garage_portal_lock"))
