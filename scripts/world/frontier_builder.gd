extends Node3D
## Phase 23: the frontier. A sand beach and open ocean along the west
## edge of the map, and a range of climbable mountains to the south.

const MOUNTAINS := [
	# [x, z, height, base radius, snow]
	[-40.0, 285.0, 70.0, 95.0, false],
	[60.0, 335.0, 100.0, 130.0, true],
	[-115.0, 350.0, 62.0, 85.0, false],
	[15.0, 405.0, 120.0, 155.0, true],
]

var _water: MeshInstance3D
var _water_mat: StandardMaterial3D
var _t := 0.0


func _ready() -> void:
	_build_beach()
	_build_ocean()
	_build_mountains()


func _slab(size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	bm.material = m
	mi.mesh = bm
	mi.position = pos
	add_child(mi)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	sb.add_child(cs)
	mi.add_child(sb)


func _build_beach() -> void:
	# Sand apron up from the dunes, then the main shelf over the ridge
	_slab(Vector3(28, 6, 620), Vector3(-228, -0.4, 0), Color(0.84, 0.75, 0.55))
	_slab(Vector3(36, 10, 620), Vector3(-258, 0.2, 0), Color(0.87, 0.78, 0.58))
	# Gentle step down to the waterline
	_slab(Vector3(10, 9, 620), Vector3(-280, -0.1, 0), Color(0.82, 0.72, 0.52))


func _build_ocean() -> void:
	# Seabed you can actually walk on
	_slab(Vector3(320, 4, 620), Vector3(-444, -1.4, 0), Color(0.35, 0.42, 0.4))
	# The water surface (visual only, no collision)
	_water = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(320, 620)
	pm.subdivide_width = 24
	pm.subdivide_depth = 24
	_water_mat = StandardMaterial3D.new()
	_water_mat.albedo_color = Color(0.1, 0.38, 0.55, 0.72)
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_mat.metallic = 0.6
	_water_mat.roughness = 0.15
	_water_mat.uv1_scale = Vector3(40, 40, 1)
	pm.material = _water_mat
	_water.mesh = pm
	_water.position = Vector3(-444, 3.8, 0)
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water)


func _build_mountains() -> void:
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.48, 0.42, 0.38)
	rock.roughness = 1.0
	var snow := StandardMaterial3D.new()
	snow.albedo_color = Color(0.92, 0.94, 0.97)
	snow.roughness = 0.8
	for spec in MOUNTAINS:
		var h: float = spec[2]
		var r: float = spec[3]
		var m := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 5.0
		cone.bottom_radius = r
		cone.height = h
		cone.radial_segments = 9
		cone.rings = 1
		cone.material = rock
		m.mesh = cone
		m.position = Vector3(spec[0], h * 0.5 - 3.0, spec[1])
		add_child(m)
		# Climbable rock: real trimesh collision on the cone
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = cone.create_trimesh_shape()
		sb.add_child(cs)
		m.add_child(sb)
		if spec[4]:
			var cap := MeshInstance3D.new()
			var sc := CylinderMesh.new()
			sc.top_radius = 4.5
			sc.bottom_radius = r * 0.24
			sc.height = h * 0.26
			sc.radial_segments = 9
			sc.material = snow
			cap.mesh = sc
			cap.position = Vector3(spec[0], h - 3.0 - h * 0.12, spec[1])
			cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(cap)


func _process(delta: float) -> void:
	# Slow current drift + a gentle bob so the sea reads as alive
	_t += delta
	if _water:
		_water_mat.uv1_offset.x = fmod(_t * 0.015, 1.0)
		_water_mat.uv1_offset.y = fmod(_t * 0.009, 1.0)
		_water.position.y = 3.8 + sin(_t * 0.6) * 0.12
