@tool
extends EditorPlugin

const PAINT_SHADER_LIT := preload("res://addons/vertex_studio/shaders/vertex_studio_lit.gdshader")
const PAINT_SHADER_UNLIT := preload("res://addons/vertex_studio/shaders/vertex_studio_unlit.gdshader")
## Token embedded in every paint shader (see the .gdshader files) so we can recognize
## runtime-generated filter/sampling variants
const PAINT_SHADER_MARKER := "vertex_studio_paint"
## BaseMaterial3D.TextureFilter: sampler filter hint to inject into the paint shader/setup material
const _FILTER_HINTS := {
	BaseMaterial3D.TEXTURE_FILTER_NEAREST: "filter_nearest",
	BaseMaterial3D.TEXTURE_FILTER_LINEAR: "filter_linear",
	BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS: "filter_nearest_mipmap",
	BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS: "filter_linear_mipmap",
	BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC: "filter_nearest_mipmap_anisotropic",
	BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC: "filter_linear_mipmap_anisotropic",
}
## Sampler line in the base paint shaders (filter variants extend its hint list)
const _SAMPLER_DECL := "albedo_texture : source_color, hint_default_white;"
const PREFS_DIR := "res://.vertex_studio"
const PREFS_PATH := "res://.vertex_studio/prefs.cfg"
## Show panel by default when a mesh is selected?
const PANEL_DEFAULT_VISIBLE := false
## Opacity shortcut settings
const OPACITY_STEP := 0.05
const OPACITY_RATE := 0.75

var _state: VSState
var _save_timer: Timer
var _settings_save_timer: Timer
var _painter: VSPainter
var _overlay: VSOverlay
var _panel: VSPanel
var _menu_button: Button

var _current_node: Node
var _last_camera: Camera3D

var _painting := false
var _stroke_touched := false
var _stroke_is_normals := false
var _stroke_before: Array = []
var _eyedrop_dest: StringName = &""

var _selecting := false
var _sel_start := Vector2.ZERO
var _sel_points := PackedVector2Array()
var _sel_mode := 0

var _point_selecting := false
var _point_sel_mode := 0

var _save_dialog: EditorFileDialog
var _load_dialog: EditorFileDialog

var _snap_save_thread: Thread
var _snap_load_path := ""
var _snap_load_timer: Timer

var _probe_ref: RefCounted
var _ui_busy_action := ""
var _ui_block_overlay: ColorRect
var _ui_block_label: Label
var _ui_block_dots := 0
var _ui_block_dots_timer: Timer
var _ui_block_label_base := ""
var _ui_pending_retarget := false

var _fill_thread: Thread
var _fill_before: Array = []

var _shader_variants: Dictionary = {}

var _swatch_png_dialog: EditorFileDialog
var _swatch_save_dialog: EditorFileDialog
var _swatch_load_dialog: EditorFileDialog
var _resync_model_dialog: EditorFileDialog
var _resync_confirm_dialog: ConfirmationDialog
var _resync_confirm_label: Label
var _resync_dont_ask_cb: CheckBox
var _pending_resync_sources: Array = []

var _resync_skip_prompt: Dictionary = {}

var _info_dialog: AcceptDialog
var _snapshot_delete_dialog: ConfirmationDialog
var _snapshot_pending_delete := ""

var _vgroup_name_dialog: AcceptDialog
var _vgroup_name_edit: LineEdit
var _vgroup_delete_dialog: ConfirmationDialog
var _vgroup_pending_delete := ""
var _vgroup_active := ""

var _material_entries: Array = []

var _prev_tool_enabled := false
var _saved_dock_tab := -1

var _commit_mode_touched: Dictionary = {}

var _swatch_index := -1

var _inc_key := KEY_BRACKETRIGHT
var _dec_key := KEY_BRACKETLEFT
var _op_inc_key := KEY_SLASH
var _op_dec_key := KEY_BACKSLASH

var _realtime_tri_limit := VSSettings.REALTIME_TRI_LIMIT_DEFAULT

var _brush_dir := 0                       

var _opacity_dir := 0

var _key_actions: Array[Array] = []

var _open_meshes: Dictionary = {}

var _dense_hidden := false
var _dense_prev_always := false
var _very_dense_hidden := false
var _very_dense_prev_show := false


func _enter_tree() -> void:
	_register_shortcuts()
	VSStore.reload()
	_state = VSState.new()
	_load_prefs()
	_painter = VSPainter.new(_state)
	_overlay = VSOverlay.new(_state, _painter)

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.5
	_save_timer.timeout.connect(_save_prefs)
	add_child(_save_timer)

	_snap_load_timer = Timer.new()
	_snap_load_timer.wait_time = 0.05
	_snap_load_timer.timeout.connect(_poll_snapshot_load)
	add_child(_snap_load_timer)

	_state.changed.connect(_on_state_changed)
	_state.view_changed.connect(_on_view_changed)

	_panel = VSPanel.new()
	_panel.setup(_state)
	_panel.visible = false
	_panel.action_requested.connect(_on_action)
	_panel.eyedrop_requested.connect(_on_eyedrop_requested)
	_panel.eyedrop_cancelled.connect(_on_eyedrop_cancelled)
	_panel.snapshot_selected.connect(_apply_snapshot)
	_panel.runtime_toggled.connect(_on_runtime_toggled)
	_panel.swatch_menu.connect(_on_swatch_menu)
	_panel.vgroup_action.connect(_on_vgroup_action)
	_panel.select_linked_material.connect(_on_select_linked_material)
	_panel.commit_mode_selected.connect(_on_commit_mode_selected)
	_panel.theme_refreshed.connect(_on_editor_theme_changed)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, _panel)

	_menu_button = Button.new()
	_menu_button.toggle_mode = true
	_menu_button.text = "Vertex Studio"
	_menu_button.flat = true
	_menu_button.icon = _load_icon()
	_menu_button.visible = false
	_menu_button.button_pressed = PANEL_DEFAULT_VISIBLE
	_menu_button.toggled.connect(_on_menu_toggled)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _menu_button)

	_build_dialogs()

	var probe := OS.get_environment("VS_PROBE_SCRIPT")
	if probe != "" and ResourceLoader.exists(probe):
		call_deferred("_run_probe", probe)


func _run_probe(path: String) -> void:
	var script = load(path)
	if script is GDScript:
		_probe_ref = (script as GDScript).new()
		if _probe_ref.has_method("run"):
			_probe_ref.run(self)


func _exit_tree() -> void:
	if _snap_save_thread != null:
		_snap_save_thread.wait_to_finish()
		_snap_save_thread = null
	if _fill_thread != null:
		_fill_thread.wait_to_finish()
		_fill_thread = null
	_ui_busy_action = ""
	if _ui_block_overlay != null:
		_ui_block_overlay.queue_free()
		_ui_block_overlay = null
	if ProjectSettings.settings_changed.is_connected(_on_project_settings_changed):
		ProjectSettings.settings_changed.disconnect(_on_project_settings_changed)
	_flush_project_settings_save()
	VSSettings.unwatch_shortcuts(_on_shortcut_edited)
	_commit_targets()
	_focus_node_dock(false)
	_restore_dense_vertex_prefs()
	_save_prefs()
	VSStore.flush()
	_free_prewarm_viewport()
	if _menu_button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _menu_button)
		_menu_button.queue_free()
	if _panel:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, _panel)
		_panel.queue_free()
	if _save_dialog: _save_dialog.queue_free()
	if _load_dialog: _load_dialog.queue_free()
	if _swatch_png_dialog: _swatch_png_dialog.queue_free()
	if _swatch_save_dialog: _swatch_save_dialog.queue_free()
	if _swatch_load_dialog: _swatch_load_dialog.queue_free()
	if _resync_model_dialog: _resync_model_dialog.queue_free()
	if _resync_confirm_dialog: _resync_confirm_dialog.queue_free()
	if _info_dialog: _info_dialog.queue_free()


func _load_icon() -> Texture2D:
	var dir := "res://addons/vertex_studio/icons/"
	var path := dir + "vertex_studio.svg"
	if _editor_is_light_theme():
		var darker := dir + "vertex_studio_darker.svg"
		if ResourceLoader.exists(darker):
			path = darker
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _editor_is_light_theme() -> bool:
	var t := EditorInterface.get_editor_theme()
	if t and t.has_color("font_color", "Label"):
		return t.get_color("font_color", "Label").get_luminance() < 0.5
	return false


func _on_editor_theme_changed() -> void:
	if _menu_button:
		_menu_button.icon = _load_icon()


func _handles(object) -> bool:
	return object is MeshInstance3D


func _edit(object) -> void:
	if object is MeshInstance3D:
		_current_node = object
		_apply_auto_open(object as MeshInstance3D)
		_retarget()


