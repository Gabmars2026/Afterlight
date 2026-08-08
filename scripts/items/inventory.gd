extends Node
## Slot inventory (Phase 7). 12 slots, each null or {id, count, dur}.

signal changed

const SIZE := 12
const DEFS := {
	"bandage": {"label": "BANDAGE", "stack": 5, "hint": "Click to heal 35 HP"},
	"ammo_pistol": {"label": "PISTOL AMMO", "stack": 48, "hint": "Used when reloading"},
	"ammo_rifle": {"label": "RIFLE AMMO", "stack": 90, "hint": "Used when reloading"},
	"pipe": {"label": "STEEL PIPE", "stack": 1, "melee": true,
			"damage": 26, "interval": 0.5, "durability": 30, "hint": "Click to equip"},
	"bat": {"label": "BASEBALL BAT", "stack": 1, "melee": true,
			"damage": 36, "interval": 0.62, "durability": 20, "hint": "Click to equip"},
	"scrap": {"label": "SCRAP METAL", "stack": 12, "hint": "Crafting material"},
	"planks": {"label": "WOOD PLANKS", "stack": 12, "hint": "Crafting material"},
}

var slots: Array = []


func _init() -> void:
	slots.resize(SIZE)


## Adds items, filling existing stacks first. Returns the leftover count
## that did not fit (0 when everything was stored).
func add_item(id: String, count: int = 1) -> int:
	if not DEFS.has(id):
		return count
	var stack: int = DEFS[id]["stack"]
	# Top up existing stacks
	for i in SIZE:
		if count <= 0:
			break
		var it = slots[i]
		if it != null and it["id"] == id and it["count"] < stack:
			var put: int = mini(count, stack - it["count"])
			it["count"] += put
			count -= put
	# Then open new slots
	for i in SIZE:
		if count <= 0:
			break
		if slots[i] == null:
			var put: int = mini(count, stack)
			var it := {"id": id, "count": put}
			if DEFS[id].has("durability"):
				it["dur"] = DEFS[id]["durability"]
			slots[i] = it
			count -= put
	changed.emit()
	return count


func count_of(id: String) -> int:
	var total := 0
	for it in slots:
		if it != null and it["id"] == id:
			total += it["count"]
	return total


## Removes up to `count` items of `id`. Returns how many were removed.
func take(id: String, count: int) -> int:
	var taken := 0
	for i in SIZE:
		if taken >= count:
			break
		var it = slots[i]
		if it != null and it["id"] == id:
			var grab: int = mini(count - taken, it["count"])
			it["count"] -= grab
			taken += grab
			if it["count"] <= 0:
				slots[i] = null
	if taken > 0:
		changed.emit()
	return taken


func consume(slot: int, count: int = 1) -> void:
	var it = slots[slot]
	if it == null:
		return
	it["count"] -= count
	if it["count"] <= 0:
		slots[slot] = null
	changed.emit()


## Wears the melee item in `slot` by one hit. Returns true if it broke.
func damage_melee(slot: int) -> bool:
	var it = slots[slot]
	if it == null or not it.has("dur"):
		return false
	it["dur"] -= 1
	if it["dur"] <= 0:
		slots[slot] = null
		changed.emit()
		return true
	changed.emit()
	return false


## Best melee weapon slot (highest damage), or -1 for bare fists.
func best_melee() -> int:
	var best := -1
	var best_dmg := 0
	for i in SIZE:
		var it = slots[i]
		if it != null and DEFS[it["id"]].get("melee", false):
			var dmg: int = DEFS[it["id"]]["damage"]
			if dmg > best_dmg:
				best_dmg = dmg
				best = i
	return best


func serialize() -> Array:
	var out := []
	for it in slots:
		out.append(null if it == null else it.duplicate())
	return out


func restore(data: Array) -> void:
	slots.clear()
	slots.resize(SIZE)
	for i in mini(data.size(), SIZE):
		if data[i] is Dictionary:
			var it := {"id": String(data[i]["id"]), "count": int(data[i]["count"])}
			if data[i].has("dur"):
				it["dur"] = int(data[i]["dur"])
			slots[i] = it
	changed.emit()
