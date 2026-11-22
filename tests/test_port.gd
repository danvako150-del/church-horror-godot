extends SceneTree

const Stamina = preload("res://scripts/stamina.gd")
var failures: Array[String] = []
var results: Array[String] = []

func check(condition: bool, message: String) -> void:
	if condition:
		results.append(message)
	else:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	for hz: int in [30, 60, 100, 144]:
		var stamina = Stamina.new()
		var dt: float = 1.0 / float(hz)
		var frames: int = 0
		while not stamina.exhausted and frames < 10 * hz:
			stamina.step(dt, true)
			frames += 1
		check(stamina.power == 0.0 and stamina.exhausted and absf(frames * dt - 5.0) <= dt + 0.002, "Sprint empties in 5 seconds at %d Hz" % hz)
		stamina.step(2.5, false)
		check(is_equal_approx(stamina.power, 50.0) and stamina.exhausted, "Exhaustion remains locked during recovery at %d Hz" % hz)
		stamina.step(2.5, false)
		check(stamina.power == 100.0 and not stamina.exhausted, "Full recovery unlocks sprint at %d Hz" % hz)
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var player: CharacterBody3D = scene.player
	for i in 90:
		await physics_frame
	check(player.is_on_floor() and absf(player.position.y) < 0.1, "Source spawn lands on imported ground")
	check(scene.get_node("World/Props").get_child_count() == 45, "All 45 Source props present")
	check(scene.get_node("World/Lights").get_child_count() == 308, "All 308 Source lights present")
	# An unobstructed test lane in the actual imported courtyard.
	player.global_position = Vector3(-25.4, 0.1, -25.4)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	for i in 12:
		await physics_frame
	var start: Vector3 = player.global_position
	Input.action_press("move_back")
	for i in 60:
		await physics_frame
	Input.action_release("move_back")
	check(player.global_position.distance_to(start) > 2.5, "WASD moves player through imported scene")
	Input.action_press("crouch")
	for i in 10:
		await physics_frame
	check(player.crouched and player.collider.shape.height < 1.0, "Crouching reduces collision capsule")
	Input.action_release("crouch")
	for i in 10:
		await physics_frame
	check(not player.crouched and player.collider.shape.height > 1.7, "Standing restores collision capsule")
	var old_height: float = player.position.y
	Input.action_press("jump")
	for i in 10:
		await physics_frame
	Input.action_release("jump")
	check(player.position.y > old_height + 0.25, "Jump lifts player off imported ground")
	for i in 80:
		await physics_frame
	check(player.is_on_floor(), "Player lands after jumping")
	player.global_position.y = -20.0
	for i in 3:
		await physics_frame
	check(player.position.distance_to(player.respawn_position) < 0.5, "Out-of-bounds recovery returns to Source spawn")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	key.pressed = true
	player._unhandled_input(key)
	check(player.flashlight.visible, "F toggles native flashlight")
	key.physical_keycode = KEY_ESCAPE
	player._unhandled_input(key)
	check(paused and player.pause_panel.visible, "Escape pauses world and shows menu")
	player._unhandled_input(key)
	check(not paused and not player.pause_panel.visible, "Escape resumes world")
	var rays: int = 0
	for x: float in [-45.0, -25.0, 0.0, 25.0, 45.0]:
		for z: float in [-45.0, -25.0, 0.0, 25.0, 45.0]:
			var hit := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 40.0, z), Vector3(x, -4.0, z)))
			if not hit.is_empty():
				rays += 1
	check(rays >= 20, "Imported collision covers map sample grid (%d/25 hits)" % rays)
	# Integration: uninterrupted sprint, recovery, and idle Shift using the real player.
	var fixture := StaticBody3D.new()
	var fixture_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(160.0, 1.0, 20.0)
	fixture_shape.shape = box
	fixture.add_child(fixture_shape)
	fixture.position = Vector3(1000.0, -0.5, 0.0)
	root.add_child(fixture)
	player.global_position = Vector3(950.0, 0.1, 0.0)
	player.rotation.y = -PI * 0.5
	player.velocity = Vector3.ZERO
	player.stamina.power = 100.0
	player.stamina.exhausted = false
	for i in 15:
		await physics_frame
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var sprint_start: Vector3 = player.global_position
	for i in 305:
		await physics_frame
	check(player.stamina.exhausted and player.stamina.power < 3.0, "Integrated sprint exhausts after five seconds")
	check(player.global_position.distance_to(sprint_start) > 38.0, "Integrated sprint uses Source 320-unit speed")
	check(player.bar.visible, "Stamina HUD appears during exhaustion")
	Input.action_release("move_forward")
	for i in 310:
		await physics_frame
	check(player.stamina.power == 100.0 and not player.stamina.exhausted, "Integrated recovery returns to full after five seconds")
	for i in 60:
		await physics_frame
	check(player.stamina.power == 100.0 and not player.bar.visible, "Holding Shift while idle does not drain stamina")
	Input.action_release("sprint")
	fixture.queue_free()
	var summary := {"passed": results, "failed": failures, "engine": Engine.get_version_info().string}
	var file := FileAccess.open("res://reports/tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "  "))
	file.close()
	print("PORT_TESTS passed=%d failed=%d" % [results.size(), failures.size()])
	scene.queue_free()
	for i in 5:
		await process_frame
	quit(0 if failures.is_empty() else 1)
