class_name WeaponManager
extends Node3D
## First-person weapon system: viewmodel, firing, reload, recoil, muzzle
## flash, and surface-based bullet impacts with 3D audio.
## Created in code as a child of the player's camera.

signal ammo_changed(text: String)
signal weapon_switched(idx: int)
signal action_played(anim: String)

const MAX_RANGE := 220.0
const AIM_ZOOM := -10.0

var player: CharacterBody3D
var _weapons: Array[Dictionary] = []
var _current := -1
var _melee_slot := -1  # inventory slot of the equipped melee item (-1 = fists)
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
var _snd_swing: AudioStream
var _snd_melee_hit: AudioStream
var _snd_punch: AudioStream
var _snd_clang: AudioStream
var _snd_break: AudioStream
var _impact_sounds := {}


func setup(p: CharacterBody3D) -> void:
	player = p
	position = _base_pos
	_snd_empty = load("res://assets/audio/empty_click.wav")
	_snd_reload = load("res://assets/audio/reload.wav")
	_snd_equip = load("res://assets/audio/equip.wav")
	_snd_shell = load("res://assets/audio/shell_drop.wav")
	_snd_swing = load("res://assets/audio/melee_swing.wav")
	_snd_melee_hit = load("res://assets/audio/melee_hit.wav")
	_snd_punch = load("res://assets/audio/punch_hit.wav")
	_snd_clang = load("res://assets/audio/melee_clang.wav")
	_snd_break = load("res://assets/audio/wood_break.wav")
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
	_build_melee()
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
		"ammo_id": "ammo_pistol",
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
		"ammo_id": "ammo_rifle",
		"sound": load("res://assets/audio/rifle_fire.wav"),
		"model": root, "muzzle": muzzle,
	})


func _build_melee() -> void:
	var root := Node3D.new()
	add_child(root)
	var skin := _mat(Color(0.78, 0.6, 0.48))
	var sleeve := _mat(Color(0.25, 0.28, 0.24))
	# Fists: two raised hands
	var fists := Node3D.new()
	root.add_child(fists)
	_vm_box(fists, Vector3(0.09, 0.09, 0.11), Vector3(0.06, -0.06, -0.05), skin)
	_vm_box(fists, Vector3(0.08, 0.08, 0.2), Vector3(0.08, -0.1, 0.12), sleeve)
	_vm_box(fists, Vector3(0.09, 0.09, 0.11), Vector3(-0.14, -0.1, 0.02), skin)
	_vm_box(fists, Vector3(0.08, 0.08, 0.2), Vector3(-0.16, -0.14, 0.18), sleeve)
	# Steel pipe held in the right hand
	var pipe := Node3D.new()
	root.add_child(pipe)
	var steel := _mat(Color(0.45, 0.47, 0.5), 0.8)
	_vm_box(pipe, Vector3(0.05, 0.05, 0.62), Vector3(0.02, -0.02, -0.22), steel)
	_vm_box(pipe, Vector3(0.07, 0.07, 0.08), Vector3(0.02, -0.02, -0.5), steel)
	_vm_box(pipe, Vector3(0.09, 0.09, 0.11), Vector3(0.02, -0.08, 0.05), skin)
	_vm_box(pipe, Vector3(0.08, 0.08, 0.2), Vector3(0.04, -0.12, 0.22), sleeve)
	# Baseball bat
	var bat := Node3D.new()
	root.add_child(bat)
	var wood := _mat(Color(0.52, 0.36, 0.2))
	_vm_box(bat, Vector3(0.05, 0.05, 0.3), Vector3(0.02, -0.03, 0.0), wood)
	_vm_box(bat, Vector3(0.08, 0.08, 0.42), Vector3(0.02, 0.0, -0.33), wood)
	_vm_box(bat, Vector3(0.09, 0.09, 0.11), Vector3(0.02, -0.09, 0.12), skin)
	_vm_box(bat, Vector3(0.08, 0.08, 0.2), Vector3(0.04, -0.13, 0.28), sleeve)
	_weapons.append({
		"name": "FISTS", "melee": true, "auto": false, "damage": 12,
		"interval": 0.45, "kind": "fists",
		"model": root, "submodels": {"fists": fists, "pipe": pipe, "bat": bat},
	})


## Equip the melee item in inventory `slot` (-1 or empty slot = bare fists),
## then switch to the melee weapon.
func equip_melee(slot: int) -> void:
	var w: Dictionary = _weapons[2]
	var inv: Node = player.inventory
	if slot < 0 or inv.slots[slot] == null \
			or not inv.DEFS[inv.slots[slot]["id"]].get("melee", false):
		_melee_slot = -1
		w["name"] = "FISTS"
		w["damage"] = 12
		w["interval"] = 0.45
		w["kind"] = "fists"
	else:
		var id: String = inv.slots[slot]["id"]
		_melee_slot = slot
		w["name"] = inv.DEFS[id]["label"]
		w["damage"] = inv.DEFS[id]["damage"]
		w["interval"] = inv.DEFS[id]["interval"]
		w["kind"] = id
	for k in w["submodels"]:
		w["submodels"][k].visible = (k == w["kind"])
	if _current != 2:
		_switch_to(2)
	else:
		_emit_ammo()


func _switch_to(idx: int) -> void:
	if idx == _current or idx < 0 or idx >= _weapons.size():
		return
	_current = idx
	weapon_switched.emit(idx)
	_reload_left = 0.0
	_equip_left = 0.5
	for i in _weapons.size():
		_weapons[i]["model"].visible = (i == idx)
	_handling.stream = _snd_equip
	_handling.play()
	_emit_ammo()