func _apply_auto_open(mi: MeshInstance3D) -> void:
	if _menu_button == null or VSSettings.auto_open_when_mesh_selected():
		return
	var want := _open_meshes.has(VSStore.mesh_key(mi))
	if want == _menu_button.button_pressed:
		return
	_menu_button.set_pressed_no_signal(want)
	_update_visibility()


func _remember_open_mesh(open: bool) -> void:
	if _current_node == null or not is_instance_valid(_current_node):
		return
	var key := VSStore.mesh_key(_current_node)
	if key == "":
		return
	if open:
		_open_meshes[key] = true
	else:
		_open_meshes.erase(key)
	_queue_save()


func _make_visible(visible: bool) -> void:
	if not visible:
		_commit_targets()
		_focus_node_dock(false)
	if _menu_button:
		_menu_button.visible = visible
	_update_visibility()
	if visible:
		_activate_targets()
		if _should_focus_node_dock():
			_focus_node_dock(true)


func _on_menu_toggled(on: bool) -> void:
	_remember_open_mesh(on)
	if not on:
		_commit_targets()
		_focus_node_dock(false)
	_update_visibility()
	if on and _menu_button.visible:
		_retarget()
		if _should_focus_node_dock():
			_focus_node_dock(true)
	update_overlays()


func _update_visibility() -> void:
	if _panel == null or _menu_button == null:
		return
	_panel.visible = _menu_button.visible and _menu_button.button_pressed


func _retarget() -> void:
	if _current_node == null:
		return
	if _ui_busy():
		_ui_pending_retarget = true
		return
	_commit_targets()
	_painter.set_targets_from_node(_current_node)
	_apply_dense_vertex_guard()
	if _panel:
		_update_selection_info()
		_prune_missing_snapshots()
		var last := str(VSStore.get_field(_current_node, VSStore.SNAP_LAST, ""))
		_panel.set_snapshot_path(last)
		_refresh_snapshot_list()
		_vgroup_active = ""
		_refresh_vgroup_list()
		_refresh_material_list()
		_sync_runtime_panel()
		_sync_commit_mode_panel()
		_refresh_restore_hint()
	_activate_targets()
	_refresh_history()
	update_overlays()
	for md in _painter.targets:
		_prewarm_commit_material(md.mesh_instance)
		_prewarm_paint_mesh(md)


func _apply_dense_vertex_guard() -> void:
	_apply_always_show_guard()
	_apply_show_vertices_guard()


func _apply_always_show_guard() -> void:
	if not VSSettings.auto_hide_dense_vertices():
		_restore_always_show_pref()
		return
	var dense := _painter.total_vertices() >= VSSettings.dense_vertex_count()
	if dense == _dense_hidden:
		return
	if dense:
		_dense_prev_always = _state.always_show_vertices
		_dense_hidden = true
		_state.always_show_vertices = false
		if _panel:
			_panel.refresh()
	else:
		_restore_always_show_pref()


func _apply_show_vertices_guard() -> void:
	if not VSSettings.auto_hide_very_dense_vertices():
		_restore_show_vertices_pref()
		return
	var very_dense := _painter.total_vertices() >= VSSettings.very_dense_vertex_count()
	if very_dense == _very_dense_hidden:
		return
	if very_dense:
		_very_dense_prev_show = _state.show_vertices
		_very_dense_hidden = true
		_state.show_vertices = false
		if _panel:
			_panel.refresh()
	else:
		_restore_show_vertices_pref()


func _restore_dense_vertex_prefs() -> void:
	_restore_always_show_pref()
	_restore_show_vertices_pref()


func _restore_always_show_pref() -> void:
	if not _dense_hidden:
		return
	_dense_hidden = false
	if not _state.always_show_vertices:
		_state.always_show_vertices = _dense_prev_always
	if _panel:
		_panel.refresh()


func _restore_show_vertices_pref() -> void:
	if not _very_dense_hidden:
		return
	_very_dense_hidden = false
	if not _state.show_vertices:
		_state.show_vertices = _very_dense_prev_show
	if _panel:
		_panel.refresh()


func _snapshot_history() -> PackedStringArray:
	var v = VSStore.get_field(_current_node, VSStore.SNAP_HISTORY, PackedStringArray())
	if v is PackedStringArray:
		return v
	if v is Array:
		return PackedStringArray(v)
	return PackedStringArray()


func _refresh_snapshot_list() -> void:
	if _panel:
		_panel.set_snapshot_history(_snapshot_history(), _state.snapshot_path)
	_refresh_runtime_nodes()


func _find_runtime(node: Node) -> VSRuntime:
	if node == null:
		return null
	var c := node.get_node_or_null("VSRuntime")
	return c as VSRuntime if c is VSRuntime else null


func _sync_runtime_meta(mi: MeshInstance3D) -> VSRuntime:
	if mi == null:
		return null
	var rt := _find_runtime(mi)
	VSStore.set_field(mi, VSStore.HAS_RUNTIME, true if rt != null else null)
	return rt


func _sync_runtime_panel() -> void:
	if _panel == null or _current_node == null or not (_current_node is MeshInstance3D):
		return
	var mi := _current_node as MeshInstance3D
	_sync_runtime_meta(mi)
	_panel.set_runtime_node_present(bool(VSStore.get_field(mi, VSStore.HAS_RUNTIME, false)))


func _refresh_runtime_nodes() -> void:
	if _current_node == null or not is_instance_valid(_current_node):
		return
	for c in _current_node.get_children():
		if c is VSRuntime:
			(c as VSRuntime).refresh_snapshot_options()
			c.notify_property_list_changed()


func _on_runtime_toggled(_enabled: bool) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _prune_missing_snapshots() -> void:
	if _current_node == null or not is_instance_valid(_current_node):
		return
	var kept := PackedStringArray()
	var changed := false
	for p in _snapshot_history():
		if p != "" and FileAccess.file_exists(p):
			kept.append(p)
		else:
			changed = true
	if changed:
		VSStore.set_field(_current_node, VSStore.SNAP_HISTORY, null if kept.is_empty() else kept)
	var last_snap := str(VSStore.get_field(_current_node, VSStore.SNAP_LAST, ""))
	if last_snap != "" and not FileAccess.file_exists(last_snap):
		VSStore.set_field(_current_node, VSStore.SNAP_LAST, null)


func _remember_snapshot(_path: String) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


# ----------------------------------------------------------------
# 3D input
# ----------------------------------------------------------------

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	_last_camera = camera
	if _ui_busy():
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if not _panel.visible or not _painter.has_targets():
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if _state.tool_mode == VSState.ToolMode.SELECT:
		return _handle_select_input(camera, event)

	if event is InputEventMouseMotion:
		_overlay.mouse = event.position
		_overlay.mouse_inside = true
		if _state.operation == VSState.Op.PRECISION and _state.tool_enabled:
			_painter.precision_update(camera, event.position)
		else:
			_painter.clear_precision_lock()
		update_overlays()
		if _painting:
			_do_paint(camera, event.position)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _eyedrop_dest != &"" and event.pressed:
			_do_eyedrop(camera, event.position)
			return EditorPlugin.AFTER_GUI_INPUT_STOP

		if not _state.tool_enabled:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

		if event.pressed:
			_begin_stroke()
			_do_paint(camera, event.position)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			_end_stroke()
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _forward_3d_draw_over_viewport(overlay: Control) -> void:
	if not _panel.visible or _ui_busy():
		return
	_overlay.draw(overlay, _last_camera)
	if _overlay.wants_redraw:
		_overlay.wants_redraw = false
		call_deferred("update_overlays")


