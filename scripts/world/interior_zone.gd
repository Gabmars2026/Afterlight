class_name InteriorZone
extends Area3D
## Switches the player's audio to a reverberant bus while inside
## (e.g. "Interior" for rooms, "Tunnel" for underground echo), and ducks
## outdoor ambience. Cheap, per-zone audio occlusion/reverb.

var bus_name := "Interior"
var ambience: Array[AudioStreamPlayer] = []

var _outside_db: Array[float] = []


func _init() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true


func _ready() -> void:
	body_entered.connect(_on_body)
	body_exited.connect(_off_body)


func _on_body(body: Node3D) -> void:
	if body is Player:
		body.enter_audio_environment(get_instance_id(), bus_name)
		_outside_db.clear()
		for amb in ambience:
			_outside_db.append(amb.volume_db)
			var tw := create_tween()
			tw.tween_property(amb, "volume_db", amb.volume_db - 10.0, 0.5)


func _off_body(body: Node3D) -> void:
	if body is Player:
		body.exit_audio_environment(get_instance_id())
		for i in ambience.size():
			if i < _outside_db.size():
				var tw := create_tween()
				tw.tween_property(ambience[i], "volume_db", _outside_db[i], 0.5)
