class_name Hud
extends CanvasLayer
## Phase 1 HUD: crosshair, stamina bar, interaction prompt, FPS counter.

var _stamina_fill: ColorRect
var _stamina_bg: ColorRect
var _prompt: Label
var _fps: Label
var _ammo: Label
var _fps_accum := 0.0


func _ready() -> void:
	# Crosshair dot
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.85)
	dot.size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position = Vector2(-2, -2)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dot)

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
	title.text = "AFTERLIGHT  -  Phase 2: Combat Test"
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
