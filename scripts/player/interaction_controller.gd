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
		hit = find_interactable(get_collider())
	if hit != _focused:
		_focused = hit
		if _focused != null and _focused.has_method("get_prompt"):
			focus_changed.emit(_focused.get_prompt())
		else:
			focus_changed.emit("")


func find_interactable(collider: Object) -> Node:
	## Imported models often put collision on a child of the actual usable
	## object. Walk upward instead of requiring the group on every child.
	var node := collider as Node
	var levels := 0
	while node != null and levels < 8:
		if node.is_in_group("interactable") \
				and node.has_method("get_prompt") and node.has_method("interact"):
			return node
		node = node.get_parent()
		levels += 1
	return null


func try_interact(user: Node) -> void:
	if _focused != null and _focused.has_method("interact"):
		_focused.interact(user)
		# Refresh prompt (state may have changed)
		if _focused.has_method("get_prompt"):
			focus_changed.emit(_focused.get_prompt())
