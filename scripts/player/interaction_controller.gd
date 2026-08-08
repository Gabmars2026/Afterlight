class_name InteractionController
extends RayCast3D
## Detects interactable objects the player is looking at.
## Created by player.gd as a child of the camera. Interactables must be in
## group "interactable" and implement get_prompt() and interact(user).

signal focus_changed(prompt: String)

const REACH := 2.6

var _focused: Node = null


func _ready() -> void:
	target_position = Vector3(0, 0, -REACH)
	collide_with_areas = true
	collide_with_bodies = true


func _physics_process(_delta: float) -> void:
	var hit: Node = null
	if is_colliding():
		var collider := get_collider()
		if collider is Node and (collider as Node).is_in_group("interactable"):
			hit = collider
	if hit != _focused:
		_focused = hit
		if _focused != null and _focused.has_method("get_prompt"):
			focus_changed.emit(_focused.get_prompt())
		else:
			focus_changed.emit("")


func try_interact(user: Node) -> void:
	if _focused != null and _focused.has_method("interact"):
		_focused.interact(user)
		# Refresh prompt (state may have changed)
		if _focused.has_method("get_prompt"):
			focus_changed.emit(_focused.get_prompt())
