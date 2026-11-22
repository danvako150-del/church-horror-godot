extends SceneTree

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var world: Node3D = load("res://scenes/church_world.tscn").instantiate()
	root.add_child(world)
	for mesh: MeshInstance3D in world.get_node("Windows").get_children():
		mesh.material_override.set_shader_parameter("has_reflection",false)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.world_3d = world.get_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.fov = 90.0
	camera.near = 0.12
	camera.far = 200.0
	viewport.add_child(camera)
	camera.current = true
	var directions: Array[Vector3] = [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]
	DirAccess.make_dir_recursive_absolute("res://assets/windows")
	for name: String in ["courtyard","street"]:
		camera.position = Vector3(-28.0,2.5,0.0) if name == "courtyard" else Vector3(25.0,2.5,0.0)
		var images: Array[Image] = []
		for direction: Vector3 in directions:
			camera.look_at(camera.position+direction,Vector3.FORWARD if absf(direction.y)>.99 else Vector3.UP)
			for i in 8:
				await process_frame
			await RenderingServer.frame_post_draw
			var image: Image = viewport.get_texture().get_image()
			if image.get_width() != 256 or image.get_height() != 256:
				push_error("Reflection face is not square: "+str(image.get_size()))
				quit(1)
				return
			image.convert(Image.FORMAT_RGB8)
			image.generate_mipmaps()
			images.append(image)
		var cube := Cubemap.new()
		var error: Error = cube.create_from_images(images)
		if error != OK:
			push_error("Cubemap creation failed: "+str(error))
			quit(1)
			return
		ResourceSaver.save(cube,"res://assets/windows/reflection_"+name+".res")
		print("WINDOW_REFLECTION_BAKED ",name)
	world.queue_free()
	viewport.queue_free()
	for i in 4:
		await process_frame
	quit()
