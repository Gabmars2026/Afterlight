class_name SlidingDoor
extends Interactable
## A door that slides open/closed when used. Built in code by test_zone.gd.

var open := false
var slide_offset := Vector3(0, 3.2, 0)

var _closed_pos: Vector3
var _closed_transform: Transform3D
var _tween: Tween
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	super()
	prompt = "Press E to open door"
	_closed_pos = position
	_closed_transform = global_transform
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = load("res://assets/audio/door_slide.wav")
	_audio.unit_size = 6.0
	_audio.max_distance = 40.0
	_audio.volume_db = -4.0
	add_child(_audio)


func interact(user: Node) -> void:
	if open and _closing_path_blocked():
		if user != null and user.has_signal("notify"):
			user.emit_signal("notify", "DOORWAY BLOCKED")
		return
	open = not open
	prompt = "Press E to close door" if open else "Press E to open door"
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", _closed_pos + (slide_offset if open else Vector3.ZERO), 0.9)
	_audio.pitch_scale = randf_range(0.95, 1.05)
	_audio.play()
	super(user)


func _closing_path_blocked() -> bool:
	## Check the full travel path so a sideways door cannot push the player
	## into its wall pocket or close through them.
	var space := get_world_3d().direct_space_state
	for child in get_children():
		if not (child is CollisionShape3D) or child.shape == null \
				or child.disabled:
			continue
		for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = child.shape
			var sample := _closed_transform
			sample.origin += _closed_transform.basis * slide_offset * fraction
			query.transform = sample * child.transform
			query.collision_mask = 2 # Player collision layer.
			query.exclude = [get_rid()]
			if not space.intersect_shape(query, 1).is_empty():
				return true
	return false
