extends Node
## Faction system (Phase 11). Four factions with reputation (-100..100)
## and named territory zones announced when the player crosses them.

signal rep_changed(faction: String, value: int)
signal territory_changed(text: String)

const FACTIONS := {
	"survivors": {"label": "MARKET SURVIVORS"},
	"wardens": {"label": "THE WARDENS"},
	"scavengers": {"label": "SCAVENGER UNION"},
	"feral": {"label": "THE FERAL"},
}

## Territory rectangles: [min_x, max_x, min_z, max_z, faction, zone name]
const TERRITORIES := [
	[20, 46, 8, 38, "survivors", "OLD MARKET - Market Survivors turf"],
	[-36, -18, -36, -20, "wardens", "THE BLOCKS - Warden patrol zone"],
	[-30, -16, 24, 38, "scavengers", "THE YARDS - Scavenger Union turf"],
	[-45, 45, -75, -45, "wardens", "MERIDIAN HEIGHTS - Warden watch"],
	[-75, 75, 45, 75, "scavengers", "CANAL DISTRICT - Scavenger docks"],
	[45, 75, -45, 45, "survivors", "GREENROW - survivor gardens"],
	[-75, -45, -45, 45, "feral", "ASHLINE - feral ground"],
	[95, 245, -65, 85, "survivors", "NEON DISTRICT - downtown"],
]

var player: Node
var rep := {"survivors": 0, "wardens": 0, "scavengers": 0, "feral": -100}
var _zone := ""
var _check := 0.0


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or player == null:
		return
	_check = 0.5
	var pos: Vector3 = player.global_position
	var zone := "THE STREETS - contested ground"
	for t in TERRITORIES:
		if pos.x >= t[0] and pos.x <= t[1] and pos.z >= t[2] and pos.z <= t[3]:
			zone = t[5]
			break
	if zone != _zone:
		_zone = zone
		territory_changed.emit(zone)


func on_npc_talked(_nm: String) -> void:
	pass


func add_rep(faction: String, amount: int) -> void:
	if not rep.has(faction) or faction == "feral":
		return
	var old: int = rep[faction]
	rep[faction] = clampi(old + amount, -100, 100)
	if rep[faction] != old:
		rep_changed.emit(faction, rep[faction])
		if amount > 0:
			player.notify.emit("+%d REP  %s" % [amount, FACTIONS[faction]["label"]])


func standing(faction: String) -> String:
	var v: int = rep.get(faction, 0)
	if v >= 40:
		return "ALLY"
	if v >= 10:
		return "FRIENDLY"
	if v <= -40:
		return "HOSTILE"
	if v <= -10:
		return "DISLIKED"
	return "NEUTRAL"


func on_enemy_killed() -> void:
	# The Wardens respect anyone thinning the herd (small, capped gain)
	if rep["wardens"] < 30:
		add_rep("wardens", 1)


func serialize() -> Dictionary:
	return rep.duplicate()


func restore(data: Dictionary) -> void:
	for k in rep:
		if data.has(k):
			rep[k] = int(data[k])