func _handle_select_input(camera: Camera3D, event: InputEvent) -> int:
	if _state.select_type == VSState.SelectType.POINT:
		return _handle_point_select_input(camera, event)

	if _state.select_type == VSState.SelectType.LINKED:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseMotion:
		_overlay.mouse = event.position
		_overlay.mouse_inside = true
		_overlay.sel_modifier = _sel_modifier_from(event)
		if _selecting:
			if _state.select_type == VSState.SelectType.LASSO:
				if _sel_points.is_empty() or _sel_points[_sel_points.size() - 1].distance_to(event.position) > 3.0:
					_sel_points.append(event.position)
			else:
				_sel_points = PackedVector2Array([_sel_start, event.position])
			_overlay.sel_points = _sel_points
			update_overlays()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not _state.tool_enabled:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		if event.pressed:
			_refocus_node_dock_if_needed()
			_selecting = true
			_sel_start = event.position
			if _state.select_type == VSState.SelectType.LASSO:
				_sel_points = PackedVector2Array([event.position])
			else:
				_sel_points = PackedVector2Array([event.position, event.position])
			_sel_mode = 0
			if event.shift_pressed:
				_sel_mode = 1
			elif event.ctrl_pressed or event.alt_pressed:
				_sel_mode = 2
			_overlay.selecting = true
			_overlay.sel_type = _state.select_type
			_overlay.sel_points = _sel_points
			update_overlays()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			if _selecting:
				_selecting = false
				_overlay.selecting = false
				_painter.select_marquee(camera, _sel_points, _state.select_type, _sel_mode)
				_sel_points = PackedVector2Array()
				_overlay.sel_points = _sel_points
				_update_selection_info()
				update_overlays()
				return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _handle_point_select_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouseMotion:
		_overlay.mouse = event.position
		_overlay.mouse_inside = true
		_overlay.sel_modifier = _sel_modifier_from(event)
		if _point_selecting:
			if _point_select_drag(camera, event):
				_update_selection_info()
			update_overlays()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not _state.tool_enabled:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		if event.pressed:
			_refocus_node_dock_if_needed()
			_point_selecting = true
			_point_sel_mode = 0
			if event.shift_pressed:
				_point_sel_mode = 1
			elif event.ctrl_pressed or event.alt_pressed:
				_point_sel_mode = 2
			_painter.select_point(camera, event.position, _point_sel_mode)
			_update_selection_info()
			update_overlays()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			_point_selecting = false
			_update_selection_info()
			update_overlays()
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _point_select_drag(_camera: Camera3D, _event: InputEvent) -> bool:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	return false


func _sel_modifier_from(event: InputEvent) -> int:
	if event is InputEventWithModifiers:
		if event.shift_pressed:
			return 1
		if event.alt_pressed or event.ctrl_pressed:
			return 2
	return 0


func _live_sel_modifier() -> int:
	if Input.is_key_pressed(KEY_SHIFT):
		return 1
	if Input.is_key_pressed(KEY_ALT) or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
		return 2
	return 0


func _update_selection_info() -> void:
	if _panel:
		_panel.set_target_info(_painter.targets.size(), _painter.total_vertices(),
			_painter.total_selected(), _painter.total_triangles())
		_panel.set_selection_active(_painter.has_selection())


func _begin_stroke() -> void:
	_painting = true
	_stroke_touched = false
	_stroke_is_normals = _state.operation == VSState.Op.NORMALS
	if _stroke_is_normals:
		_stroke_before = _painter.snapshot_surfaces_all()
	elif _painter.all_native():
		_stroke_before = []
		_painter.begin_stroke()
	else:
		_stroke_before = _painter.snapshot_all()
		_painter.begin_stroke()
	_refocus_node_dock_if_needed()


func _do_paint(camera: Camera3D, pos: Vector2) -> void:
	var touched: bool
	match _state.operation:
		VSState.Op.PRECISION:
			touched = _painter.paint_precision(camera, pos)
		VSState.Op.NORMALS:
			touched = _painter.paint_normals(camera, pos, _state.normals_mode == VSState.NormalsMode.SMOOTH)
		VSState.Op.BLUR:
			touched = _painter.paint_blur(camera, pos)
		_:
			touched = _painter.paint(camera, pos)
	if touched:
		_stroke_touched = true
		if _state.realtime_painting and _painter.total_triangles() <= _realtime_tri_limit:
			_painter.commit()
		update_overlays()


func _end_stroke() -> void:
	if not _painting:
		return
	_painting = false
	var native := not _stroke_is_normals and _painter.all_native()
	var sparse: Array = []
	if not _stroke_is_normals:
		if native:
			sparse = _painter.end_stroke_collect()
		else:
			_painter.end_stroke()
	if not _stroke_touched:
		return
	_painter.commit()
	update_overlays()
	if _stroke_is_normals:
		_update_selection_info()
		_push_surface_undo("Paint Normals", _stroke_before, _painter.snapshot_surfaces_all())
	elif native:
		_push_sparse_undo("Vertex Studio: Paint", sparse)
	else:
		_push_undo("Vertex Studio: Paint", _stroke_before, _painter.snapshot_all(), false)


func _do_eyedrop(camera: Camera3D, pos: Vector2) -> void:
	var sampled = _painter.sample(camera, pos, maxf(_state.radius, 24.0))
	if sampled != null:
		match _eyedrop_dest:
			&"color": _panel.set_color(sampled)
			&"replace_target": _panel.set_replace_color(&"replace_target", sampled)
			&"replace_new": _panel.set_replace_color(&"replace_new", sampled)
	_eyedrop_dest = &""
	_overlay.eyedropper = false
	_panel.clear_eyedrop()
	update_overlays()


#region Undo/redo
# ----------------------------------------------------------------
# Undo/redo
# ----------------------------------------------------------------

func _push_undo(action_name: String, before: Array, after: Array, execute: bool) -> void:
	var ur := get_undo_redo()
	var ctx: Object = _painter.targets[0].mesh_instance if _painter.has_targets() else null
	ur.create_action(action_name, UndoRedo.MERGE_DISABLE, ctx)
	ur.add_do_method(self, "_apply_colors", after)
	ur.add_undo_method(self, "_apply_colors", before)
	ur.commit_action(execute)
	_refresh_history()
	update_overlays()


func _apply_colors(data: Array) -> void:
	if _ui_busy():
		push_warning("Vertex Studio: undo ignored while '%s' is running" % _ui_busy_action)
		return
	_painter.restore_all(data)
	update_overlays()


func _push_sparse_undo(action_name: String, entries: Array) -> void:
	var ur := get_undo_redo()
	var ctx: Object = _painter.targets[0].mesh_instance if _painter.has_targets() else null
	ur.create_action(action_name, UndoRedo.MERGE_DISABLE, ctx)
	ur.add_do_method(self, "_apply_sparse", entries, true)
	ur.add_undo_method(self, "_apply_sparse", entries, false)
	ur.commit_action(false)
	_refresh_history()
	update_overlays()


func _apply_sparse(entries: Array, after: bool) -> void:
	if _ui_busy():
		push_warning("Vertex Studio: undo ignored while '%s' is running" % _ui_busy_action)
		return
	for i in mini(entries.size(), _painter.targets.size()):
		var e = entries[i]
		if not (e is Dictionary):
			continue
		var md: VSMeshData = _painter.targets[i]
		if md.nat == null:
			continue
		md.ensure_paint_ready()
		md.nat.apply_sparse(e["indices"], e["after"] if after else e["before"])
		md.mark_colors_dirty()
	update_overlays()


func _push_surface_undo(_action_name: String, _before: Array, _after: Array) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _apply_surfaces(_data: Array) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _history() -> UndoRedo:
	var ur := get_undo_redo()
	var id := EditorUndoRedoManager.GLOBAL_HISTORY
	if _painter.has_targets():
		id = ur.get_object_history_id(_painter.targets[0].mesh_instance)
	return ur.get_history_undo_redo(id)


func _refresh_history() -> void:
	if _panel == null:
		return
	var h := _history()
	_panel.set_undo_redo_enabled(h != null and h.has_undo(), h != null and h.has_redo())


#endregion Undo/redo


#region State reactions
# ----------------------------------------------------------------
# State reactions
# ----------------------------------------------------------------

func _on_state_changed() -> void:
	update_overlays()
	_update_materials()
	_queue_save()
	if _state.tool_enabled != _prev_tool_enabled:
		_prev_tool_enabled = _state.tool_enabled
		if _state.auto_focus_node_tab:
			_focus_node_dock(_should_focus_node_dock())


func _should_focus_node_dock() -> bool:
	return _is_vs_open() and _state.tool_enabled and _state.auto_focus_node_tab


func _refocus_node_dock_if_needed() -> void:
	if _should_focus_node_dock():
		_focus_node_dock(true)


func _focus_node_dock(active: bool) -> void:
	var tc := _inspector_tab_container()
	if tc == null or tc.get_tab_count() < 2:
		return
	if active:
		if _saved_dock_tab < 0:
			_saved_dock_tab = tc.current_tab
		var target := -1
		var insp_tab := -1
		for i in tc.get_tab_count():
			var ctrl := tc.get_tab_control(i)
			if ctrl.is_class("NodeDock"):
				target = i
			elif ctrl.is_class("InspectorDock"):
				insp_tab = i
		if target < 0:
			for i in tc.get_tab_count():
				if i != insp_tab:
					target = i
					break
		if target >= 0:
			tc.current_tab = target
	else:
		if _saved_dock_tab >= 0 and _saved_dock_tab < tc.get_tab_count():
			tc.current_tab = _saved_dock_tab
		_saved_dock_tab = -1


