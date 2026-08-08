class_name Hud
extends CanvasLayer
## HUD: crosshair, health + stamina bars, interaction prompt, ammo, FPS,
## damage flash and death screen.

var _stamina_fill: ColorRect
var _stamina_bg: ColorRect
var _health_fill: ColorRect
var _health_bg: ColorRect
var _prompt: Label
var _fps: Label
var _ammo: Label
var _flash: ColorRect
var _death: Label
var _toast: Label
var _fps_accum := 0.0
var _last_health := 100


func _ready() -> void:
	# Crosshair dot
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.85)
	dot.size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position = Vector2(-2, -2)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dot)

	# Damage flash (full screen, under everything else)
	_flash = ColorRect.new()
	_flash.color = Color(0.8, 0.05, 0.05, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	move_child(_flash, 0)

	# Health bar (bottom left, above stamina)
	_health_bg = ColorRect.new()
	_health_bg.color = Color(0, 0, 0, 0.45)
	_health_bg.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_health_bg.position = Vector2(24, -92)
	_health_bg.size = Vector2(240, 14)
	_health_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_health_bg)

	_health_fill = ColorRect.new()
	_health_fill.color = Color(0.85, 0.25, 0.25)
	_health_fill.position = Vector2(2, 2)
	_health_fill.size = Vector2(236, 10)
	_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bg.add_child(_health_fill)

	var health_label := Label.new()
	health_label.text = "HEALTH"
	health_label.add_theme_font_size_override("font_size", 12)
	health_label.position = Vector2(0, -20)
	_health_bg.add_child(health_label)

	# Death screen text (hidden until needed)
	_death = Label.new()
	_death.text = "YOU DIED"
	_death.add_theme_font_size_override("font_size", 64)
	_death.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
	_death.set_anchors_preset(Control.PRESET_CENTER)
	_death.position = Vector2(-190, -60)
	_death.size = Vector2(380, 80)
	_death.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death.visible = false
	_death.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_death)

	# Toast message (top center, fades out)
	_toast = Label.new()
	_toast.text = ""
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position = Vector2(-180, 48)
	_toast.size = Vector2(360, 30)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate = Color(1, 1, 1, 0)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)

	# Stamina bar (bottom left)
	_stamina_bg = ColorRect.new()
	_stamina_bg.color = Color(0, 0, 0, 0.45)
	_stamina_bg.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_stamina_bg.position = Vector2(24, -46)
	_stamina_bg.size = Vector2(240, 14)
	_stamina_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stamina_bg)

	_stamina_fill = ColorRect.new()
	_stamina_fill.color = Color(0.35, 0.85, 0.55)
	_stamina_fill.position = Vector2(2, 2)
	_stamina_fill.size = Vector2(236, 10)
	_stamina_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_bg.add_child(_stamina_fill)

	var stamina_label := Label.new()
	stamina_label.text = "STAMINA"
	stamina_label.add_theme_font_size_override("font_size", 12)
	stamina_label.position = Vector2(0, -20)
	_stamina_bg.add_child(stamina_label)

	# Interaction prompt (center, below crosshair)
	_prompt = Label.new()
	_prompt.text = ""
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.position = Vector2(-150, 40)
	_prompt.size = Vector2(300, 30)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt)

	# Ammo (bottom right)
	_ammo = Label.new()
	_ammo.text = ""
	_ammo.add_theme_font_size_override("font_size", 22)
	_ammo.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo.position = Vector2(-260, -52)
	_ammo.size = Vector2(236, 30)
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ammo)

	# FPS (top right)
	_fps = Label.new()
	_fps.add_theme_font_size_override("font_size", 14)
	_fps.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps.position = Vector2(-90, 12)
	_fps.size = Vector2(80, 20)
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_fps)

	# Title tag (top left)
	var title := Label.new()
	title.text = "AFTERLIGHT  -  Phase 5: Old Market"
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(1, 1, 1, 0.55)
	title.position = Vector2(24, 12)
	add_child(title)


func _process(delta: float) -> void:
	_fps_accum -= delta
	if _fps_accum <= 0.0:
		_fps_accum = 0.25
		_fps.text = "%d FPS" % Engine.get_frames_per_second()


func set_stamina(current: float, maximum: float) -> void:
	var ratio := clampf(current / maximum, 0.0, 1.0)
	_stamina_fill.size.x = 236.0 * ratio
	_stamina_fill.color = Color(0.35, 0.85, 0.55) if ratio > 0.25 else Color(0.9, 0.55, 0.25)


func set_exhausted(is_exhausted: bool) -> void:
	if is_exhausted:
		_stamina_fill.color = Color(0.85, 0.3, 0.25)


func set_prompt(text: String) -> void:
	_prompt.text = text


func set_ammo(text: String) -> void:
	_ammo.text = text


func set_health(current: int, maximum: int) -> void:
	var ratio := clampf(float(current) / float(maximum), 0.0, 1.0)
	_health_fill.size.x = 236.0 * ratio
	if current < _last_health:
		_flash.color.a = 0.32
		var tw := create_tween()
		tw.tween_property(_flash, "color:a", 0.0, 0.45)
	_last_health = current


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


func show_death() -> void:
	_death.visible = true
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.55, 1.2)
