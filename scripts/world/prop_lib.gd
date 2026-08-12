## (loaded via preload as PropLib)
extends Object
## Phase 16 helper: places props from the Medieval Village pack
## (Done_*.glb at the project root). Handles instancing, scaling,
## and auto-generated box collision from the mesh bounds.

static var _scenes := {}
static var _bounds := {}


## Place a prop. `prop` is the name without the Done_ prefix, e.g. "Barril".
## Props with `collide` get a StaticBody3D with a box shape fitted to the
## visual bounds, so bullets and the player interact with them.
static func place(parent: Node, prop: String, pos: Vector3, yrot := 0.0,
		scl := 1.0, collide := true, xrot := 0.0) -> Node3D:
	var path := "res://Done_%s.glb" % prop
	if not _scenes.has(path):
		_scenes[path] = load(path)
	var packed: PackedScene = _scenes[path]
	if packed == null:
		push_warning("PropLib: missing prop %s" % path)
		return null
	var inst: Node3D = packed.instantiate()
	inst.scale = Vector3.ONE * scl
	var root: Node3D
	if collide:
		var body := StaticBody3D.new()
		body.add_child(inst)
		var aabb := _bounds_for(path, inst)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = aabb.size * scl
		shape.shape = box
		shape.position = (aabb.position + aabb.size * 0.5) * scl
		body.add_child(shape)
		body.set_meta("surface", "wood")
		root = body
	else:
		root = inst
	root.position = pos
	root.rotation = Vector3(xrot, yrot, 0.0)
	root.add_to_group("prop")
	parent.add_child(root)
	return root


static func _bounds_for(path: String, inst: Node3D) -> AABB:
	if _bounds.has(path):
		return _bounds[path]
	var aabb := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true):
		var b: AABB = mi.transform * mi.mesh.get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
	_bounds[path] = aabb
	return aabb
