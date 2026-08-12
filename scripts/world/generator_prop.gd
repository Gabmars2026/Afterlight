class_name GeneratorProp
extends Interactable
## A generator the player can start/stop. When running it hums in 3D and
## powers a linked light. Built in code by test_zone.gd.

var powered_light: Light3D
var running := false

var _hum: AudioStreamPlayer3D
var _start_snd: AudioStreamPlayer3D


func _ready() -> void:
	super()
	prompt = "Press E to start generator"
	set_meta("surface", "metal")
	_hum = AudioStreamPlayer3D.new()
	var hum_stream: AudioStream = load("res://assets/audio/generator_hum.wav")
	if hum_stream is AudioStreamWAV:
		hum_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		hum_stream.loop_end = int(hum_stream.get_length() * hum_stream.mix_rate)
	_hum.stream = hum_stream
	_hum.unit_size = 5.0
	_hum.max_distance = 45.0
	_hum.volume_db = -6.0
	add_child(_hum)
	_start_snd = AudioStreamPlayer3D.new()
	_start_snd.stream = load("res://assets/audio/generator_start.wav")
	_start_snd.unit_size = 5.0
	_start_snd.max_distance = 45.0
	add_child(_start_snd)
	if powered_light:
		powered_light.visible = false


func interact(user: Node) -> void:
	running = not running
	if running:
		_start_snd.play()
		get_tree().create_timer(0.7).timeout.connect(_engage)
		prompt = "Press E to stop generator"
	else:
		_hum.stop()
		if powered_light:
			powered_light.visible = false
		prompt = "Press E to start generator"
	super(user)


func _engage() -> void:
	if not running or not is_inside_tree():
		return
	_hum.play()
	if powered_light:
		powered_light.visible = true
