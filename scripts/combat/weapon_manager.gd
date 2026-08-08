class_name WeaponManager
extends Node3D
## First-person weapon system: viewmodel, firing, reload, recoil, muzzle
## flash, and surface-based bullet impacts with 3D audio.
## Created in code as a child of the player's camera.

signal ammo_changed(text: String)

const MAX_RANGE := 220.0
const AIM_ZOOM := -10.0

var player: CharacterBody3D
var _weapons: Array[Dictionary] = []
var _current := -1
var _cooldown := 0.0
var _reload_left := 0.0
var _equip_left := 0.0
var _capture_grace := 0.0
var _recoil_back := 0.0
var _base_pos := Vector3(0.3, -0.27, -0.55)

var _flash: OmniLight3D
var _shot_players: Array[AudioStreamPlayer3D] = []
var _impact_players: Array[AudioStreamPlayer3D] = []
var _impact_idx := 0
var _handling: AudioStreamPlayer
var _bus := "Master"

var _snd_empty: AudioStream
var _snd_reload: AudioStream
var _snd_equip: AudioStream
var _snd_shell: AudioStream
var _impact_sounds := {}


func setup(p: CharacterBody3D) -> void:
	player = p
	position = _base_pos
	_snd_empty = load("res://assets/audio/empty_click.wav")
	_snd_reload = load("res://assets/audio/reload.wav")
	_snd_equip = load("res://assets/audio/equip.wav")
	_snd_shell = load("res://assets/audio/shell_drop.wav")
	_impact_sounds = {
		"concrete": load("res://assets/audio/impact_concrete.wav"),
		"metal": load("res://assets/audio/impact_metal.wav"),
		"wood": load("res://assets/audio/impact_wood.wav"),
		"grass": load("res://assets/audio/impact_concrete.wav"),
	}
	_handling = AudioStreamPlayer.new()
	_handling.volume_db = -6.0
	add_child(_handling)
	# Pool of positional players for gunshots (at the muzzle).
	for i in 4:
		var sp := AudioStreamPlayer3D.new()
		sp.unit_size = 14.0
		sp.max_distance = 160.0
		sp.volume_db = -2.0
		add_child(sp)
		_shot_players.append(sp)
	# Pool of positional players for bullet impacts (at the hit point).
	for i in 6:
		var ip := AudioStreamPlayer3D.new()
		ip.unit_size = 7.0
		ip.max_distance = 60.0
		get_tree().current_scene.add_child.call_deferred(ip)
		_impact_players.append(ip)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.82, 0.5)
	_flash.omni_range = 7.0
	_flash.light_energy = 0.0
	add_child(_flash)
	_build_pistol()
	_build_rifle()
	_switch_to(0)


func set_bus(bus_name: String) -> void:
	_bus = bus_name
	for sp in _shot_players:
		sp.bus = bus_name
	for ip in _impact_players:
		ip.bus = bus_name


