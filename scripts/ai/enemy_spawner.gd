extends Node3D
## Keeps one zombie alive at this position; respawns it after a delay when
## it dies. kind: "shambler" (slow, tough) or "stalker" (fast, fragile).

const EnemyScript := preload("res://scripts/ai/enemy_base.gd")

var kind := "shambler"
var direct_nav := false
var respawn_delay := 18.0
var _night := false


func _ready() -> void:
	add_to_group("spawners")
	_spawn()


func set_night(night: bool) -> void:
	## Nights are dangerous: replacements arrive twice as fast.
	_night = night
	respawn_delay = 9.0 if night else 18.0


func _spawn() -> void:
	var enemy := EnemyScript.new()
	enemy.kind = kind
	if kind == "stalker":
		enemy.max_health = 55
		enemy.patrol_speed = 1.6
		enemy.chase_speed = 5.4
		enemy.attack_damage = 10
		enemy.attack_interval = 0.9
		enemy.vision_range = 28.0
		enemy.body_color = Color(0.38, 0.32, 0.36)
	enemy.position = Vector3.ZERO
	if kind == "screamer":
		enemy.max_health = 45
		enemy.chase_speed = 4.4
		enemy.attack_damage = 6
		enemy.attack_interval = 1.2
		enemy.vision_range = 30.0
		enemy.body_color = Color(0.78, 0.72, 0.62)
		enemy.is_screamer = true
		enemy.size_mult = 0.88
	elif kind == "brute":
		enemy.max_health = 320
		enemy.patrol_speed = 0.9
		enemy.chase_speed = 3.1
		enemy.attack_damage = 30
		enemy.attack_interval = 1.5
		enemy.vision_range = 20.0
		enemy.body_color = Color(0.42, 0.24, 0.2)
		enemy.is_brute = true
		enemy.size_mult = 1.38
		enemy.attack_reach = 3.0
	elif kind == "climber":
		enemy.max_health = 70
		enemy.chase_speed = 5.0
		enemy.attack_damage = 12
		enemy.vision_range = 26.0
		enemy.body_color = Color(0.35, 0.45, 0.3)
		enemy.is_climber = true
		enemy.size_mult = 0.94
	elif kind == "hunter":
		enemy.max_health = 110
		enemy.chase_speed = 3.4
		enemy.attack_damage = 18
		enemy.attack_interval = 0.8
		enemy.vision_range = 20.0
		enemy.body_color = Color(0.13, 0.11, 0.16)
		enemy.is_night_hunter = true
	enemy.direct_nav = direct_nav
	enemy.died.connect(_on_died)
	add_child(enemy)
	enemy.set_night(_night)


func _on_died() -> void:
	get_tree().create_timer(respawn_delay).timeout.connect(_respawn)


func _respawn() -> void:
	if is_inside_tree():
		_spawn()
