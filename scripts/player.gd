extends CharacterBody3D

const Stamina = preload("res://scripts/stamina.gd")
const WALK_SPEED: float = 4.826
const RUN_SPEED: float = 8.128
const CROUCH_SPEED: float = 1.6087
const JUMP_SPEED: float = 4.064
const STAND_HEIGHT: float = 1.80
const CROUCH_HEIGHT: float = 0.92
var stamina = Stamina.new()
var camera: Camera3D
var flashlight: SpotLight3D
var collider: CollisionShape3D
var headbob: bool = true
var crouched: bool = false
var sprinting: bool = false
var bob_phase: float = 0.0
var bob_amplitude: float = 0.0
var step_distance: float = 0.0
var footsteps: AudioStreamPlayer3D
var footstep_sets: Dictionary = {}
var respawn_position: Vector3
var respawn_yaw: float
var paused: bool = false
var hints: Label
var bar: ProgressBar
var pause_panel: PanelContainer
var last_physics_us: int = 0
var last_collision_us: int = 0
var fps_label: Label
var hint_time: float = 0.0
var fps_time: float = 0.0

func _exit_tree() -> void:
	if is_instance_valid(footsteps):
		footsteps.stop()
		footsteps.stream = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "Player"
	add_to_group("player")
	floor_snap_length = 0.30
	floor_max_angle = deg_to_rad(48.0)
	wall_min_slide_angle = deg_to_rad(15.0)
	collider = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = STAND_HEIGHT
	collider.shape = capsule
	collider.position.y = STAND_HEIGHT * 0.5
	add_child(collider)
	camera = Camera3D.new()
	camera.position.y = 1.6256
	camera.fov = 80.0
	camera.near = 0.05
	camera.far = 220.0
	add_child(camera)
	camera.current = true
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.14, -0.13, -0.12)
	flashlight.light_color = Color(1.0, 0.94, 0.82)
	flashlight.light_energy = 3.5
	flashlight.spot_range = 24.0
	flashlight.spot_angle = 29.0
	flashlight.spot_angle_attenuation = 0.7
	flashlight.shadow_enabled = true
	flashlight.visible = false
	camera.add_child(flashlight)
	footsteps = AudioStreamPlayer3D.new()
	footsteps.volume_db = -9.0
	add_child(footsteps)
	for kind in ["concrete", "dirt", "grass", "metal"]:
		var streams: Array[AudioStream] = []
		for i in range(1, 5):
			var file: String = "res://assets/audio/player/footsteps/%s%d.wav" % [kind, i]
			if ResourceLoader.exists(file):
				streams.append(load(file))
		footstep_sets[kind] = streams
	respawn_position = position
	respawn_yaw = rotation.y
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				paused = not paused
				get_tree().paused = paused
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
				pause_panel.visible = paused
			KEY_F:
				if not paused:
					flashlight.visible = not flashlight.visible
			KEY_B:
				headbob = not headbob
			KEY_N:
				get_tree().call_group("atmosphere", "toggle_nightmare")
			KEY_R:
				if paused:
					respawn()
			KEY_F11:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_F3:
				fps_label.visible = not fps_label.visible
			KEY_Q:
				if paused:
					get_tree().quit()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.0022)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.0022, -1.48, 1.48)

func _process(delta: float) -> void:
	if not paused:
		hint_time += delta
		hints.modulate.a = clampf(9.0 - hint_time, 0.0, 0.75)
	fps_time += delta
	if fps_label.visible and fps_time > 0.25:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
		fps_time = 0.0