func current_index() -> int:
	return _current


func _emit_ammo() -> void:
	var w := _weapons[_current]
	if w.get("melee", false):
		if _melee_slot >= 0 and player.inventory.slots[_melee_slot] != null:
			ammo_changed.emit("%s   %d" % [w["name"],
					player.inventory.slots[_melee_slot]["dur"]])
		else:
			ammo_changed.emit("FISTS")
	else:
		ammo_changed.emit("%s   %d / %d   +%d" % [w["name"], w["mag"],
				w["mag_size"], player.inventory.count_of(w["ammo_id"])])


func _process(delta: float) -> void:
	if _current < 0:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_equip_left = maxf(0.0, _equip_left - delta)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			var w := _weapons[_current]
			if not w.get("melee", false):
				var needed: int = w["mag_size"] - w["mag"]
				w["mag"] += player.inventory.take(w["ammo_id"], needed)
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
	if Input.is_action_pressed("aim") and _reload_left <= 0.0 \
			and not _weapons[_current].get("melee", false):
		target = Vector3(0.0, -0.22, -0.42 + _recoil_back)
		camera.set("zoom_offset", AIM_ZOOM)
	else:
		camera.set("zoom_offset", 0.0)
	position = position.lerp(target, minf(1.0, delta * 14.0))


func _handle_combat_input() -> void:
	if player.health <= 0 or player.get("is_hanging"):
		return
	var w := _weapons[_current]
	if Input.is_action_just_pressed("weapon_1"):
		_switch_to(0)
		return
	if Input.is_action_just_pressed("weapon_2"):
		_switch_to(1)
		return
	if Input.is_action_just_pressed("weapon_3"):
		equip_melee(_melee_slot if _melee_slot >= 0 else player.inventory.best_melee())
		return
	if w.get("melee", false):
		if _equip_left > 0.0 or _capture_grace > 0.0 or _cooldown > 0.0:
			return
		var heavy := Input.is_action_just_pressed("aim")
		if heavy or Input.is_action_just_pressed("fire"):
			var cost := 14.0 if heavy else 6.0
			if player.stamina.is_exhausted or player.stamina.stamina < cost:
				return
			player.stamina.drain(cost)
			_melee_attack(w, heavy)
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
	action_played.emit("Pistol_Reload")
	if player.inventory.count_of(w["ammo_id"]) <= 0:
		_handling.stream = _snd_empty
		_handling.play()
		player.notify.emit("NO %s LEFT" % player.inventory.DEFS[w["ammo_id"]]["label"])
		return
	_reload_left = w["reload_time"]
	_handling.stream = _snd_reload
	_handling.play()


func _fire(w: Dictionary) -> void:
	action_played.emit("Pistol_Shoot")
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
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		_apply_impact(hit, w["damage"])
	# Gunshots are LOUD: every zombie in a wide radius comes hunting
	get_tree().call_group("enemies", "hear_noise", player.global_position, 45.0)


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


# ---------------------------------------------------------------- melee

func _melee_attack(w: Dictionary, heavy: bool) -> void:
	action_played.emit("Sword_Attack" if not heavy else "Punch_Cross")
	_cooldown = w["interval"] * (1.7 if heavy else 1.0)
	_handling.stream = _snd_swing
	_handling.pitch_scale = 0.8 if heavy else randf_range(0.95, 1.1)
	_handling.play()
	# Viewmodel swing: wind back, then chop across the screen
	var root: Node3D = w["model"]
	var windup := 0.22 if heavy else 0.08
	var tw := create_tween()
	tw.tween_property(root, "rotation", Vector3(0.35, 0.4, 0.2), windup) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "rotation", Vector3(-0.5, -0.35, -0.3), 0.09) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(root, "rotation", Vector3.ZERO, 0.25) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(windup + 0.07).timeout.connect(
			_melee_strike.bind(w, heavy))


func _melee_strike(w: Dictionary, heavy: bool) -> void:
	if player.health <= 0:
		return
	var camera := get_parent() as Camera3D
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * 2.1
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	# Melee is quiet: only very close zombies notice
	get_tree().call_group("enemies", "hear_noise", player.global_position, 9.0)
	if hit.is_empty():
		return
	var damage := int(round(w["damage"] * (2.2 if heavy else 1.0)))
	var collider: Object = hit["collider"]
	var flesh: bool = collider.has_method("take_hit") \
			and collider.is_in_group("enemies")
	# Impact sound at the point of contact
	var ip: AudioStreamPlayer3D = _impact_players[randi() % _impact_players.size()]
	ip.global_position = hit["position"]
	if flesh:
		ip.stream = _snd_punch if w["kind"] == "fists" else _snd_melee_hit
	elif w["kind"] == "pipe":
		ip.stream = _snd_clang
	else:
		ip.stream = _snd_melee_hit
	ip.pitch_scale = randf_range(0.9, 1.1)
	ip.play()
	# Small camera thump on contact
	var head: Node3D = player.get("head")
	head.rotation.x = clampf(head.rotation.x + (0.02 if heavy else 0.01),
			deg_to_rad(-85.0), deg_to_rad(85.0))
	_apply_impact(hit, damage)
	# Wear down the equipped melee item
	if _melee_slot >= 0:
		if player.inventory.damage_melee(_melee_slot):
			_handling.stream = _snd_break
			_handling.pitch_scale = 1.0
			_handling.play()
			player.notify.emit("YOUR WEAPON BROKE")
			equip_melee(player.inventory.best_melee())
	_emit_ammo()
