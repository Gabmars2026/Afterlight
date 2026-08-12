extends Node
## Phase 20: GTA-style WANTED heat. Crimes add heat; it slowly cools
## off when you behave. Cops hunt you while any stars are showing.

var heat := 0.0
var hud: Node


func _ready() -> void:
	add_to_group("wanted_manager")


func add_heat(amount: float) -> void:
	heat = clampf(heat + amount, 0.0, 5.0)
	_update_hud()


func _process(delta: float) -> void:
	if heat > 0.0:
		heat = maxf(heat - 0.035 * delta, 0.0)
		_update_hud()


func _update_hud() -> void:
	if hud and hud.has_method("set_wanted"):
		hud.set_wanted(clampi(int(ceil(heat - 0.05)), 0, 5))