func _physics_process(delta: float) -> void:
	if paused:
		return
	var physics_started: int = Time.get_ticks_usec()
	var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var desired_crouch: bool = Input.is_action_pressed("crouch")
	if not desired_crouch and crouched:
		var query := PhysicsShapeQueryParameters3D.new()
		var stand_shape := CapsuleShape3D.new()
		stand_shape.radius = 0.38
		stand_shape.height = STAND_HEIGHT
		query.shape = stand_shape
		query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * (STAND_HEIGHT / 2.0 + 0.02))
		query.exclude = [get_rid()]
		desired_crouch = not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
	crouched = desired_crouch
	var height: float = CROUCH_HEIGHT if crouched else STAND_HEIGHT
	# Re-registering a capsule with the physics server every tick invalidates
	# contact caches, especially expensive next to detailed static geometry.
	if not is_equal_approx(collider.shape.height, height):
		collider.shape.height = height
		collider.position.y = height * 0.5
	var direction: Vector3 = (basis * Vector3(axis.x, 0.0, axis.y)).normalized()
	sprinting = Input.is_action_pressed("sprint") and not crouched and not stamina.exhausted and stamina.power > 0.0 and axis.length_squared() > 0.0
	var speed: float = CROUCH_SPEED if crouched else (RUN_SPEED if sprinting else WALK_SPEED)
	var accel: float = 36.0 if is_on_floor() else 8.0
	velocity.x = move_toward(velocity.x, direction.x * speed, accel * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, accel * delta)
	if not is_on_floor():
		velocity.y -= 15.24 * delta
	elif Input.is_action_just_pressed("jump") and not crouched:
		velocity.y = JUMP_SPEED
	var old_position: Vector3 = position
	_move_with_step(delta)
	var travel: float = Vector2(position.x - old_position.x, position.z - old_position.z).length()
	var moving: bool = is_on_floor() and travel / maxf(delta, 0.001) > 0.508
	stamina.step(delta, sprinting and moving)
	if stamina.exhausted:
		sprinting = false
	var target: float = (0.019 if sprinting else 0.009) if moving and headbob else 0.0
	bob_amplitude = move_toward(bob_amplitude, target, delta * 0.064)
	if moving:
		bob_phase = fmod(bob_phase + delta * (2.3 if sprinting else 1.6) * TAU, TAU)
		step_distance += travel
		if step_distance > (1.55 if sprinting else 1.05):
			step_distance = 0.0
			_play_footstep()
	var eye_height: float = 0.78 if crouched else 1.6256
	camera.position.y = move_toward(camera.position.y, eye_height + sin(bob_phase * 2.0) * bob_amplitude, delta * 4.0)
	camera.position.x = cos(bob_phase) * bob_amplitude * 0.4
	camera.rotation.z = sin(bob_phase) * bob_amplitude * 0.22
	bar.value = stamina.power
	bar.visible = stamina.power < 99.95 or (sprinting and moving)
	bar.modulate = Color(0.78, 0.48, 0.32) if stamina.exhausted else Color(0.80, 0.86, 0.80)
	if position.y < -15.0:
		respawn()
	last_physics_us = Time.get_ticks_usec() - physics_started

func _move_with_step(delta: float) -> void:
	var collision_started: int = Time.get_ticks_usec()
	# Source-sized stair step: climb small curbs without jumping, check head clearance.
	var horizontal := Vector3(velocity.x, 0.0, velocity.z) * delta
	if is_on_floor() and velocity.y <= 0.0 and horizontal.length_squared() > 0.000001 and test_move(global_transform, horizontal):
		var raised: Transform3D = global_transform.translated(Vector3.UP * 0.46)
		if not test_move(global_transform, Vector3.UP * 0.46) and not test_move(raised, horizontal):
			var landing := KinematicCollision3D.new()
			if test_move(raised.translated(horizontal), Vector3.DOWN * 0.50, landing) and landing.get_normal().y > 0.7:
				global_position.y += 0.46 + landing.get_travel().y
	move_and_slide()
	last_collision_us = Time.get_ticks_usec() - collision_started

func _play_footstep() -> void:
	var from: Vector3 = global_position + Vector3.UP * 0.25
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.8)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var kind: String = "concrete"
	if not hit.is_empty():
		kind = str(hit.collider.get_meta("footstep", "concrete"))
	var streams: Array = footstep_sets.get(kind, [])
	if not streams.is_empty():
		footsteps.stream = streams.pick_random()
		footsteps.pitch_scale = randf_range(0.94, 1.06)
		if DisplayServer.get_name() != "headless":
			footsteps.play()

func respawn() -> void:
	global_position = respawn_position
	rotation.y = respawn_yaw
	velocity = Vector3.ZERO
	stamina.power = 100.0
	stamina.exhausted = false

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	bar = ProgressBar.new()
	bar.position = Vector2(24, 642)
	bar.size = Vector2(204, 7)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.visible = false
	layer.add_child(bar)
	hints = Label.new()
	hints.text = "WASD  движение   Shift  бег   F  фонарь   Ctrl  присесть   Esc  пауза"
	hints.position = Vector2(24, 680)
	hints.add_theme_font_size_override("font_size", 14)
	hints.modulate = Color(0.65, 0.69, 0.72, 0.75)
	layer.add_child(hints)
	fps_label = Label.new()
	fps_label.position = Vector2(1160, 20)
	fps_label.add_theme_font_size_override("font_size", 14)
	fps_label.modulate = Color(0.69, 0.73, 0.60)
	fps_label.visible = false
	layer.add_child(fps_label)
	pause_panel = PanelContainer.new()
	pause_panel.position = Vector2(370, 220)
	pause_panel.size = Vector2(540, 260)
	pause_panel.visible = false
	var label := Label.new()
	label.text = "ЦЕРКОВЬ\n\nEsc — продолжить    Q — выйти\nR — вернуться к началу\nB — покачивание камеры\nN — режим кошмара\nF3 — FPS    F11 — полный экран"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 21)
	pause_panel.add_child(label)
	layer.add_child(pause_panel)
