extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(5, 3, 5)
	world.add_child(camera)
	camera.look_at(Vector3(0, 0.8, 0))
	camera.current = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12,0.14,0.18)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.65
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-30,0)
	world.add_child(light)
	var model: Node3D = load("res://assets/models/models__dinus__fabia_mdl_skin0.gltf").instantiate()
	world.add_child(model)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	for mesh: MeshInstance3D in meshes:
		for si in mesh.mesh.get_surface_count():
			var a: Array = mesh.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			var positive: int = 0
			var negative: int = 0
			for i in range(0, indices.size(), 3):
				var x: int = indices[i]
				var y: int = indices[i+1]
				var z: int = indices[i+2]
				var d: float = (verts[y]-verts[x]).cross(verts[z]-verts[x]).dot(normals[x]+normals[y]+normals[z])
				if d > 0.00000001:
					positive += 1
				if d < -0.00000001:
					negative += 1
			print("GODOT_WINDING positive=", positive, " negative=",negative," verts=",verts.size()," indices=",indices.size())
	for mode in [0, 2]:
		for mesh: MeshInstance3D in meshes:
			for si in mesh.mesh.get_surface_count():
				var material: StandardMaterial3D = mesh.mesh.surface_get_material(si).duplicate()
				material.cull_mode = mode
				mesh.set_surface_override_material(si, material)
		for i in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/screenshots/fabia_cull_"+str(mode)+".png")
	world.queue_free()
	for i in 3:
		await process_frame
	quit()