func _focus_inspector_dock() -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _inspector_tab_container() -> TabContainer:
	var n: Node = EditorInterface.get_inspector()
	while n != null and not (n is TabContainer):
		n = n.get_parent()
	return n as TabContainer


func _queue_save() -> void:
	if _save_timer:
		_save_timer.start(0.5)


func _load_prefs() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PREFS_PATH) == OK:
		var d = cfg.get_value("prefs", "data", {})
		if d is Dictionary:
			_state.from_dict(d)
		var skip = cfg.get_value("resync", "skip_prompt", {})
		if skip is Dictionary:
			_resync_skip_prompt = skip
		var opened = cfg.get_value("panel", "open_meshes", {})
		if opened is Dictionary:
			_open_meshes = opened
	if VSPro.locked(VSPro.Feature.SINGLE_CHANNEL):
		_state.set_channel_rgba()
	_clamp_pro_select_tools()


func _clamp_pro_select_tools() -> void:
	var pro_only := {
		VSState.SelectType.LASSO: VSPro.Feature.SELECT_LASSO,
		VSState.SelectType.RECTANGLE: VSPro.Feature.SELECT_RECTANGLE,
		VSState.SelectType.ELLIPSE: VSPro.Feature.SELECT_ELLIPSE,
		VSState.SelectType.LINKED: VSPro.Feature.SELECT_LINKED,
	}

	if pro_only.has(_state.select_type) and VSPro.locked(pro_only[_state.select_type]):
		_state.select_type = VSState.SelectType.POINT


func _save_prefs() -> void:
	if not DirAccess.dir_exists_absolute(PREFS_DIR):
		DirAccess.make_dir_recursive_absolute(PREFS_DIR)
	var cfg := ConfigFile.new()
	cfg.set_value("prefs", "data", _state.to_dict())
	cfg.set_value("resync", "skip_prompt", _resync_skip_prompt)
	cfg.set_value("panel", "open_meshes", _open_meshes)
	cfg.save(PREFS_PATH)


func _on_view_changed() -> void:
	_update_materials()


func _update_materials() -> void:
	for md in _painter.targets:
		var mi = md.mesh_instance
		if not is_instance_valid(mi) or mi.mesh == null:
			continue
		_apply_view_uniforms(mi.material_override)
		for i in mi.mesh.get_surface_count():
			_apply_view_uniforms(mi.get_active_material(i))


func _apply_view_uniforms(mat) -> void:
	if mat is ShaderMaterial and mat.shader != null and _is_paint_shader(mat):
		mat.set_shader_parameter("use_vertex_color", _state.show_vertex_colors)
		mat.set_shader_parameter("use_texture", _state.show_textured)
		mat.set_shader_parameter("debug_channel", _state.debug_channel)


#endregion State reactions


#region Panel actions
# ----------------------------------------------------------------
# Panel actions
# ----------------------------------------------------------------

func _on_action(action: StringName) -> void:
	if _ui_busy():
		_toast("Vertex Studio: busy (%s)..." % _ui_busy_action.to_lower(), 1)
		return
	match action:
		&"retarget": _retarget()
		&"refresh_target_info": _update_selection_info()
		&"setup_material_unlit": _setup_targets(true, false)
		&"setup_material_lit": _setup_targets(true, true)
		&"commit_material": _commit_targets(true)
		&"select_all":
			_painter.select_all()
			_update_selection_info()
			update_overlays()
		&"deselect":
			_painter.clear_selection()
			_update_selection_info()
			update_overlays()
		&"invert_selection":
			_painter.invert_selection()
			_update_selection_info()
			update_overlays()
		&"fill_all": _action_with_undo("Fill All", func(): _painter.fill_all(_state.color))
		&"erase_all": _action_with_undo("Erase All", func(): _painter.erase_all())
		&"replace": _action_with_undo("Replace Color", func():
			_painter.replace_color(_state.replace_target, _state.replace_new, _state.replace_threshold))
		&"fill_hard": _fill_normals_routed(false)
		&"fill_smooth": _fill_normals_routed(true)
		&"snapshot_new": _snapshot_new()
		&"snapshot_save": _snapshot_save()
		&"snapshot_load": _snapshot_load()
		&"snapshot_reload": _snapshot_reload()
		&"snapshot_delete": _snapshot_delete()
		&"resync_uvs": _resync_uvs()
		&"undo": _menu_undo()
		&"redo": _menu_redo()
		&"falloff_editor": _focus_inspector_dock()


func _action_with_undo(label: String, fn: Callable) -> void:
	if not _painter.has_targets():
		return
	var before := _painter.snapshot_all()
	fn.call()
	var after := _painter.snapshot_all()
	_push_undo("Vertex Studio: " + label, before, after, false)


func _normals_action_with_undo(_label: String, _fn: Callable) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _ui_busy() -> bool:
	return _ui_busy_action != ""


func _begin_blocking_ui(action_name: String, detail := "") -> bool:
	if _ui_busy():
		_toast("Vertex Studio: busy (%s)..." % _ui_busy_action.to_lower(), 1)
		return false
	_ui_busy_action = action_name
	_show_ui_block_overlay(action_name, detail)
	_toast("Vertex Studio: %s running..." % action_name.to_lower())
	return true


func _end_blocking_ui(done_msg := "") -> void:
	_ui_busy_action = ""
	_hide_ui_block_overlay()
	if done_msg != "":
		_toast("Vertex Studio: " + done_msg)
	if _ui_pending_retarget:
		_ui_pending_retarget = false
		_retarget()


func _fill_normals_routed(_smooth: bool) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _fill_normals_async(_smooth: bool, _label: String) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _fill_normals_job(_jobs: Array, _smooth: bool, _sel_on: bool) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _on_fill_normals_done(_jobs: Array) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _show_ui_block_overlay(label: String, detail := "") -> void:
	if _ui_block_overlay == null:
		_ui_block_overlay = ColorRect.new()
		_ui_block_overlay.color = Color(0.0, 0.0, 0.0, 0.45)
		_ui_block_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		_ui_block_label = Label.new()
		_ui_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ui_block_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_ui_block_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_ui_block_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var theme := EditorInterface.get_editor_theme()
		if theme != null and theme.has_font("bold", "EditorFonts"):
			_ui_block_label.add_theme_font_override("font", theme.get_font("bold", "EditorFonts"))
		_ui_block_label.add_theme_font_size_override("font_size", 24)
		_ui_block_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		_ui_block_label.add_theme_constant_override("shadow_offset_y", 2)
		_ui_block_overlay.add_child(_ui_block_label)
		_ui_block_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		EditorInterface.get_base_control().add_child(_ui_block_overlay)
		var host := EditorInterface.get_editor_main_screen()
		if host != null and not host.resized.is_connected(_sync_ui_block_rect):
			host.resized.connect(_sync_ui_block_rect)
		_ui_block_dots_timer = Timer.new()
		_ui_block_dots_timer.wait_time = 0.4
		_ui_block_dots_timer.timeout.connect(_animate_ui_block_overlay)
		_ui_block_overlay.add_child(_ui_block_dots_timer)
	_ui_block_label_base = "Vertex Studio - " + label
	if detail != "":
		_ui_block_label_base += " (%s)" % detail
	_ui_block_dots = 0
	_animate_ui_block_overlay()
	_sync_ui_block_rect()
	_ui_block_overlay.visible = true
	_ui_block_dots_timer.start()


func _sync_ui_block_rect() -> void:
	if _ui_block_overlay == null or not is_instance_valid(_ui_block_overlay):
		return
	var host := EditorInterface.get_editor_main_screen()
	var base := EditorInterface.get_base_control()
	if host == null or base == null:
		return
	_ui_block_overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_ui_block_overlay.global_position = host.global_position
	_ui_block_overlay.size = host.size
	if _ui_block_label != null and is_instance_valid(_ui_block_label):
		_ui_block_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _animate_ui_block_overlay() -> void:
	if _ui_block_label == null:
		return
	_ui_block_dots = (_ui_block_dots % 3) + 1
	_ui_block_label.text = _ui_block_label_base + ".".repeat(_ui_block_dots)


func _hide_ui_block_overlay() -> void:
	if _ui_block_overlay != null:
		_ui_block_dots_timer.stop()
		_ui_block_overlay.visible = false


