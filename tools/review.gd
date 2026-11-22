extends SceneTree

func _initialize() -> void:
	call_deferred("review")

func review() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 45:
		await process_frame
	var player: CharacterBody3D = scene.player
	player.set_physics_process(false)
	print("REVIEW spawn=", player.global_position, " grounded=", player.is_on_floor(), " meshes=", get_nodes_in_group("player").size())
	DirAccess.make_dir_recursive_absolute("res://reports/screenshots")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/screenshots/spawn.png")
	player.global_position = Vector3(12.7, 0.1, -10.16)
	player.velocity = Vector3.ZERO
	player.rotation.y = deg_to_rad(55.0)
	player.camera.rotation.x = deg_to_rad(-10.0)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/screenshots/church.png")
	player.flashlight.visible = true
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/screenshots/flashlight.png")
	player.flashlight.visible = false
	player.global_position = Vector3(-14.732, 1.1684, -31.75)
	player.rotation.y = deg_to_rad(130.0)
	player.camera.rotation.x = deg_to_rad(8.0)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/screenshots/church_front.png")
	player.global_position = Vector3(25.0, -0.202, -20.0)
	player.rotation.y = 0.0
	player.camera.rotation.x = deg_to_rad(-2.0)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/screenshots/street_retro.png")
	player.flashlight.visible = true
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/screenshots/street_flashlight_retro.png")
	print("REVIEW_CAPTURED")
	scene.queue_free()
	for i in 5:
		await process_frame
	quit()
