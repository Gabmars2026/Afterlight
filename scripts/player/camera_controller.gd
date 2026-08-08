class_name CameraController
extends Camera3D
## First-person camera: head bob, strafe tilt, sprint FOV kick, landing dip.
## Created by player.gd as a child of the Head node.
## Respects GameSettings: fov, head_bob on/off, camera_shake scale.

const SPRINT_FOV_KICK := 8.0
const BOB_AMPLITUDE := 0.028
const TILT_MAX := 0.02

var bob_phase := 0.0

var _land_dip := 0.0
var _target_tilt := 0.0


func setup() -> void:
	fov = GameSettings.fov
	near = 0.05
	current = true


## Called each physics frame by player.gd.
func update_motion(delta: float, hspeed: float, sprinting: bool, on_floor: bool, strafe_dir: float) -> void:
	# Head bob driven by horizontal speed (toggleable in settings)
	if on_floor and hspeed > 0.5:
		bob_phase += delta * hspeed * 1.55
	var amp := BOB_AMPLITUDE if GameSettings.head_bob else 0.0
	var speed_factor: float = clampf(hspeed / 7.0, 0.0, 1.2)
	var bob_y := sin(bob_phase) * amp * speed_factor
	var bob_x := cos(bob_phase * 0.5) * amp * 0.6 * speed_factor

	# Landing dip decays back to zero (scaled by camera shake setting)
	_land_dip = lerpf(_land_dip, 0.0, 9.0 * delta)

	position = Vector3(bob_x, bob_y - _land_dip * GameSettings.camera_shake, 0)

	# Strafe tilt
	_target_tilt = -strafe_dir * TILT_MAX * GameSettings.camera_shake
	rotation.z = lerpf(rotation.z, _target_tilt, 8.0 * delta)

	# FOV: settings value + sprint kick, always smooth
	var target_fov := GameSettings.fov + (SPRINT_FOV_KICK if (sprinting and hspeed > 5.5) else 0.0)
	fov = lerpf(fov, target_fov, 6.0 * delta)


func on_landed(fall_speed: float) -> void:
	_land_dip = clampf(fall_speed * 0.035, 0.05, 0.3)
