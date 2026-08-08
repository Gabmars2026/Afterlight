class_name ToggleLamp
extends Interactable
## A switch that toggles a light on/off. Built in code by test_zone.gd.

var lamp: Light3D
var on := true

var _click: AudioStreamPlayer3D


func _ready() -> void:
	super()
	prompt = "Press E to toggle light"
	_click = AudioStreamPlayer3D.new()
	_click.stream = load("res://assets/audio/switch_click.wav")
	_click.unit_size = 4.0
	_click.max_distance = 25.0
	add_child(_click)


func interact(user: Node) -> void:
	on = not on
	if lamp:
		lamp.visible = on
	_click.play()
	super(user)
