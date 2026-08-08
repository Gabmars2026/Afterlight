extends Node
## Day/night cycle. One game day lasts 12 real minutes. Drives the sun
## across the sky, fades the sky/ambient/fog to real darkness at night,
## brings up a dim moon, and makes zombies faster, sharper-eyed and
## quicker to respawn between 20:00 and 06:00.

signal time_changed(day: int, hour24: float, is_night: bool)
signal night_changed(is_night: bool)

const DAY_LENGTH_SEC := 720.0
const NIGHT_START := 20.0
const NIGHT_END := 6.0

const SUN_DAY := Color(1.0, 0.93, 0.78)
const SUN_LOW := Color(1.0, 0.55, 0.3)
const SKY_TOP_DAY := Color(0.24, 0.45, 0.78)
const SKY_TOP_NIGHT := Color(0.015, 0.02, 0.06)
const SKY_HOR_DAY := Color(0.73, 0.78, 0.84)
const SKY_HOR_DUSK := Color(0.92, 0.5, 0.28)
const SKY_HOR_NIGHT := Color(0.05, 0.07, 0.13)
const FOG_DAY := Color(0.78, 0.8, 0.82)
const FOG_NIGHT := Color(0.03, 0.04, 0.08)

var sun: DirectionalLight3D
var env: Environment

var day := 1
var hour := 9.0
var is_night := false

var _moon: DirectionalLight3D
var _sky: ProceduralSkyMaterial


func _ready() -> void:
	_sky = env.sky.sky_material
	_moon = DirectionalLight3D.new()
	_moon.rotation_degrees = Vector3(-38, -140, 0)
	_moon.light_color = Color(0.55, 0.66, 0.92)
	_moon.light_energy = 0.0
	_moon.visible = false
	add_child(_moon)
	_apply(0.0)


func _process(delta: float) -> void:
	hour += delta * 24.0 / DAY_LENGTH_SEC
	if hour >= 24.0:
		hour -= 24.0
		day += 1
	var night := hour >= NIGHT_START or hour < NIGHT_END
	if night != is_night:
		is_night = night
		night_changed.emit(is_night)
		get_tree().call_group("enemies", "set_night", is_night)
		get_tree().call_group("spawners", "set_night", is_night)
	_apply(delta)
	time_changed.emit(day, hour, is_night)


func _apply(_delta: float) -> void:
	# 0 at 06:00, 1 at noon, 0 at 18:00 (sun height factor)
	var t := clampf((hour - 6.0) / 12.0, 0.0, 1.0)
	var height := sin(t * PI)
	if hour < 6.0 or hour > 18.0:
		height = 0.0

	# Sun sweeps east -> west across the sky during the day
	var elev := height * 58.0 + 2.0
	var azim := lerpf(115.0, -45.0, t)
	sun.rotation_degrees = Vector3(-elev, azim, 0)
	sun.light_energy = height * 1.25
	sun.light_color = SUN_LOW.lerp(SUN_DAY, clampf(height * 1.6, 0.0, 1.0))
	sun.shadow_enabled = height > 0.02

	# Dusk/dawn glow on the horizon while the sun is low but up
	var dusk := clampf(1.0 - height * 3.2, 0.0, 1.0) if height > 0.0 else 0.0
	var sky_hor := SKY_HOR_NIGHT.lerp(SKY_HOR_DAY, height).lerp(SKY_HOR_DUSK, dusk * 0.7)
	_sky.sky_top_color = SKY_TOP_NIGHT.lerp(SKY_TOP_DAY, height)
	_sky.sky_horizon_color = sky_hor
	_sky.ground_horizon_color = sky_hor
	_sky.ground_bottom_color = Color(0.02, 0.02, 0.04).lerp(Color(0.45, 0.4, 0.3), height)

	env.ambient_light_energy = lerpf(0.14, 0.95, height)
	env.fog_light_color = FOG_NIGHT.lerp(FOG_DAY, height)

	_moon.visible = height < 0.05
	_moon.light_energy = (1.0 - height * 20.0) * 0.16 if height < 0.05 else 0.0