static func _grouped_count(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


func _on_eyedrop_requested(dest: StringName) -> void:
	_eyedrop_dest = dest
	_overlay.eyedropper = true
	update_overlays()


func _on_eyedrop_cancelled() -> void:
	_eyedrop_dest = &""
	_overlay.eyedropper = false
	update_overlays()


func _menu_undo() -> void:
	var h := _history()
	if h and h.has_undo():
		h.undo()
	_refresh_history()


func _menu_redo() -> void:
	var h := _history()
	if h and h.has_redo():
		h.redo()
	_refresh_history()


#endregion Panel actions


#region Material setup
# ----------------------------------------------------------------
# Material setup
# ----------------------------------------------------------------

func _setup_targets(mark: bool, lit: bool) -> void:
	for md in _painter.targets:
		if not is_instance_valid(md.mesh_instance):
			continue
		_setup_single(md.mesh_instance, lit)
		if mark:
			_state.setup_meshes[str(md.mesh_instance.get_path())] = "lit" if lit else "unlit"
	if mark:
		_queue_save()
	update_overlays()


func _is_vs_open() -> bool:
	return _panel != null and _panel.visible


func _activate_targets() -> void:
	if _painter == null or not _is_vs_open():
		return
	for md in _painter.targets:
		var mi = md.mesh_instance
		if not is_instance_valid(mi):
			continue
		_sync_runtime_meta(mi)
		if _state.setup_meshes.has(str(mi.get_path())):
			_setup_single(mi, _setup_entry_lit(_state.setup_meshes[str(mi.get_path())]))


func _setup_entry_lit(entry: Variant) -> bool:
	if entry is String:
		return entry != "unlit"
	return true


func _setup_single(mi: MeshInstance3D, lit: bool) -> void:
	if mi == null or mi.mesh == null:
		return
	_capture_original(mi)
	for i in mi.mesh.get_surface_count():
		var src := _surface_source(mi, i)
		mi.set_surface_override_material(i, _make_paint_material(src["texture"], lit, src["filter"]))


func _capture_original(mi: MeshInstance3D) -> void:
	if VSStore.get_field(mi, VSStore.ORIG_OVERRIDES) != null:
		return
	var orig: Array = []
	for i in mi.mesh.get_surface_count():
		var m = mi.get_surface_override_material(i)
		if _is_paint_shader(m):
			m = null
		orig.append(m)
	VSStore.set_field(mi, VSStore.ORIG_OVERRIDES, orig)


func _commit_mode_for(mi: MeshInstance3D) -> int:
	return int(VSStore.get_field(mi, VSStore.COMMIT_MODE, _state.commit_mode))


func _on_commit_mode_selected(mode: int) -> void:
	var meshes: Array = []
	var before: Array = []
	var after: Array = []
	var already := true
	for md in _painter.targets:
		var mi = md.mesh_instance
		if not is_instance_valid(mi):
			continue
		meshes.append(mi)
		var stored: Variant = VSStore.get_field(mi, VSStore.COMMIT_MODE)
		before.append(stored)
		after.append(mode)
		if stored == null or int(stored) != mode:
			already = false
	if meshes.is_empty():
		_set_default_commit_mode(mode)
		return
	if already:
		return
	var ur := get_undo_redo()
	ur.create_action("Vertex Studio: On restore", UndoRedo.MERGE_DISABLE, meshes[0])
	ur.add_do_method(self, "_apply_commit_mode", meshes, after, mode)
	ur.add_undo_method(self, "_apply_commit_mode", meshes, before, _state.commit_mode)
	ur.commit_action()
	if EditorInterface.get_edited_scene_root() != null:
		EditorInterface.mark_scene_as_unsaved()
	for mi in meshes:
		_commit_mode_touched[VSStore.mesh_key(mi)] = true
		_prewarm_commit_material(mi)
	_refresh_restore_hint()
	_refresh_history()


func _apply_commit_mode(meshes: Array, modes: Array, default_mode: int) -> void:
	for i in mini(meshes.size(), modes.size()):
		var mi = meshes[i]
		if is_instance_valid(mi):
			VSStore.set_field(mi, VSStore.COMMIT_MODE, modes[i])
	_set_default_commit_mode(default_mode)
	_sync_commit_mode_panel()


func _set_default_commit_mode(mode: int) -> void:
	_state.commit_mode = mode
	_state.emit_changed()
	if _panel != null:
		_panel.set_commit_mode(mode)


func _sync_commit_mode_panel() -> void:
	if _panel == null or not _painter.has_targets():
		return
	var mi = _painter.targets[0].mesh_instance
	if is_instance_valid(mi):
		_panel.set_commit_mode(_commit_mode_for(mi))


func _refresh_restore_hint() -> void:
	if _panel == null:
		return
	var show := false
	for md in _painter.targets:
		var mi = md.mesh_instance
		if not is_instance_valid(mi):
			continue
		if not _commit_mode_touched.get(VSStore.mesh_key(mi), false):
			continue
		if bool(VSStore.get_field(mi, VSStore.RESTORE_APPLIED, false)):
			continue
		if _is_setup(mi) or _is_vs_managed(mi):
			continue
		show = true
		break
	_panel.set_restore_hint(show)


func _commit_targets(explicit := false) -> void:
	if _painter == null:
		return
	_painter.sync_for_save()
	for md in _painter.targets:
		if is_instance_valid(md.mesh_instance):
			var mi := md.mesh_instance
			_commit_single(mi, explicit)
			if explicit:
				VSStore.set_field(mi, VSStore.RESTORE_APPLIED, true)
			if not bool(VSStore.get_field(mi, VSStore.HAS_RUNTIME, false)):
				continue
			var rt := _sync_runtime_meta(mi)
			if rt != null and rt.get_active_snapshot() == "":
				rt.capture_baseline()
	if explicit:
		_refresh_restore_hint()
	update_overlays()


func _apply_changes() -> void:
	if _painter == null or not _painter.has_targets():
		return
	if _ui_busy():
		push_warning("Vertex Studio: scene saved while '%s' was running; save again once it finishes." % _ui_busy_action)
		return
	_painter.sync_for_save()
	var stripped := false
	for md in _painter.targets:
		var mi = md.mesh_instance
		if not is_instance_valid(mi):
			continue
		var was_setup := _is_setup(mi)
		if not was_setup and not _is_vs_managed(mi):
			continue
		_commit_single(mi)
		stripped = stripped or was_setup
	VSStore.flush()
	if stripped:
		call_deferred("_activate_targets")


func _commit_single(mi: MeshInstance3D, explicit := false) -> void:
	if mi == null or mi.mesh == null:
		return
	var mode := _commit_mode_for(mi)
	if not _is_setup(mi) and not _is_vs_managed(mi):
		if not explicit or mode != VSState.CommitMode.STANDARD:
			return
		_capture_original(mi)
	var sc := mi.mesh.get_surface_count()
	match mode:
		VSState.CommitMode.RESTORE:
			var orig: Array = VSStore.get_field(mi, VSStore.ORIG_OVERRIDES, [])
			for i in sc:
				mi.set_surface_override_material(i, orig[i] if i < orig.size() else null)
		VSState.CommitMode.STANDARD:
			for i in sc:
				var src := _surface_source(mi, i)
				if _is_committed_standard(mi.get_surface_override_material(i), src):
					continue
				mi.set_surface_override_material(i, _standard_commit_material(src))
		VSState.CommitMode.KEEP:
			pass


func _standard_commit_material(src: Dictionary) -> StandardMaterial3D:
	var sm := StandardMaterial3D.new()
	sm.vertex_color_use_as_albedo = true
	if src["texture"] != null:
		sm.albedo_texture = src["texture"]
		if src["filter"] >= 0:
			sm.texture_filter = src["filter"]
	return sm


#region Material prewarm
# ----------------------------------------------------------------
# Material prewarm
# ----------------------------------------------------------------
# A material variant the engine has never drawn compiles its shader and render
# pipelines on the FIRST DRAW, on the main thread. Measured in the editor with a
# cold shader cache (a freshly generated project has one): 200ms for the
# StandardMaterial3D an On restore commit produces, 774ms for a heavier variant.
# That is the whole of the reported "Restore Material freezes for a second" -
# our own work in that click is now well under a millisecond.
#
# It cannot be compiled on demand from script (there is no precompile API), but
# it CAN be paid somewhere else: drawing the same variant once in a 16x16
# offscreen viewport costs ~40ms there and leaves the real assignment at ~8ms.
# So VS warms the material a commit WOULD produce as soon as it knows it (taking
# a mesh, or picking the mode), keyed so each variant compiles once per session.

## Long enough that the click which scheduled the prewarm has been drawn and the
## user is reading the panel rather than aiming at the next control, short enough
## that the material is ready before they press Restore.
const PREWARM_DELAY := 0.3

var _prewarm_vp: SubViewport = null
var _prewarm_quad: MeshInstance3D = null

var _prewarmed: Dictionary = {}


func _prewarm_commit_material(mi: MeshInstance3D) -> void:
	if mi == null or mi.mesh == null or not is_instance_valid(mi):
		return
	if _commit_mode_for(mi) != VSState.CommitMode.STANDARD:
		return
	var pending: Array = []
	for i in mi.mesh.get_surface_count():
		var src := _surface_source(mi, i)
		var key := [src["texture"] != null, int(src["filter"])]
		if _prewarmed.has(key):
			continue
		_prewarmed[key] = true
		pending.append(_standard_commit_material(src))
	if not pending.is_empty():
		_prewarm_later(pending)


func _prewarm_paint_mesh(md: VSMeshData) -> void:
	if md == null or md.nat == null or md.nat.has_gpu():
		return
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(PREWARM_DELAY).timeout
	if not is_inside_tree() or not _is_vs_open() or not _painter.targets.has(md):
		return
	if not is_instance_valid(md.mesh_instance):
		return
	if md.prepare_paint_mesh() == null:
		return
	while md.parked_bake_pending():
		await tree.process_frame
	md._join_parked_task()


func _prewarm_later(mats: Array) -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(PREWARM_DELAY).timeout
	for m in mats:
		if not is_inside_tree() or not _is_vs_open():
			return
		_prewarm_material(m)
		await tree.process_frame


func _prewarm_material(m: Material) -> void:
	if m == null:
		return
	_ensure_prewarm_viewport()
	_prewarm_quad.material_override = m
	_prewarm_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _ensure_prewarm_viewport() -> void:
	if _prewarm_vp != null:
		return
	_prewarm_vp = SubViewport.new()
	_prewarm_vp.size = Vector2i(16, 16)
	_prewarm_vp.own_world_3d = true
	_prewarm_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 1.2)
	_prewarm_vp.add_child(cam)
	_prewarm_quad = MeshInstance3D.new()
	_prewarm_quad.mesh = QuadMesh.new()
	_prewarm_vp.add_child(_prewarm_quad)
	add_child(_prewarm_vp)