func _mat(c: Color, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = 0.55
	return m


func _vm_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _build_hands(root: Node3D, two_handed: bool) -> void:
	var skin := _mat(Color(0.78, 0.6, 0.48))
	var sleeve := _mat(Color(0.25, 0.28, 0.24))
	_vm_box(root, Vector3(0.07, 0.07, 0.09), Vector3(0.0, -0.09, 0.05), skin)
	_vm_box(root, Vector3(0.08, 0.08, 0.26), Vector3(0.02, -0.13, 0.24), sleeve)
	if two_handed:
		_vm_box(root, Vector3(0.07, 0.07, 0.09), Vector3(-0.02, -0.05, -0.22), skin)
		_vm_box(root, Vector3(0.08, 0.08, 0.24), Vector3(-0.1, -0.1, -0.1), sleeve)


func _build_pistol() -> void:
	var root := Node3D.new()
	add_child(root)
	var gun := _mat(Color(0.16, 0.16, 0.18), 0.6)
	var grip := _mat(Color(0.1, 0.1, 0.1))
	_vm_box(root, Vector3(0.05, 0.09, 0.26), Vector3(0, 0, -0.08), gun)   # slide
	_vm_box(root, Vector3(0.045, 0.12, 0.07), Vector3(0, -0.09, 0.02), grip)
	_build_hands(root, false)
	var muzzle := Node3D.new()
	muzzle.position = Vector3(0, 0.0, -0.22)
	root.add_child(muzzle)
	_weapons.append({
		"name": "PISTOL", "auto": false, "damage": 34, "mag_size": 12,
		"mag": 12, "interval": 0.22, "recoil": 0.016, "reload_time": 1.35,
		"sound": load("res://assets/audio/pistol_fire.wav"),
		"model": root, "muzzle": muzzle,
	})


func _build_rifle() -> void:
	var root := Node3D.new()
	add_child(root)
	var gun := _mat(Color(0.14, 0.15, 0.16), 0.6)
	var furn := _mat(Color(0.23, 0.19, 0.14))
	_vm_box(root, Vector3(0.055, 0.09, 0.5), Vector3(0, 0, -0.15), gun)    # receiver+barrel
	_vm_box(root, Vector3(0.045, 0.07, 0.16), Vector3(0, -0.02, 0.2), furn)  # stock
	_vm_box(root, Vector3(0.04, 0.13, 0.05), Vector3(0, -0.1, -0.02), gun)  # mag
	_vm_box(root, Vector3(0.05, 0.06, 0.14), Vector3(0, -0.06, -0.25), furn)  # foregrip
	_build_hands(root, true)
	var muzzle := Node3D.new()
	muzzle.position = Vector3(0, 0.01, -0.42)
	root.add_child(muzzle)
	_weapons.append({
		"name": "RIFLE", "auto": true, "damage": 22, "mag_size": 30,
		"mag": 30, "interval": 0.1, "recoil": 0.011, "reload_time": 1.7,
		"sound": load("res://assets/audio/rifle_fire.wav"),
		"model": root, "muzzle": muzzle,
	})


func _switch_to(idx: int) -> void:
	if idx == _current or idx < 0 or idx >= _weapons.size():
		return
	_current = idx
	_reload_left = 0.0
	_equip_left = 0.5
	for i in _weapons.size():
		_weapons[i]["model"].visible = (i == idx)
	_handling.stream = _snd_equip
	_handling.play()
	_emit_ammo()


func _emit_ammo() -> void:
	var w := _weapons[_current]
	ammo_changed.emit("%s   %d / %d" % [w["name"], w["mag"], w["mag_size"]])


func _process(delta: float) -> void:
	if _current < 0:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_equip_left = maxf(0.0, _equip_left - delta)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			var w := _weapons[_current]
			w["mag"] = w["mag_size"]
			_emit_ammo()
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_capture_grace = 0.25
	else:
		_capture_grace = maxf(0.0, _capture_grace - delta)
		_handle_combat_input()
	# Viewmodel recoil / aim positioning
	_recoil_back = lerpf(_recoil_back, 0.0, minf(1.0, delta * 12.0))
	var target := _base_pos + Vector3(0, 0, _recoil_back)
	var camera := get_parent() as Camera3D
	if Input.is_action_pressed("aim") and _reload_left <= 0.0:
		target = Vector3(0.0, -0.22, -0.42 + _recoil_back)
		camera.set("zoom_offset", AIM_ZOOM)
	else:
		camera.set("zoom_offset", 0.0)
	position = position.lerp(target, minf(1.0, delta * 14.0))


func _handle_combat_input() -> void:
	var w := _weapons[_current]
	if Input.is_action_just_pressed("weapon_1"):
		_switch_to(0)
		return
	if Input.is_action_just_pressed("weapon_2"):
		_switch_to(1)
		return
	if Input.is_action_just_pressed("reload") and w["mag"] < w["mag_size"] \
			and _reload_left <= 0.0:
		_start_reload(w)
		return
	if _reload_left > 0.0 or _equip_left > 0.0 or _capture_grace > 0.0:
		return
	var wants_fire: bool = Input.is_action_pressed("fire") if w["auto"] \
			else Input.is_action_just_pressed("fire")
	if wants_fire and _cooldown <= 0.0:
		if w["mag"] <= 0:
			if Input.is_action_just_pressed("fire"):
				_handling.stream = _snd_empty
				_handling.play()
				_start_reload(w)
			return
		_fire(w)


func _start_reload(w: Dictionary) -> void:
	_reload_left = w["reload_time"]
	_handling.stream = _snd_reload
	_handling.play()


func _fire(w: Dictionary) -> void:
	w["mag"] -= 1
	_cooldown = w["interval"]
	_emit_ammo()
	# Gunshot from the muzzle, routed through the current reverb bus.
	var sp: AudioStreamPlayer3D = _shot_players[randi() % _shot_players.size()]
	sp.stream = w["sound"]
	sp.pitch_scale = randf_range(0.95, 1.05)
	sp.play()
	# Muzzle flash
	_flash.position = w["muzzle"].position
	_flash.light_energy = 2.6
	get_tree().create_tween().tween_property(_flash, "light_energy", 0.0, 0.06)
	# Recoil: camera kick + viewmodel pushback
	_recoil_back = 0.06
	var head: Node3D = player.get("head")
	head.rotation.x = clampf(head.rotation.x + w["recoil"],
			deg_to_rad(-85.0), deg_to_rad(85.0))
	player.rotate_y(randf_range(-0.004, 0.004))
	# Shell casing tinkle shortly after the shot
	get_tree().create_timer(0.28).timeout.connect(_play_shell)
	# Hitscan
	var camera := get_parent() as Camera3D
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * MAX_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		_apply_impact(hit, w["damage"])


func _play_shell() -> void:
	if not is_inside_tree():
		return
	var sp: AudioStreamPlayer3D = _shot_players[randi() % _shot_players.size()]
	if sp.playing:
		return
	sp.stream = _snd_shell
	sp.pitch_scale = randf_range(0.9, 1.1)
	sp.play()


func _apply_impact(hit: Dictionary, damage: int) -> void:
	var collider: Object = hit["collider"]
	var point: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	if collider is Node and (collider as Node).is_in_group("breakable_glass"):
		if collider.has_method("break_glass"):
			collider.break_glass()
		return
	if collider.has_method("take_hit"):
		collider.take_hit(damage, point)
		return
	var surface := "concrete"
	if collider is Node and (collider as Node).has_meta("surface"):
		surface = (collider as Node).get_meta("surface")
	# Impact sound at the hit point
	var ip: AudioStreamPlayer3D = _impact_players[_impact_idx]
	_impact_idx = (_impact_idx + 1) % _impact_players.size()
	ip.global_position = point
	ip.stream = _impact_sounds.get(surface, _impact_sounds["concrete"])
	ip.pitch_scale = randf_range(0.92, 1.08)
	ip.play()
	# Impact particles
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 0.35
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = normal
	p.spread = 35.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.02
	p.scale_amount_max = 0.05
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.75, 0.72, 0.66) if surface != "metal" \
			else Color(1.0, 0.85, 0.4)
	var pmesh := BoxMesh.new()
	pmesh.size = Vector3(0.03, 0.03, 0.03)
	pmesh.material = pm
	p.mesh = pmesh
	p.emitting = true
	get_tree().current_scene.add_child(p)
	p.global_position = point + normal * 0.03
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
