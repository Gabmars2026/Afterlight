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
	used.emit(user)