func _free_prewarm_viewport() -> void:
	if _prewarm_vp != null and is_instance_valid(_prewarm_vp):
		_prewarm_vp.queue_free()
	_prewarm_vp = null
	_prewarm_quad = null
	_prewarmed.clear()


#endregion Material prewarm


func _is_paint_shader(m) -> bool:
	if not m is ShaderMaterial or m.shader == null:
		return false
	var sh = m.shader
	var path: String = sh.resource_path
	if sh == PAINT_SHADER_LIT or sh == PAINT_SHADER_UNLIT \
			or path == PAINT_SHADER_LIT.resource_path or path == PAINT_SHADER_UNLIT.resource_path:
		return true
	return sh.code.contains(PAINT_SHADER_MARKER)


func _is_setup(mi: MeshInstance3D) -> bool:
	if mi == null or mi.mesh == null or mi.mesh.get_surface_count() == 0:
		return false
	return _is_paint_shader(mi.get_surface_override_material(0))


func _is_vs_managed(mi: MeshInstance3D) -> bool:
	return VSStore.get_field(mi, VSStore.ORIG_OVERRIDES) != null


func _is_committed_standard(m, src: Dictionary) -> bool:
	if not m is StandardMaterial3D or not m.vertex_color_use_as_albedo:
		return false
	return m.albedo_texture == src["texture"]


func _make_paint_material(tex: Texture2D, lit: bool, filter: int = -1) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _paint_shader(lit, filter)
	mat.set_shader_parameter("use_vertex_color", _state.show_vertex_colors)
	mat.set_shader_parameter("use_texture", _state.show_textured)
	mat.set_shader_parameter("debug_channel", _state.debug_channel)
	if tex != null:
		mat.set_shader_parameter("albedo_texture", tex)
		mat.set_shader_parameter("has_texture", true)
	else:
		mat.set_shader_parameter("has_texture", false)
	return mat


func _paint_shader(lit: bool, filter: int) -> Shader:
	var base: Shader = PAINT_SHADER_LIT if lit else PAINT_SHADER_UNLIT
	if not _FILTER_HINTS.has(filter):
		return base
	var key := "%s_%d" % ["lit" if lit else "unlit", filter]
	if _shader_variants.has(key):
		return _shader_variants[key]
	var variant := Shader.new()
	variant.code = base.code.replace(
		_SAMPLER_DECL,
		_SAMPLER_DECL.trim_suffix(";") + ", %s;" % _FILTER_HINTS[filter])
	_shader_variants[key] = variant
	return variant


func _surface_source(mi: MeshInstance3D, i: int) -> Dictionary:
	var candidates: Array = []
	var orig: Array = VSStore.get_field(mi, VSStore.ORIG_OVERRIDES, [])
	if i < orig.size() and orig[i] != null:
		candidates.append(orig[i])
	if mi.mesh:
		candidates.append(mi.mesh.surface_get_material(i))
	if mi.material_override:
		candidates.append(mi.material_override)
	for m in candidates:
		if m is BaseMaterial3D and m.albedo_texture:
			return {"texture": m.albedo_texture, "filter": m.texture_filter}
		if m is ShaderMaterial:
			var t = m.get_shader_parameter("albedo_texture")
			if t is Texture2D:
				return {"texture": t, "filter": -1}
	return {"texture": null, "filter": -1}


#endregion Material setup


#region Swatch palette
# ----------------------------------------------------------------
# Swatch palette
# ----------------------------------------------------------------

func _on_swatch_menu(action: StringName) -> void:
	match action:
		&"import_png": _swatch_png_dialog.popup_centered_ratio(0.6)
		&"save": _swatch_save_dialog.popup_centered_ratio(0.6)
		&"load": _swatch_load_dialog.popup_centered_ratio(0.6)


func _import_png_palette(path: String) -> void:
	var img := Image.new()
	if img.load(path) != OK:
		push_warning("Vertex Studio: couldn't load PNG palette: " + path)
		return
	if img.is_compressed():
		img.decompress()
	var seen: Dictionary = {}
	var cols: Array[Color] = []
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var key := c.to_argb32()
			if not seen.has(key):
				seen[key] = true
				cols.append(c)
		if cols.size() >= 256:
			break
	if cols.is_empty():
		return
	_set_swatches(cols)


func _save_palette(path: String) -> void:
	var pal := VSColorPalette.create(PackedColorArray(_state.swatches))
	ResourceSaver.save(pal, path)


func _load_palette(path: String) -> void:
	var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var packed := VSColorPalette.colors_from(res)
	if packed.is_empty():
		return
	var cols: Array[Color] = []
	for c in packed:
		cols.append(c)
	_set_swatches(cols)


func _set_swatches(cols: Array[Color]) -> void:
	_state.swatches = cols
	if _panel:
		_panel.refresh_swatches()
	_state.emit_changed()
	_queue_save()


#endregion Swatch palette


#region Snapshots
# ----------------------------------------------------------------
# Snapshots
# ----------------------------------------------------------------

func _snapshot_new() -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _snapshot_save() -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _write_snapshot(_path: String) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _snapshot_save_job(_snap: VSSnapshot, _path: String) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _on_snapshot_saved(_path: String, _err: int) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _toast(msg: String, severity: int = 0) -> void:
	var ei := Engine.get_singleton(&"EditorInterface")
	if ei != null and ei.has_method(&"get_editor_toaster"):
		var toaster = ei.call(&"get_editor_toaster")
		if toaster != null:
			toaster.push_toast(msg, severity)
			return
	if severity > 0:
		push_warning(msg)
	else:
		print(msg)


func _snapshot_load() -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _snapshot_reload() -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _snapshot_delete() -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _snapshot_delete_confirmed() -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _apply_snapshot(_path: String) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _poll_snapshot_load() -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _finish_apply_snapshot(_snap: VSSnapshot, _path: String) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


#endregion Snapshots


#region Vertex groups
# ----------------------------------------------------------------
# Vertex Groups
# ----------------------------------------------------------------

func _vgroups() -> Dictionary:
	if _current_node == null or not is_instance_valid(_current_node):
		return {}
	var v = VSStore.get_field(_current_node, VSStore.VGROUPS, {})
	return v if v is Dictionary else {}


func _write_vgroups(_groups: Dictionary) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _refresh_vgroup_list() -> void:
	if _panel == null:
		return
	var names := PackedStringArray(_vgroups().keys())
	names.sort()
	_panel.set_vertex_groups(names, _vgroup_active)


func _on_vgroup_action(_action: StringName, _group_name: String) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _vgroup_create(_raw_name: String) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _vgroup_save(_name: String) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _vgroup_reload(_name: String) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _vgroup_delete_confirmed() -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


#endregion Vertex groups


#region Select linked
# ----------------------------------------------------------------
# Select linked
# ----------------------------------------------------------------

func _refresh_material_list() -> void:
	if _panel == null:
		return
	_material_entries = _painter.linked_materials()
	var labels := PackedStringArray()
	for e in _material_entries:
		labels.append(str(e["label"]))
	_panel.set_materials(labels)


