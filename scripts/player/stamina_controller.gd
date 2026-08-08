class_name StaminaController
extends Node
## Manages stamina: sprint drain, action costs, regeneration, exhaustion.
## Attach as a child of the Player node. No required children.

signal stamina_changed(current: float, maximum: float)
signal exhausted_changed(is_exhausted: bool)

const MAX_STAMINA := 100.0
const REGEN_PER_SEC := 16.0
const REGEN_DELAY := 0.9
const EXHAUSTION_RECOVER_AT := 25.0

var stamina: float = MAX_STAMINA
var is_exhausted := false

var _regen_wait := 0.0


func _process(delta: float) -> void:
	if _regen_wait > 0.0:
		_regen_wait -= delta
		return
	if stamina < MAX_STAMINA:
		stamina = minf(MAX_STAMINA, stamina + REGEN_PER_SEC * delta)
		stamina_changed.emit(stamina, MAX_STAMINA)
		if is_exhausted and stamina >= EXHAUSTION_RECOVER_AT:
			is_exhausted = false
			exhausted_changed.emit(false)


## Continuous drain (e.g. sprinting). Returns false when out of stamina.
func drain(amount: float) -> bool:
	if is_exhausted:
		return false
	stamina = maxf(0.0, stamina - amount)
	_regen_wait = REGEN_DELAY
	stamina_changed.emit(stamina, MAX_STAMINA)
	if stamina <= 0.0:
		is_exhausted = true
		exhausted_changed.emit(true)
		return false
	return true


## One-shot cost (e.g. jumping). Returns false if not enough stamina.
func try_spend(amount: float) -> bool:
	if is_exhausted or stamina < amount:
		return false
	stamina -= amount
	_regen_wait = REGEN_DELAY
	stamina_changed.emit(stamina, MAX_STAMINA)
	if stamina <= 0.0:
		is_exhausted = true
		exhausted_changed.emit(true)
	return true


func can_sprint() -> bool:
	return not is_exhausted and stamina > 1.0
