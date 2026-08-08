class_name PauseMenu
extends CanvasLayer
## ESC pause menu: pauses the game, frees the mouse, and exposes live settings:
## mouse sensitivity, invert Y, FOV, head bob, camera shake.

var _panel_root: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	var opening := not visible
	visible = opening
	get_tree().paused = opening
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if opening else Input.MOUSE_MODE_CAPTURED


func _build_ui() -> void:
	_panel_root = Control.new()
	_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(460, 0)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var resume := Button.new()
	resume.text = "Resume  (ESC)"
	resume.pressed.connect(toggle)
	vbox.add_child(resume)

	var settings_title := Label.new()
	settings_title.text = "SETTINGS"
	settings_title.add_theme_font_size_override("font_size", 18)
	settings_title.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(settings_title)

	_slider(vbox, "Mouse sensitivity", 0.2, 3.0, 0.05, GameSettings.mouse_sensitivity,
			func(v: float) -> void: GameSettings.mouse_sensitivity = v)
	_slider(vbox, "Field of view", 60.0, 100.0, 1.0, GameSettings.fov,
			func(v: float) -> void: GameSettings.fov = v)
	_slider(vbox, "Camera shake", 0.0, 1.0, 0.05, GameSettings.camera_shake,
			func(v: float) -> void: GameSettings.camera_shake = v)
	_checkbox(vbox, "Invert mouse Y", GameSettings.invert_y,
			func(on: bool) -> void: GameSettings.invert_y = on)
	_checkbox(vbox, "Head bob", GameSettings.head_bob,
			func(on: bool) -> void: GameSettings.head_bob = on)

	var hint := Label.new()
	hint.text = "Settings apply instantly."
	hint.modulate = Color(1, 1, 1, 0.5)
	hint.add_theme_font_size_override("font_size", 13)
	vbox.add_child(hint)


func _slider(parent: Control, label_text: String, minv: float, maxv: float, step: float,
		value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(170, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minv
	slider.max_value = maxv
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(180, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var val_label := Label.new()
	val_label.text = "%.2f" % value
	val_label.custom_minimum_size = Vector2(52, 0)
	row.add_child(val_label)
	slider.value_changed.connect(func(v: float) -> void:
		val_label.text = "%.2f" % v
		on_change.call(v))


func _checkbox(parent: Control, label_text: String, value: bool, on_change: Callable) -> void:
	var box := CheckBox.new()
	box.text = label_text
	box.button_pressed = value
	box.toggled.connect(func(on: bool) -> void: on_change.call(on))
	parent.add_child(box)
