class_name GameSettings
extends RefCounted
## Global gameplay/camera settings (static — no autoload registration needed).
## Changed live from the pause menu; read by player + camera each frame.

static var mouse_sensitivity := 1.0   # multiplier, 0.2 .. 3.0
static var invert_y := false
static var fov := 75.0                # 60 .. 100
static var head_bob := true
static var camera_shake := 1.0        # 0 .. 1 scale for landing dips etc.
static var toggle_crouch := false     # false = hold CTRL (default)
