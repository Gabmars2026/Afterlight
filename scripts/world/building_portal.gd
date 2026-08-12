class_name BuildingPortal
extends Interactable
## Invisible interaction volume placed over an asset-authored building door.

var destination: Node3D


func _ready() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 2.5, 0.35)
	collision.shape = shape
	add_child(collision)
	super()


func interact(user: Node) -> void:
	if destination == null or user == null or not (user is Node3D):
		return
	var traveler := user as Node3D
	traveler.global_position = destination.global_position
	if traveler is CharacterBody3D:
		(traveler as CharacterBody3D).velocity = Vector3.ZERO
	if user.has_signal("notify"):
		user.emit_signal("notify", "ENTERED BUILDING" if prompt.contains("enter") else "LEFT BUILDING")
	super(user)
