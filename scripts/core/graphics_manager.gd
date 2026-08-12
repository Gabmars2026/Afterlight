extends Node
## Phase 16: scalability presets. LOW / MEDIUM / HIGH change shadows,
## render scale, anti-aliasing, streaming distance and rain density in one
## click from the pause menu. The choice persists in user://settings.cfg.

const PRESET_NAMES := ["LOW", "MEDIUM", "HIGH"]

var sun: DirectionalLight3D
var env: Environment
var streamer: Node3D
var weather: Node

var preset := 1


func _ready() -> void:
	add_to_group("graphics")
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		preset = clampi(cfg.get_value("video", "preset", 1), 0, 2)
	apply_preset(preset)


func apply_preset(idx: int) -> void:
	preset = clampi(idx, 0, 2)
	var vp := get_viewport()
	match preset:
		0:  # LOW - integrated graphics / old laptops
			sun.shadow_enabled = false
			env.glow_enabled = false
			vp.scaling_3d_scale = 0.75
			vp.msaa_3d = Viewport.MSAA_DISABLED
			streamer.set_view(2, 3, 1)
			weather.rain_scale = 0.4
		1:  # MEDIUM - default
			sun.shadow_enabled = true
			env.glow_enabled = true
			sun.directional_shadow_max_distance = 45.0
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_DISABLED
			streamer.set_view(3, 4, 2)
			weather.rain_scale = 0.7
		2:  # HIGH
			sun.shadow_enabled = true
			env.glow_enabled = true
			sun.directional_shadow_max_distance = 80.0
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_2X
			streamer.set_view(3, 4, 2)
			weather.rain_scale = 1.0
	var cfg := ConfigFile.new()
	cfg.set_value("video", "preset", preset)
	cfg.save("user://settings.cfg")


func preset_name() -> String:
	return PRESET_NAMES[preset]
