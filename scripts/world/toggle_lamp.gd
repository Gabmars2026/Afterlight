class_name ToggleLamp
extends Interactable
## A switch that toggles a light on/off. Built in code by test_zone.gd.

var lamp: Light3D
var on := true


func _ready() -> void:
	super()
	prompt = "Press E to toggle light"


func interact(user: Node) -> void:
	on = not on
	if lamp:
		lamp.visible = on
	super(user)
