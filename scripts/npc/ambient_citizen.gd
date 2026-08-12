extends CharacterBody3D
## Lightweight clothed pedestrian used by the clean rebuild city.

@export_file("*.gltf") var model_path := ""
@export var wander_radius := 6.0
@export var walk_speed := 1.35

var _anchor := Vector3.ZERO
var _target := Vector3.ZERO
var _anim: AnimationPlayer
var _idle_time := 0.0
var _emote_cooldown := 0.0
var _emoting := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(name)
	_anchor = global_position
	_build_collision()
	_build_model()
	_choose_target()


func _physics_process(delta: float) -> void:
	_emote_cooldown = maxf(0.0, _emote_cooldown - delta)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.5
	if _idle_time > 0.0:
		_idle_time -= delta
		velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
		if not _emoting and _emote_cooldown <= 0.0 \
				and _rng.randf() < delta * 0.18:
			_play_emote()
		elif not _emoting:
			_play("Idle_Neutral")
	else:
		var direction := _target - global_position
		direction.y = 0.0
		if direction.length() < 0.7:
			_idle_time = _rng.randf_range(1.0, 3.5)
			_choose_target()
		else:
			direction = direction.normalized()
			velocity.x = direction.x * walk_speed
			velocity.z = direction.z * walk_speed
			# The Quaternius character faces local +Z. Point +Z along travel so
			# pedestrians no longer moonwalk backwards through the city.
			rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 7.0 * delta)
			_play("Walk")
	move_and_slide()
	if is_on_wall():
		_choose_target()


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.875
	add_child(collision)
	collision_layer = 4
	collision_mask = 1


func _build_model() -> void:
	var scene := load(model_path) as PackedScene
	if scene == null:
		push_warning("Citizen model could not load: %s" % model_path)
		return
	var model := scene.instantiate() as Node3D
	model.rotation.y = 0.0
	add_child(model)
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var looping_animations: Array[String] = ["Idle", "Idle_Neutral", "Walk", "Run"]
	for animation_name in looping_animations:
		var resolved := _find_animation(animation_name)
		if resolved != &"":
			_anim.get_animation(resolved).loop_mode = Animation.LOOP_LINEAR
	_play("Idle_Neutral")
	if _anim != null:
		_anim.animation_finished.connect(_on_animation_finished)


func _play_emote() -> void:
	var choices: Array[String] = ["Wave", "Interact", "Kick_Left", "Punch_Right"]
	var choice: String = choices[_rng.randi_range(0, choices.size() - 1)]
	var resolved := _find_animation(choice)
	if resolved == &"":
		return
	_emoting = true
	_emote_cooldown = _rng.randf_range(8.0, 16.0)
	_anim.play(resolved, 0.2)


func _on_animation_finished(_animation_name: StringName) -> void:
	_emoting = false


func _choose_target() -> void:
	var angle := _rng.randf_range(0.0, TAU)
	var distance := _rng.randf_range(wander_radius * 0.35, wander_radius)
	_target = _anchor + Vector3(sin(angle), 0.0, cos(angle)) * distance


func _play(animation_name: String) -> void:
	if _anim == null:
		return
	var resolved := _find_animation(animation_name)
	if resolved == &"" or _anim.current_animation == resolved:
		return
	_anim.play(resolved, 0.2)


func _find_animation(animation_name: String) -> StringName:
	if _anim.has_animation(animation_name):
		return StringName(animation_name)
	for available in _anim.get_animation_list():
		var full_name := String(available)
		if full_name.ends_with("/" + animation_name) \
				or full_name.ends_with("|" + animation_name) \
				or full_name.ends_with(":" + animation_name):
			return available
	return &""
