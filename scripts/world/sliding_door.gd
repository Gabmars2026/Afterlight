class_name SlidingDoor
extends Interactable
## A door that slides open/closed when used. Built in code by test_zone.gd.

var open := false
var slide_offset := Vector3(0, 3.2, 0)

var _closed_pos: Vector3
var _tween: Tween
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	super()
	prompt = "Press E to open door"
	_closed_pos = position
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = load("res://assets/audio/door_slide.wav")
	_audio.unit_size = 6.0
	_audio.max_distance = 40.0
	_audio.volume_db = -4.0
	add_child(_audio)


func interact(user: Node) -> void:
	open = not open
	prompt = "Press E to close door" if open else "Press E to open door"
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", _closed_pos + (slide_offset if open else Vector3.ZERO), 0.9)
	_audio.pitch_scale = randf_range(0.95, 1.05)
	_audio.play()
	super(user)
