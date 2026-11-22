extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node3D = load("res://scenes/church_world.tscn").instantiate()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.fov = 70.0
	world.add_child(camera)
	camera.current = true
	var beam := SpotLight3D.new()
	beam.light_energy = 4.0
	beam.spot_range = 30.0
	beam.spot_angle = 38.0
	beam.light_color = Color(1.0,0.94,0.82)
	beam.shadow_enabled = true
	camera.add_child(beam)
	DirAccess.make_dir_recursive_absolute("res://reports/screenshots/church_doors")
	var views: Array[Dictionary] = [
		{"name":"south_wall","position":Vector3(-43.18,1.7,39),"target":Vector3(-43.18,3.3,26.67)},
		{"name":"cemetery_front","position":Vector3(-43.18,1.7,-34.5),"target":Vector3(-43.18,4.0,-26.67)},
		{"name":"cemetery_left_seam","position":Vector3(-39.8,1.7,-29.0),"target":Vector3(-42.0,2.3,-26.75)},
		{"name":"cemetery_right_seam","position":Vector3(-46.6,1.7,-29.0),"target":Vector3(-44.5,2.3,-26.75)},
		{"name":"cemetery_threshold","position":Vector3(-43.18,1.7,-30.5),"target":Vector3(-43.18,0.5,-26.9)}
	]
	for v: Dictionary in views:
		camera.position = v.position
		camera.look_at(v.target)
		for i in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/screenshots/church_doors/"+str(v.name)+".png")
	print("CHURCH_DOOR_REVIEW_CAPTURED 5 views")
	world.queue_free()
	for i in 4:
		await process_frame
	quit()
