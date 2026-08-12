class_name Interactable
extends StaticBody3D
## Base class for anything the player can use with E.
## Add to group "interactable" (done automatically in _ready).

@export var prompt: String = "Press E to use"

signal used(user: Node)


func _ready() -> void:
	add_to_group("interactable")


func get_prompt() -> String:
	return prompt


func interact(user: Node) -> void:
	used.emit(user)
