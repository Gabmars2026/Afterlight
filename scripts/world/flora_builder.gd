extends Node3D
## v1.18.0: DESERT BLOOM. Low-poly life for the dry outskirts - palm
## trees, tamarisk bushes, scattered rocks, two oases with water, and
## a MultiMesh carpet of grass tufts. Everything sits on the Terrain3D
## surface via get_height() and stays out of districts and roads.

const PropLib := preload("res://scripts/world/prop_lib.gd")

var terrain_data: Object = null  # Terrain3DData, injected by the zone

var _trunk_mat: StandardMaterial3D
var _frond_mat: StandardMaterial3D
var _frond_mat2: StandardMaterial3D
var _bush_mat: StandardMaterial3D
var _bush_mat2: StandardMaterial3D
var _water_mat: StandardMaterial3D
var palms := 0
var bushes := 0


func _ready() -> void:
	_trunk_mat = _mat(Color(0.42, 0.3, 0.2))
	_frond_mat = _mat(Color(0.24, 0.45, 0.22))
	_frond_mat2 = _mat(Color(0.35, 0.52, 0.25))
	_bush_mat = _mat(Color(0.3, 0.42, 0.24))
	_bush_mat2 = _mat(Color(0.5, 0.52, 0.3))
	_water_mat = StandardMaterial3D.new()
	_water_mat.albedo_color = Color(0.15, 0.4, 0.5, 0.9)
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_mat.roughness = 0.05
	_water_mat.metallic = 0.3
	if terrain_data == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 18
	_build_oases()
	_scatter(rng)
	_build_grass(rng)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m


func _h(x: float, z: float) -> float:
	var v: float = terrain_data.get_height(Vector3(x, 0, z))
	return 0.0 if is_nan(v) else v


func _blocked(x: float, z: float) -> bool:
	# Town + walls
	if absf(x) < 84.0 and absf(z) < 84.0:
		return true
	# NEON DISTRICT plinth + approach road
	if x > 90.0 and x < 248.0 and z > -68.0 and z < 88.0:
		return true
	# SUNSET FLATS mesa + ramp
	if x > 96.0 and x < 244.0 and z > -174.0 and z < -86.0:
		return true
	# Castle grounds
	if absf(x) < 48.0 and z > -218.0 and z < -122.0:
		return true
	# Road corridors leaving the gates
	if absf(x) < 9.0 or absf(z) < 9.0:
		return true
	# Ocean west, mountains south
	if x < -255.0 or z > 255.0:
		return true
	return false


func _build_oases() -> void:
	## Two palm-ringed waterholes in the open dunes
	var spots: Array[Vector2] = [Vector2(-150, -150), Vector2(115, 165)]
	for spot in spots:
		var cx := spot.x
		var cz := spot.y
		var hmid := _h(cx, cz)
		var flat := true
		for a in 4:
			if absf(_h(cx + cos(a * TAU / 4.0) * 9.0,
					cz + sin(a * TAU / 4.0) * 9.0) - hmid) > 1.6:
				flat = false
		if not flat:
			continue
		var pool := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 10.0
		cm.bottom_radius = 10.0
		cm.height = 0.3
		cm.radial_segments = 18
		cm.material = _water_mat
		pool.mesh = cm
		pool.position = Vector3(cx, hmid + 0.25, cz)
		add_child(pool)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(cx)
		for i in 5:
			var ang := TAU * i / 5.0 + rng.randf_range(-0.3, 0.3)
			var d := rng.randf_range(11.0, 14.5)
			var px := cx + cos(ang) * d
			var pz := cz + sin(ang) * d
			plant_palm(Vector3(px, _h(px, pz), pz), rng)
		for i in 6:
			var ang := TAU * i / 6.0 + rng.randf_range(-0.4, 0.4)
			var d := rng.randf_range(12.0, 17.0)
			var bx := cx + cos(ang) * d
			var bz := cz + sin(ang) * d
			plant_bush(Vector3(bx, _h(bx, bz), bz), rng)


