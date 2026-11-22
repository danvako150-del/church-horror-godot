extends Node3D

var player: CharacterBody3D
var rain: GPUParticles3D
var post_material: ShaderMaterial
var ambience: Array[AudioStreamPlayer] = []

func _exit_tree() -> void:
	for audio: AudioStreamPlayer in ambience:
		audio.stop()
		audio.stream = null

func _ready() -> void:
	_register_controls()
	add_to_group("atmosphere")
	var level: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/level.json"))
	player = CharacterBody3D.new()
	player.set_script(load("res://scripts/player.gd"))
	var origin: Array = level.spawn.origin
	player.position = Vector3(origin[0], origin[1], origin[2])
	# Source faces +X at yaw=0; Godot camera faces -Z.
	player.rotation.y = deg_to_rad(float(level.spawn.angles[1]) - 90.0)
	add_child(player)
	_setup_atmosphere()
	_setup_rain()
	for pair in [["res://assets/audio/church/wind_loop.wav", -16.0], ["res://assets/audio/church/rain_loop.wav", -20.0]]:
		var file: String = str(pair[0])
		if ResourceLoader.exists(file):
			var audio := AudioStreamPlayer.new()
			audio.stream = load(file)
			if audio.stream is AudioStreamWAV:
				audio.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				audio.stream.loop_begin = 0
				audio.stream.loop_end = int(audio.stream.get_length() * audio.stream.mix_rate)
			audio.volume_db = float(pair[1])
			add_child(audio)
			ambience.append(audio)
			if DisplayServer.get_name() != "headless":
				audio.play()
	print("CHURCH_READY Godot native port v29")

func _register_controls() -> void:
	var controls: Dictionary = {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "sprint": KEY_SHIFT, "crouch": KEY_CTRL, "jump": KEY_SPACE}
	for action: String in controls:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key := InputEventKey.new()
			key.physical_keycode = controls[action]
			InputMap.action_add_event(action, key)

func _process(_delta: float) -> void:
	if is_instance_valid(player) and rain:
		rain.global_position = player.global_position + Vector3.UP * 7.0

func _setup_atmosphere() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_material = ShaderMaterial.new()
	post_material.shader = load("res://scripts/atmosphere.gdshader")
	post_material.set_shader_parameter("grain_strength", 0.024)
	post_material.set_shader_parameter("color_steps", 64.0)
	post_material.set_shader_parameter("vignette_strength", 0.22)
	post_material.set_shader_parameter("pixel_scale", 0.75)
	rect.material = post_material
	layer.add_child(rect)

func toggle_nightmare() -> void:
	post_material.set_shader_parameter("nightmare", not bool(post_material.get_shader_parameter("nightmare")))

func _setup_rain() -> void:
	rain = GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 1400
	rain.lifetime = 1.1
	rain.preprocess = 1.1
	rain.visibility_aabb = AABB(Vector3(-20,-15,-20),Vector3(40,30,40))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(15.0, 0.2, 15.0)
	process.direction = Vector3(-0.12, -1.0, 0.04)
	process.spread = 3.0
	process.initial_velocity_min = 14.0
	process.initial_velocity_max = 19.0
	process.gravity = Vector3(-0.5, -9.0, 0.0)
	process.scale_min = 0.7
	process.scale_max = 1.3
	rain.process_material = process
	var drop := QuadMesh.new()
	drop.size = Vector2(0.008, 0.25)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.46, 0.52, 0.48, 0.18)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	drop.material = mat
	rain.draw_pass_1 = drop
	add_child(rain)
