class_name LadderZone
extends Area3D
## Volume the player can climb while inside (W = up, S = down).


func _init() -> void:
	collision_layer = 0
	collision_mask = 2  # player layer
	monitoring = true


func _ready() -> void:
	body_entered.connect(_on_body)
	body_exited.connect(_off_body)


func _on_body(body: Node3D) -> void:
	if body is Player:
		body.enter_ladder()


func _off_body(body: Node3D) -> void:
	if body is Player:
		body.exit_ladder()
