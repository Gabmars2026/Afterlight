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
	enemy.direct_nav = direct_nav
	enemy.died.connect(_on_died)
	add_child(enemy)
	enemy.set_night(_night)


func _on_died() -> void:
	get_tree().create_timer(respawn_delay).timeout.connect(_respawn)


func _respawn() -> void:
	if is_inside_tree():
		_spawn()
