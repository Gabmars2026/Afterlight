class_name InteriorZone
extends Area3D
## Switches the player's audio to the reverberant Interior bus while inside,
## and duck outdoor ambience. Cheap, per-zone audio occlusion/reverb.

var wind_player: AudioStreamPlayer = null
var _outside_wind_db := -18.0


func _init() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true


func _ready() -> void:
	body_entered.connect(_on_body)
	body_exited.connect(_off_body)


func _on_body(body: Node3D) -> void:
	if body is Player:
		body.set_audio_environment("Interior")
		if wind_player:
			_outside_wind_db = wind_player.volume_db
			var tw := create_tween()
			tw.tween_property(wind_player, "volume_db", _outside_wind_db - 10.0, 0.5)


func _off_body(body: Node3D) -> void:
	if body is Player:
		body.set_audio_environment("Master")
		if wind_player:
			var tw := create_tween()
			tw.tween_property(wind_player, "volume_db", _outside_wind_db, 0.5)