func _on_select_linked_material(_index: int) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


#endregion linked


#region Shortcuts
# ----------------------------------------------------------------
# Shortcuts
# ----------------------------------------------------------------

func _build_key_actions() -> void:
	_key_actions = [
		[VSSettings.SC_TOGGLE_PAINT, func(): _panel.toggle_brush_tool(VSState.Op.REPLACE), -1],
		[VSSettings.SC_PAINT_ADD, func(): _panel.toggle_brush_tool(VSState.Op.ADD), -1],
		[VSSettings.SC_TOGGLE_ERASE, func(): _panel.toggle_brush_tool(VSState.Op.ERASE), -1],
		[VSSettings.SC_PAINT_PRECISION, func(): _panel.toggle_brush_tool(VSState.Op.PRECISION),
			VSPro.Feature.PAINT_PRECISION],
		[VSSettings.SC_PAINT_NORMALS, func(): _panel.toggle_brush_tool(VSState.Op.NORMALS),
			VSPro.Feature.PAINT_NORMALS],
		[VSSettings.SC_PAINT_BLUR, func(): _panel.toggle_brush_tool(VSState.Op.BLUR), -1],
		[VSSettings.SC_TOGGLE_LASSO, func(): _panel.toggle_select_tool(VSState.SelectType.LASSO),
			VSPro.Feature.SELECT_LASSO],
		[VSSettings.SC_SELECT_POINT, func(): _panel.toggle_select_tool(VSState.SelectType.POINT), -1],
		[VSSettings.SC_SELECT_RECT, func(): _panel.toggle_select_tool(VSState.SelectType.RECTANGLE),
			VSPro.Feature.SELECT_RECTANGLE],
		[VSSettings.SC_SELECT_ELLIPSE, func(): _panel.toggle_select_tool(VSState.SelectType.ELLIPSE),
			VSPro.Feature.SELECT_ELLIPSE],
		[VSSettings.SC_SELECT_LINKED, func(): _panel.toggle_select_tool(VSState.SelectType.LINKED),
			VSPro.Feature.SELECT_LINKED],
		[VSSettings.SC_INVERT_SELECTION, func(): _on_action(&"invert_selection"),
			VSPro.Feature.INVERT_SELECTION],
		[VSSettings.SC_DESELECT, func(): _on_action(&"deselect"), -1],
		[VSSettings.SC_FILL, func(): _on_action(&"fill_all"), -1],
		[VSSettings.SC_ERASE_ALL, func(): _on_action(&"erase_all"), -1],
		[VSSettings.SC_RESTORE_MATERIAL, func(): _on_action(&"commit_material"), -1],
		[VSSettings.SC_RESYNC_UVS, func(): _on_action(&"resync_uvs"), VSPro.Feature.RESYNC_UVS],
		[VSSettings.SC_SHARED_VERTS, _toggle_shared_verts, VSPro.Feature.SPLIT_VERTS],
		[VSSettings.SC_FRONT_VERTS, _toggle_front_verts_only, -1],
		[VSSettings.SC_CYCLE_SWATCH, _cycle_swatch_or_normals_mode, -1],
	]


func _shortcut_input(event: InputEvent) -> void:
	if _ui_busy():
		get_viewport().set_input_as_handled()
		return
	if _panel == null or not _panel.visible or not _painter.has_targets():
		return
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if _state.tool_mode == VSState.ToolMode.SELECT and _overlay.mouse_inside:
		var m := _live_sel_modifier()
		if m != _overlay.sel_modifier:
			_overlay.sel_modifier = m
			update_overlays()
	if not ke.pressed or ke.echo:
		return
	for entry in _key_actions:
		if not VSSettings.matches(entry[0], ke):
			continue
		var feature := int(entry[2])
		if feature != -1 and VSPro.locked(feature):
			_panel.show_pro_alert(feature)
		else:
			(entry[1] as Callable).call()
			update_overlays()
		get_viewport().set_input_as_handled()
		return
	if VSSettings.matches(VSSettings.SC_BRUSH_SETTINGS, ke):
		if _mouse_over_viewport():
			_panel.open_brush_popup(DisplayServer.mouse_get_position())
			get_viewport().set_input_as_handled()
	elif VSSettings.matches(VSSettings.SC_BRUSH_INCREASE, ke):
		if _state.operation != VSState.Op.PRECISION:
			_set_brush_resize(1, ke.pressed, ke.echo)
			get_viewport().set_input_as_handled()
	elif VSSettings.matches(VSSettings.SC_BRUSH_DECREASE, ke):
		if _state.operation != VSState.Op.PRECISION:
			_set_brush_resize(-1, ke.pressed, ke.echo)
			get_viewport().set_input_as_handled()
	elif VSSettings.matches(VSSettings.SC_OPACITY_INCREASE, ke):
		if _state.operation != VSState.Op.NORMALS:
			_start_opacity_ramp(1)
			get_viewport().set_input_as_handled()
	elif VSSettings.matches(VSSettings.SC_OPACITY_DECREASE, ke):
		if _state.operation != VSState.Op.NORMALS:
			_start_opacity_ramp(-1)
			get_viewport().set_input_as_handled()


func _set_brush_resize(dir: int, pressed: bool, echo: bool) -> void:
	if pressed:
		if not echo:
			_panel.adjust_brush_size(dir * maxf(2.0, _state.radius * 0.1))
			update_overlays()
		_brush_dir = dir
	elif _brush_dir == dir:
		_brush_dir = 0


func _start_opacity_ramp(dir: int) -> void:
	_panel.adjust_opacity(dir * OPACITY_STEP)
	_opacity_dir = dir


func _process(delta: float) -> void:
	if _brush_dir == 0 and _opacity_dir == 0:
		return
	if _panel == null or not _panel.visible or not _painter.has_targets():
		_brush_dir = 0
		_opacity_dir = 0
		return
	_ramp_brush_size(delta)
	_ramp_opacity(delta)


func _ramp_brush_size(delta: float) -> void:
	if _brush_dir == 0:
		return
	if _state.operation == VSState.Op.PRECISION \
			or not Input.is_key_pressed(_inc_key if _brush_dir > 0 else _dec_key):
		_brush_dir = 0
		return
	var rate := maxf(40.0, _state.radius * 1.5)
	_panel.adjust_brush_size(_brush_dir * rate * delta)
	update_overlays()


func _ramp_opacity(delta: float) -> void:
	if _opacity_dir == 0:
		return
	if _state.operation == VSState.Op.NORMALS \
			or not Input.is_key_pressed(_op_inc_key if _opacity_dir > 0 else _op_dec_key):
		_opacity_dir = 0
		return
	_panel.adjust_opacity(_opacity_dir * OPACITY_RATE * delta)


func _cycle_swatch() -> void:
	var sw: Array = _state.swatches
	if sw.is_empty():
		return
	for i in sw.size():
		if sw[i].is_equal_approx(_state.color):
			_swatch_index = i
			break
	_swatch_index = (_swatch_index + 1) % sw.size()
	_panel.set_color(sw[_swatch_index])
	_state.color_changed.emit()
	_state.emit_changed()
	update_overlays()


func _cycle_swatch_or_normals_mode() -> void:
	if _state.tool_enabled and _state.operation == VSState.Op.NORMALS:
		_toggle_normals_mode()
	else:
		_cycle_swatch()


func _toggle_shared_verts() -> void:
	_state.shared_verts = VSState.SharedVerts.MERGE \
		if _state.shared_verts == VSState.SharedVerts.SPLIT \
		else VSState.SharedVerts.SPLIT
	_view_toggled()


func _toggle_front_verts_only() -> void:
	_state.front_verts_only = not _state.front_verts_only
	_view_toggled()


func _view_toggled() -> void:
	_state.view_changed.emit()
	_state.emit_changed()
	if _panel:
		_panel.refresh()


func _toggle_normals_mode() -> void:
	_state.normals_mode = VSState.NormalsMode.HARD \
		if _state.normals_mode == VSState.NormalsMode.SMOOTH \
		else VSState.NormalsMode.SMOOTH
	_state.emit_changed()
	update_overlays()


func _mouse_over_viewport() -> bool:
	if _last_camera == null:
		return false
	var vp := _last_camera.get_viewport()
	if vp == null:
		return false
	var c := vp.get_parent()
	if c is Control:
		return c.get_global_rect().has_point(c.get_global_mouse_position())
	return false


