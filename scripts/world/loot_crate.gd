class_name LootCrate
extends Interactable
## Searchable container: opens with sound + lid animation, gives supplies once.

var _opened := false
var lid: Node3D = null


func _ready() -> void:
	add_to_group("interactable")
	prompt = "Press E to search crate"


func interact(user: Node) -> void:
	if _opened:
		return
	_opened = true
	prompt = "Empty crate"
	var p := AudioStreamPlayer3D.new()
	p.stream = load("res://assets/audio/crate_open.wav")
	p.unit_size = 5.0
	p.max_distance = 30.0
	add_child(p)
	p.play()
	if lid:
		var tw := create_tween()
		tw.tween_property(lid, "rotation:x", -1.9, 0.45).set_trans(Tween.TRANS_BACK)
	# Random supplies straight into the player's inventory
	if user.has_method("pickup"):
		var roll := randf()
		if roll < 0.2:
			user.pickup("ammo_pistol", randi_range(10, 20))
		elif roll < 0.38:
			user.pickup("ammo_rifle", randi_range(12, 28))
		elif roll < 0.52:
			user.pickup("bandage", randi_range(1, 2))
		elif roll < 0.6:
			user.pickup("pipe", 1)
		elif roll < 0.68:
			user.pickup("bat", 1)
		elif roll < 0.76:
			user.pickup("sword", 1)
		elif roll < 0.86:
			user.pickup("scrap", randi_range(2, 5))
		elif roll < 0.94:
			user.pickup("cloth", randi_range(2, 4))
		else:
			user.pickup("planks", randi_range(2, 4))
		# Every crate also holds a few loose bullets
		user.pickup("ammo_pistol", randi_range(4, 8))
		user.pickup("ammo_rifle", randi_range(4, 10))
	used.emit(user)
