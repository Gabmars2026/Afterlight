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
var _clock: Label
var _quest: Label
var _territory: Label
var _territory_left := 0.0
var _inv_panel: PanelContainer
var _inv_buttons: Array = []
var _craft_buttons: Array = []
var _inv_open := false
var _weather_label: Label
var _stats_label: Label
var _stats_accum := 0.0
var player: Node  # set by the world after spawn
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

	# Day/time clock (top center)
	_clock = Label.new()
	_clock.text = "DAY 1   09:00"
	_clock.add_theme_font_size_override("font_size", 18)
	_clock.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_clock.position = Vector2(-90, 14)
	_clock.size = Vector2(180, 26)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.modulate = Color(1, 1, 1, 0.85)
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clock)

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
	title.text = "AFTERLIGHT  -  Phase 16: Optimization"
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(1, 1, 1, 0.55)
	title.position = Vector2(24, 12)
	add_child(title)

	_weather_label = Label.new()
	_weather_label.text = ""
	_weather_label.add_theme_font_size_override("font_size", 15)
	_weather_label.modulate = Color(0.75, 0.85, 1.0, 0.85)
	_weather_label.position = Vector2(24, 34)
	add_child(_weather_label)

	_stats_label = Label.new()
	_stats_label.visible = false
	_stats_label.position = Vector2(24, 60)
	_stats_label.add_theme_font_size_override("font_size", 13)
	_stats_label.modulate = Color(0.6, 1.0, 0.6, 0.9)
	add_child(_stats_label)

	# --- Territory banner (under the clock) ---
	_territory = Label.new()
	_territory.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_territory.position = Vector2(-300, 52)
	_territory.custom_minimum_size = Vector2(600, 0)
	_territory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_territory.add_theme_font_size_override("font_size", 17)
	_territory.modulate = Color(1, 0.9, 0.6, 0)
	add_child(_territory)

	# --- Quest tracker (top right) ---
	_quest = Label.new()
	_quest.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_quest.position = Vector2(-470, 42)
	_quest.custom_minimum_size = Vector2(455, 0)
	_quest.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest.add_theme_font_size_override("font_size", 15)
	_quest.modulate = Color(0.75, 0.95, 1.0)
	add_child(_quest)

	# --- Inventory panel (TAB) ---
	_inv_panel = PanelContainer.new()
	_inv_panel.set_anchors_preset(Control.PRESET_CENTER)
	_inv_panel.position = Vector2(-390, -170)
	_inv_panel.custom_minimum_size = Vector2(780, 330)
	_inv_panel.visible = false
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_inv_panel.add_child(vbox)
	var inv_title := Label.new()
	inv_title.text = "INVENTORY"
	inv_title.add_theme_font_size_override("font_size", 22)
	inv_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(inv_title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	vbox.add_child(columns)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	columns.add_child(grid)
	for i in 12:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(112, 58)
		btn.text = "-"
		btn.pressed.connect(_on_inv_slot.bind(i))
		grid.add_child(btn)
		_inv_buttons.append(btn)
	# Crafting column
	var craft_box := VBoxContainer.new()
	craft_box.add_theme_constant_override("separation", 6)
	columns.add_child(craft_box)
	var craft_title := Label.new()
	craft_title.text = "CRAFT"
	craft_title.add_theme_font_size_override("font_size", 18)
	craft_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	craft_box.add_child(craft_title)
	for i in 5:
		var cbtn := Button.new()
		cbtn.custom_minimum_size = Vector2(240, 40)
		cbtn.pressed.connect(_on_craft.bind(i))
		craft_box.add_child(cbtn)
		_craft_buttons.append(cbtn)
	var hint := Label.new()
	hint.text = "Click an item to use or equip it  ·  TAB to close"
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.7)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)
	add_child(_inv_panel)


func _process(delta: float) -> void:
	_update_stats(delta)
	if _territory_left > 0.0:
		_territory_left -= delta
		if _territory_left <= 1.0:
			_territory.modulate.a = maxf(0.0, _territory_left)
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


func set_time(day: int, hour24: float, is_night: bool) -> void:
	var hh := int(hour24)
	var mm := int((hour24 - hh) * 60.0)
	_clock.text = "DAY %d   %02d:%02d" % [day, hh, mm]
	_clock.modulate = Color(0.62, 0.72, 1.0, 0.95) if is_night else Color(1, 1, 1, 0.85)


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


# ---------------------------------------------------------------- inventory

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and not _death.visible \
			and not get_tree().paused:
		toggle_inventory()


func toggle_inventory() -> void:
	_inv_open = not _inv_open
	_inv_panel.visible = _inv_open
	if player:
		player.set("ui_lock", _inv_open)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _inv_open \
			else Input.MOUSE_MODE_CAPTURED
	if _inv_open:
		refresh_inventory()


func refresh_inventory() -> void:
	if not _inv_open or player == null:
		return
	var inv: Node = player.get("inventory")
	for i in _inv_buttons.size():
		var btn: Button = _inv_buttons[i]
		var it = inv.slots[i]
		if it == null:
			btn.text = "-"
			btn.disabled = true
			btn.tooltip_text = ""
		else:
			var def: Dictionary = inv.DEFS[it["id"]]
			var line: String = def["label"]
			if it.has("dur"):
				line += "\n%d durability" % it["dur"]
			elif it["count"] > 1 or def["stack"] > 1:
				line += "\nx%d" % it["count"]
			btn.text = line
			btn.disabled = false
			btn.tooltip_text = def.get("hint", "")
	for i in _craft_buttons.size():
		var cbtn: Button = _craft_buttons[i]
		var r: Dictionary = inv.RECIPES[i]
		var needs := []
		for id in r["needs"]:
			needs.append("%d %s" % [r["needs"][id], inv.DEFS[id]["label"]])
		var result: String = inv.DEFS[r["id"]]["label"]
		if r["count"] > 1:
			result += " x%d" % r["count"]
		cbtn.text = "%s  <  %s" % [result, " + ".join(needs)]
		cbtn.disabled = not inv.can_craft(i)


func _on_inv_slot(i: int) -> void:
	if player:
		player.call("use_inventory_slot", i)
	refresh_inventory()


func _on_craft(i: int) -> void:
	if player:
		player.call("craft_recipe", i)
	refresh_inventory()


func set_quest(text: String) -> void:
	_quest.text = text


func set_territory(text: String) -> void:
	_territory.text = text
	_territory_left = 3.5
	_territory.modulate.a = 1.0


func set_weather(label: String) -> void:
	_weather_label.text = label


func _update_stats(delta: float) -> void:
	if Input.is_action_just_pressed("debug_stats"):
		_stats_label.visible = not _stats_label.visible
	if not _stats_label.visible:
		return
	_stats_accum -= delta
	if _stats_accum > 0.0:
		return
	_stats_accum = 0.25
	var streamer := get_tree().get_first_node_in_group("streamer")
	var cells: int = streamer.cell_count() if streamer else 0
	_stats_label.text = "FPS %d   frame %.1f ms\ndraw calls %d   objects %d\nvideo mem %.0f MB   streamed cells %d" % [
		Performance.get_monitor(Performance.TIME_FPS),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		cells]