func _register_shortcuts() -> void:
	VSSettings.register_all()
	_refresh_cached_settings()
	_build_key_actions()
	_purge_legacy_editor_shortcuts()
	if not ProjectSettings.settings_changed.is_connected(_on_project_settings_changed):
		ProjectSettings.settings_changed.connect(_on_project_settings_changed)

	_settings_save_timer = Timer.new()
	_settings_save_timer.one_shot = true
	_settings_save_timer.wait_time = 0.5
	_settings_save_timer.timeout.connect(_save_project_settings)
	add_child(_settings_save_timer)
	VSSettings.watch_shortcuts(_on_shortcut_edited)


func _on_project_settings_changed() -> void:
	_refresh_cached_settings()
	VSSettings.watch_shortcuts(_on_shortcut_edited)


func _on_shortcut_edited() -> void:
	VSSettings.watch_shortcuts(_on_shortcut_edited)
	_refresh_cached_settings()
	if _settings_save_timer:
		_settings_save_timer.start()


func _save_project_settings() -> void:
	ProjectSettings.save()


func _flush_project_settings_save() -> void:
	if _settings_save_timer and not _settings_save_timer.is_stopped():
		_settings_save_timer.stop()
		_save_project_settings()


func _refresh_cached_settings() -> void:
	_inc_key = VSSettings.keycode(VSSettings.SC_BRUSH_INCREASE)
	_dec_key = VSSettings.keycode(VSSettings.SC_BRUSH_DECREASE)
	_op_inc_key = VSSettings.keycode(VSSettings.SC_OPACITY_INCREASE)
	_op_dec_key = VSSettings.keycode(VSSettings.SC_OPACITY_DECREASE)
	_realtime_tri_limit = VSSettings.realtime_triangle_limit()
	if _panel != null:
		_panel.set_show_statistics(VSSettings.show_mesh_statistics())


func _purge_legacy_editor_shortcuts() -> void:
	var es := EditorInterface.get_editor_settings()
	if es == null:
		return
	var legacy: PackedStringArray = ["increase_brush_size", "decrease_brush_size",
		"open_brush_settings", "toggle_paint", "toggle_paint_erase", "toggle_lasso",
		"deselect", "fill", "cycle_swatch"]
	for key in legacy:
		var path := "vertex_studio/" + key
		if es.has_setting(path):
			es.erase(path)


#endregion Shortcuts


#region Dialogs
# ----------------------------------------------------------------
# Dialogs
# ----------------------------------------------------------------

func _build_dialogs() -> void:
	var base := EditorInterface.get_base_control()

	_save_dialog = EditorFileDialog.new()
	_save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_save_dialog.add_filter("*.res", "Vertex Studio Snapshot (binary)")
	_save_dialog.add_filter("*.tres", "Vertex Studio Snapshot (text)")
	_save_dialog.current_file = "vertex_snapshot.res"
	_save_dialog.file_selected.connect(_write_snapshot)
	base.add_child(_save_dialog)

	_load_dialog = EditorFileDialog.new()
	_load_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_load_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_load_dialog.add_filter("*.res", "Vertex Studio Snapshot (binary)")
	_load_dialog.add_filter("*.tres", "Vertex Studio Snapshot (text)")
	_load_dialog.file_selected.connect(_apply_snapshot)
	base.add_child(_load_dialog)

	_swatch_png_dialog = EditorFileDialog.new()
	_swatch_png_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_swatch_png_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_swatch_png_dialog.add_filter("*.png", "PNG Image")
	_swatch_png_dialog.title = "Import PNG Palette"
	_swatch_png_dialog.file_selected.connect(_import_png_palette)
	base.add_child(_swatch_png_dialog)

	_swatch_save_dialog = EditorFileDialog.new()
	_swatch_save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_swatch_save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_swatch_save_dialog.add_filter("*.tres", "Color Palette")
	_swatch_save_dialog.current_file = "palette.tres"
	_swatch_save_dialog.title = "Save Palette"
	_swatch_save_dialog.file_selected.connect(_save_palette)
	base.add_child(_swatch_save_dialog)

	_swatch_load_dialog = EditorFileDialog.new()
	_swatch_load_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_swatch_load_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_swatch_load_dialog.add_filter("*.tres", "Color Palette")
	_swatch_load_dialog.add_filter("*.res", "Color Palette")
	_swatch_load_dialog.title = "Load Palette"
	_swatch_load_dialog.file_selected.connect(_load_palette)
	base.add_child(_swatch_load_dialog)

	_resync_model_dialog = EditorFileDialog.new()
	_resync_model_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_resync_model_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_resync_model_dialog.title = "Pick the source model to re-sync UVs from"
	for ext in ["*.glb", "*.gltf", "*.blend", "*.fbx", "*.obj", "*.dae"]:
		_resync_model_dialog.add_filter(ext)
	_resync_model_dialog.file_selected.connect(_on_resync_model_picked)
	base.add_child(_resync_model_dialog)

	_info_dialog = AcceptDialog.new()
	base.add_child(_info_dialog)

	_resync_confirm_dialog = ConfirmationDialog.new()
	_resync_confirm_dialog.title = "Re-sync UVs"
	_resync_confirm_dialog.ok_button_text = "Best-guess re-sync"
	var resync_vb := VBoxContainer.new()
	resync_vb.add_theme_constant_override("separation", 10)
	_resync_confirm_label = Label.new()
	_resync_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resync_confirm_label.custom_minimum_size = Vector2(440, 0)
	resync_vb.add_child(_resync_confirm_label)
	_resync_dont_ask_cb = CheckBox.new()
	_resync_dont_ask_cb.text = "Don't ask again for this mesh"
	_resync_dont_ask_cb.toggled.connect(func(on: bool):
		var key := _resync_pref_key()
		if key == "":
			return
		if on:
			_resync_skip_prompt[key] = true
		else:
			_resync_skip_prompt.erase(key)
		_save_prefs())
	resync_vb.add_child(_resync_dont_ask_cb)
	_resync_confirm_dialog.add_child(resync_vb)
	_resync_confirm_dialog.confirmed.connect(func(): _do_resync(_pending_resync_sources, true))
	base.add_child(_resync_confirm_dialog)

	_vgroup_name_dialog = AcceptDialog.new()
	_vgroup_name_dialog.title = "New Vertex Group"
	_vgroup_name_dialog.ok_button_text = "Create"
	_vgroup_name_edit = LineEdit.new()
	_vgroup_name_edit.placeholder_text = "Group name"
	_vgroup_name_edit.custom_minimum_size = Vector2(240, 0)
	_vgroup_name_dialog.add_child(_vgroup_name_edit)
	_vgroup_name_dialog.register_text_enter(_vgroup_name_edit)
	_vgroup_name_dialog.confirmed.connect(func(): _vgroup_create(_vgroup_name_edit.text))
	base.add_child(_vgroup_name_dialog)

	_vgroup_delete_dialog = ConfirmationDialog.new()
	_vgroup_delete_dialog.title = "Delete Vertex Group"
	_vgroup_delete_dialog.ok_button_text = "Delete"
	_vgroup_delete_dialog.confirmed.connect(_vgroup_delete_confirmed)
	base.add_child(_vgroup_delete_dialog)

	_snapshot_delete_dialog = ConfirmationDialog.new()
	_snapshot_delete_dialog.title = "Delete Snapshot"
	_snapshot_delete_dialog.ok_button_text = "Delete"
	_snapshot_delete_dialog.confirmed.connect(_snapshot_delete_confirmed)
	base.add_child(_snapshot_delete_dialog)


#endregion Dialogs


#region Source re-sync
# ----------------------------------------------------------------
# Source mesh re-sync (pull possibly updated UVs from the source model)
# ----------------------------------------------------------------

func _resync_uvs() -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _on_resync_model_picked(_path: String) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _do_resync(_sources: Array, _by_position := false) -> void:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	pass


func _resync_pref_key() -> String:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	return ""


func _resync_best_guess_pref() -> bool:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	return false


func _resync_summary(_r: Dictionary) -> String:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	return ""


func _source_mesh_for(_mi: MeshInstance3D, _root: Node) -> Mesh:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	return null


func _resolve_source(_mi: MeshInstance3D, _root: Node) -> Dictionary:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	return {}


func _mesh_from_model(_model_path: String, _rel: NodePath, _node_name: String) -> Mesh:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	return null


func _find_mesh_by_name(_node: Node, _nm: String) -> MeshInstance3D:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	return null


func _find_first_mesh(_node: Node) -> MeshInstance3D:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	return null


func _is_model_file(_path: String) -> bool:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	return false


func _is_packed_scene(_path: String) -> bool:
	# Code stripped away in the free version.
	# Get Vertex Studio Pro to get access to all features and the full source-code.
	return false


func _show_info(title: String, text: String) -> void:
	if _info_dialog == null:
		return
	_info_dialog.title = title
	_info_dialog.dialog_text = text
	_info_dialog.popup_centered()

#endregion Source re-sync