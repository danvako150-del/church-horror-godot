extends SceneTree

var passed: Array[String] = []
var failed: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed.append(message)
	else:
		failed.append(message)
		push_error(message)

func run() -> void:
	var windows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/windows.json"))
	var by_id: Dictionary = {}
	var lit: int = 0
	var valid_shapes: bool = true
	var church_oriented: bool = true
	for w: Dictionary in windows:
		by_id[str(w.id)] = w
		if bool(w.lit):
			lit += 1
		var center := Vector3(w.center[0],w.center[1],w.center[2])
		var n := Vector3(w.normal[0],w.normal[1],w.normal[2])
		for point: Array in w.polygon:
			var position := Vector3(point[0],point[1],point[2])
			valid_shapes = valid_shapes and absf((position-center).dot(n)) < 0.002
		if "window_church" in str(w.material) or "art_glass_dark" in str(w.material):
			church_oriented = church_oriented and w.kind == "hall" and n.dot(center-Vector3(-43.18,center.y,0.0)) > 0.0
	check(windows.size() == 555 and by_id.size() == 555,"All 555 exterior windows have unique glass surfaces")
	check(lit == 162,"All 162 complete lit apertures retain their light state")
	check(valid_shapes,"Glass follows the original facade planes")
	check(church_oriented,"Church glazing faces outwards and uses hall interiors")
	var world: Node3D = load("res://scenes/church_world.tscn").instantiate()
	root.add_child(world)
	var container: Node3D = world.get_node("Windows")
	var count: int = 0
	var valid_materials: bool = true
	var valid_reflections: bool = true
	var triangles: int = 0
	for mesh: MeshInstance3D in container.get_children():
		count += int(mesh.get_meta("window_count"))
		valid_materials = valid_materials and mesh.material_override is ShaderMaterial and mesh.layers == 2
		var material: ShaderMaterial = mesh.material_override
		valid_reflections = valid_reflections and material.get_shader_parameter("has_reflection") == true and material.get_shader_parameter("exterior_reflection") is Cubemap
		for si in mesh.mesh.get_surface_count():
			triangles += mesh.mesh.surface_get_array_len(si)/3
	check(count == 555,"Saved scene contains every glass panel")
	check(container.get_child_count() < 70,"Windows are batched into fewer than 70 draw meshes")
	check(valid_materials,"Glass uses the interior/reflection shader on a separate visual layer")
	check(valid_reflections,"Both baked environment reflection maps are attached")
	check(triangles < 1700,"No room geometry is generated per apartment")
	check(container.find_children("*","CollisionObject3D",true,false).is_empty(),"Window interiors add no physics bodies")
	var associated: int = 0
	var spotlights: int = 0
	var correct_lights: bool = true
	var streetlights: int = 0
	for light: Light3D in world.get_node("Lights").get_children():
		if light.has_meta("window_id"):
			associated += 1
			var w: Dictionary = by_id[str(light.get_meta("window_id"))]
			var center := Vector3(w.center[0],w.center[1],w.center[2])
			var normal := Vector3(w.normal[0],w.normal[1],w.normal[2])
			correct_lights = correct_lights and absf((light.position-center).dot(normal)-0.12)<0.005 and light.light_cull_mask==1
			if light is SpotLight3D:
				spotlights += 1
				var direction: Vector3 = -light.basis.z
				correct_lights = correct_lights and direction.dot(normal)>.6 and direction.y<-.4 and light.spot_range<=8.0
			if light is OmniLight3D:
				correct_lights = correct_lights and light.omni_range<=1.8
		else:
			streetlights += 1
	check(associated == 296 and spotlights == 148,"Existing window lights are attached to their apertures")
	check(correct_lights,"Light spills outwards/downwards and lights the masonry without self-glare")
	check(streetlights == 12,"All 12 original street-light sources are preserved")
	var file := FileAccess.open("res://reports/windows_tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"window_triangles":triangles},"  "))
	file.close()
	print("WINDOW_TESTS passed=%d failed=%d triangles=%d" % [passed.size(),failed.size(),triangles])
	world.queue_free()
	for i in 3:
		await process_frame
	quit(0 if failed.is_empty() else 1)