func _scatter(rng: RandomNumberGenerator) -> void:
	## Palms, bushes and rocks over the reachable dunes
	var tries := 0
	while palms < 46 and tries < 700:
		tries += 1
		var x := rng.randf_range(-250.0, 250.0)
		var z := rng.randf_range(-250.0, 250.0)
		if _blocked(x, z):
			continue
		plant_palm(Vector3(x, _h(x, z), z), rng)
	tries = 0
	while bushes < 90 and tries < 900:
		tries += 1
		var x := rng.randf_range(-250.0, 250.0)
		var z := rng.randf_range(-250.0, 250.0)
		if _blocked(x, z):
			continue
		plant_bush(Vector3(x, _h(x, z), z), rng)
	var rocks := 0
	tries = 0
	while rocks < 30 and tries < 400:
		tries += 1
		var x := rng.randf_range(-240.0, 240.0)
		var z := rng.randf_range(-240.0, 240.0)
		if _blocked(x, z):
			continue
		var nm := "Rock_%d" % (1 + rng.randi() % 10)
		PropLib.place(self, nm, Vector3(x, _h(x, z), z),
				rng.randf() * TAU, rng.randf_range(1.2, 2.6))
		rocks += 1


func plant_palm(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var p := Node3D.new()
	p.name = "Palm%d" % palms
	p.position = pos
	p.rotation.y = rng.randf() * TAU
	add_child(p)
	var lean := rng.randf_range(-0.12, 0.12)
	var h := rng.randf_range(5.5, 8.0)
	# One tapered trunk, leaning from the base
	var pivot := Node3D.new()
	pivot.rotation.z = lean
	p.add_child(pivot)
	var seg := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.13
	cm.bottom_radius = 0.26
	cm.height = h
	cm.radial_segments = 6
	cm.material = _trunk_mat
	seg.mesh = cm
	seg.position = Vector3(0, h * 0.5, 0)
	pivot.add_child(seg)
	var top := Vector3(-h * sin(lean), h * cos(lean), 0)
	# Frond crown: drooping flat prisms fanned around the top
	var fronds := 6 + (rng.randi() % 3)
	for i in fronds:
		var f := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.34, 0.06, rng.randf_range(2.6, 3.4))
		bm.material = _frond_mat if i % 2 == 0 else _frond_mat2
		f.mesh = bm
		f.position = top
		f.rotation.y = TAU * i / fronds + rng.randf_range(-0.15, 0.15)
		f.rotation.x = rng.randf_range(0.28, 0.5)
		var piv := Node3D.new()
		piv.position = top
		piv.rotation.y = TAU * i / fronds + rng.randf_range(-0.15, 0.15)
		p.add_child(piv)
		f.position = Vector3(0, 0, -1.5)
		f.rotation.y = 0.0
		f.rotation.x = rng.randf_range(0.24, 0.42)
		piv.add_child(f)
	# Trunk collision so you can't ghost through a tree
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.26
	shape.height = h
	cs.shape = shape
	cs.position = Vector3(0, h * 0.5, 0)
	sb.add_child(cs)
	p.add_child(sb)
	palms += 1


func plant_bush(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var b := Node3D.new()
	b.position = pos
	add_child(b)
	var blobs := 2 + (rng.randi() % 2)
	for i in blobs:
		var mi := MeshInstance3D.new()
		var sp := SphereMesh.new()
		var r := rng.randf_range(0.7, 1.3)
		sp.radius = r
		sp.height = r * 1.2
		sp.radial_segments = 8
		sp.rings = 4
		sp.material = _bush_mat if rng.randf() < 0.7 else _bush_mat2
		mi.mesh = sp
		mi.position = Vector3(rng.randf_range(-0.8, 0.8), r * 0.45,
				rng.randf_range(-0.8, 0.8))
		b.add_child(mi)
	bushes += 1


func _build_grass(rng: RandomNumberGenerator) -> void:
	## One MultiMesh with ~1400 crossed-quad tufts = one draw call
	var quad := CylinderMesh.new()
	quad.top_radius = 0.02
	quad.bottom_radius = 0.34
	quad.height = 0.55
	quad.radial_segments = 5
	quad.rings = 1
	quad.cap_bottom = false
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.4, 0.5, 0.28)
	gm.roughness = 1.0
	quad.material = gm
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	var xforms: Array[Transform3D] = []
	var tries := 0
	while xforms.size() < 1400 and tries < 6000:
		tries += 1
		var x := rng.randf_range(-235.0, 235.0)
		var z := rng.randf_range(-235.0, 235.0)
		if _blocked(x, z):
			continue
		var y := _h(x, z) + 0.18
		var base := Transform3D(Basis(Vector3.UP, rng.randf() * TAU)
				.scaled(Vector3.ONE * rng.randf_range(0.7, 1.5)),
				Vector3(x, y, z))
		xforms.append(base)
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "GrassTufts"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
