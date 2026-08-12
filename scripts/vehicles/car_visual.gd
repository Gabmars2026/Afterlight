extends Object
## Phase 24: extracts the visual meshes (body + positioned wheels) from
## a M.A.V.S vehicle scene, leaving its physics and controller behind.

static func build(scene_path: String) -> Node3D:
	var root := Node3D.new()
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_warning("car_visual: cannot load " + scene_path)
		return root
	var src: Node = packed.instantiate()
	# M.A.V.S models face +Z; the game drives toward -Z, so turn them
	_collect(src, Transform3D(Basis.from_euler(Vector3(0.0, PI, 0.0)), Vector3.ZERO), root)
	src.free()
	# Rest the tyres exactly on the ground (y = 0)
	var min_y := 999.0
	for c in root.get_children():
		if c is MeshInstance3D and c.mesh:
			var a: AABB = c.transform * c.mesh.get_aabb()
			min_y = minf(min_y, a.position.y)
	if min_y < 900.0:
		for c in root.get_children():
			c.position.y -= min_y
	return root


static func _collect(node: Node, xf: Transform3D, root: Node3D,
		wheel_name: String = "") -> void:
	var local := xf
	if node is Node3D:
		local = xf * (node as Node3D).transform
	if node is VehicleWheel3D:
		wheel_name = str(node.name)
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var src: MeshInstance3D = node
		var mi := MeshInstance3D.new()
		mi.mesh = src.mesh
		for s in src.get_surface_override_material_count():
			mi.set_surface_override_material(s,
					src.get_surface_override_material(s))
		if src.material_override:
			mi.material_override = src.material_override
		mi.transform = local
		if not wheel_name.is_empty():
			mi.set_meta("car_wheel", wheel_name)
		root.add_child(mi)
	for child in node.get_children():
		_collect(child, local, root, wheel_name)
