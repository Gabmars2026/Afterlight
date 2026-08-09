extends Object
## v1.17.0 helper: dresses a rigged mannequin in simple clothes.
## Boxy vest + shorts ride the spine/hip bones; hats ride the head.
## Static, no per-frame cost - the bones animate the meshes for free.

const HAT_NONE := 0
const HAT_CAP := 1
const HAT_BRIM := 2
const HAT_BEANIE := 3


static func dress(skel: Skeleton3D, torso: Color, pants: Color,
		hat_kind := HAT_NONE, hat_color := Color(0.2, 0.2, 0.22)) -> void:
	if skel == null:
		return
	var vest := _attach(skel, "DEF-spine.003", "OutfitVest")
	if vest:
		_box(vest, Vector3(0.42, 0.36, 0.3), Vector3(0, 0.1, 0), torso)
	var hips := _attach(skel, "DEF-hips", "OutfitShorts")
	if hips:
		_box(hips, Vector3(0.4, 0.3, 0.27), Vector3(0, 0.02, 0), pants)
	if hat_kind == HAT_NONE:
		return
	var head := _attach(skel, "DEF-head", "OutfitHat")
	if head == null:
		return
	match hat_kind:
		HAT_CAP:
			_cyl(head, 0.13, 0.145, 0.09, Vector3(0, 0.13, 0), hat_color)
			_box(head, Vector3(0.17, 0.02, 0.13), Vector3(0, 0.09, 0.17),
					hat_color)
		HAT_BRIM:
			_cyl(head, 0.21, 0.21, 0.025, Vector3(0, 0.1, 0), hat_color)
			_cyl(head, 0.11, 0.125, 0.11, Vector3(0, 0.16, 0), hat_color)
		HAT_BEANIE:
			var mi := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = 0.15
			sp.height = 0.2
			sp.material = _mat(hat_color)
			mi.mesh = sp
			mi.position = Vector3(0, 0.11, 0)
			head.add_child(mi)


static func _attach(skel: Skeleton3D, bone: String,
		nm: String) -> BoneAttachment3D:
	if skel.find_bone(bone) < 0:
		return null
	var att := BoneAttachment3D.new()
	att.name = nm
	skel.add_child(att)
	att.bone_name = bone
	return att


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.92
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3,
		c: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _mat(c)
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)


static func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float,
		pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.material = _mat(c)
	mi.mesh = cm
	mi.position = pos
	parent.add_child(mi)
