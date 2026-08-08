class_name CameraController
extends Camera3D
## First-person camera: head bob, strafe tilt, sprint FOV kick, landing dip.
## Created by player.gd as a child of the Head node.

const BASE_FOV := 82.0
const SPRINT_FOV := 90.0
const BOB_AMPLITUDE := 0.028
const TILT_MAX := 0.02

var bob_phase := 0.0

var _land_dip := 0.0
var _target_tilt := 0.0


func setup() -> void:
	fov = BASE_FOV
	near = 0.05
	current = true


## Called each physics frame by player.gd.
func update_motion(delta: float, hspeed: float, sprinting: bool, on_floor: bool, strafe_dir: float) -> void:
	# Head bob driven by horizontal speed
	if on_floor and hspeed > 0.5:
		bob_phase += delta * hspeed * 1.55
	var speed_factor: float = clampf(hspeed / 7.0, 0.0, 1.2)
	var bob_y := sin(bob_phase) * BOB_AMPLITUDE * speed_factor
	var bob_x := cos(bob_phase * 0.5) * BOB_AMPLITUDE * 0.6 * speed_factor

	# Landing dip decays back to zero
	_land_dip = lerpf(_land_dip, 0.0, 9.0 * delta)

	position = Vector3(bob_x, bob_y - _land_dip, 0)

	# Strafe tilt
	_target_tilt = -strafe_dir * TILT_MAX
	rotation.z = lerpf(rotation.z, _target_tilt, 8.0 * delta)

	# Sprint FOV kick
	var target_fov := SPRINT_FOV if (sprinting and hspeed > 5.5) else BASE_FOV
	fov = lerpf(fov, target_fov, 7.0 * delta)


func on_landed(fall_speed: float) -> void:
	_land_dip = clampf(fall_speed * 0.035, 0.05, 0.3)


## Returns true each time a bob cycle completes (used for footstep timing).
func stepped_this_frame(prev_phase: float) -> bool:
	return fmod(prev_phase, TAU) > fmod(bob_phase, TAU)
