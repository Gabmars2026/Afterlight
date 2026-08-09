extends CharacterBody3D
## Phase 21: AI traffic. Cars cruise fixed loops along the town's two
## main streets, brake for anything on the road ahead (you included),
## and floor it in a panic if you shoot them.

const CarVisual := preload("res://scripts/vehicles/car_visual.gd")

const KINDS := [
	"res://addons/M.A.V.S/Vehicle/NightSky/NightSky_Body.tscn",
	"res://addons/M.A.V.S/Vehicle/Cleo V8/CleoV8.tscn",
	"res://addons/M.A.V.S/Vehicle/GT30/GT30.tscn",
	"res://addons/M.A.V.S/Vehicle/TGR/TRG.tscn",
]

const CRUISE := 7.0
const PANIC := 12.0

var waypoints: Array = []
var wp := 0
var paint := Color(0.6, 0.6, 0.65)
var kind := 0

var _speed := 0.0
var _panic_left := 0.0
var _blocked_time := 0.0
var _ray: RayCast3D


func _ready() -> void:
	add_to_group("traffic")
	collision_layer = 1
	collision_mask = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 1.4, 4.1)
	col.shape = shape
	col.position.y = 0.72
	add_child(col)
	_build_mesh()
	_ray = RayCast3D.new()
	_ray.position = Vector3(0, 0.9, -2.4)
	_ray.target_position = Vector3(0, 0, -5.0)
	_ray.collision_mask = 1 | 2 | 4
	_ray.enabled = true
	add_child(_ray)


func _build_mesh() -> void:
	# A street car from the M.A.V.S pack (meshes only, physics is ours)
	var visual := CarVisual.build(KINDS[kind % KINDS.size()])
	visual.name = "Visual"
	visual.position.y = 0.02  # collision box bottom
	add_child(visual)


func take_hit(_damage: int, _point: Vector3) -> void:
	_panic_left = 10.0


func _physics_process(delta: float) -> void:
	if waypoints.is_empty():
		return
	_panic_left = maxf(_panic_left - delta, 0.0)
	var target: Vector3 = waypoints[wp]
	var to_t := target - global_position
	to_t.y = 0.0
	if to_t.length() < 3.0:
		wp = (wp + 1) % waypoints.size()
		target = waypoints[wp]
		to_t = target - global_position
		to_t.y = 0.0
	var dir := to_t.normalized()
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 2.6 * delta)

	# Brake for whatever is on the road ahead (unless panicking)
	var want := CRUISE if _panic_left <= 0.0 else PANIC
	if _panic_left <= 0.0 and _ray.is_colliding():
		_blocked_time += delta
		# After a long standoff, creep forward so junctions unjam
		want = 1.2 if _blocked_time > 4.0 else 0.0
	else:
		_blocked_time = 0.0
	_speed = move_toward(_speed, want, 8.0 * delta)
	var fwd := -global_transform.basis.z
	velocity = Vector3(fwd.x * _speed, -2.0, fwd.z * _speed)
	move_and_slide()
