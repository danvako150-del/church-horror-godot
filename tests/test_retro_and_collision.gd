extends SceneTree

var passed: Array[String] = []
var failed: Array[String] = []
var shape_changes: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed.append(message)
	else:
		failed.append(message)
		push_error(message)

func run() -> void:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 20:
		await physics_frame
	for pivot: Node3D in scene.get_node("World/Props").get_children():
		if not pivot.has_node("VehicleHull"):
			continue
		var body: StaticBody3D = pivot.get_node("VehicleHull")
		var shape: CollisionShape3D = body.get_node("Hull")
		check(body.get_child_count() == 1 and shape.shape is ConvexPolygonShape3D and shape.shape.points.size() <= 32, "One bounded convex proxy: " + str(pivot.name))
	scene.player.collider.shape.changed.connect(func(): shape_changes += 1)
	for i in 30:
		await physics_frame
	check(shape_changes == 0, "Standing capsule is not re-registered every physics tick")
	Input.action_press("crouch")
	for i in 5:
		await physics_frame
	print("SHAPE_CHANGES crouch=", shape_changes)
	# CapsuleShape3D emits two changed signals for one height assignment.
	check(shape_changes == 2, "Capsule is updated only on entering crouch")
	Input.action_release("crouch")
	for i in 5:
		await physics_frame
	print("SHAPE_CHANGES standing=", shape_changes)
	check(shape_changes == 4, "Capsule is updated only on standing up")
	check(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")) == 0 and not bool(ProjectSettings.get_setting("rendering/anti_aliasing/quality/use_taa")), "MSAA and TAA disabled")
	check(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa")) == 0, "No screen-space antialiasing")
	var material_count: int = 0
	var sharp: bool = true
	var textures_small: bool = true
	for mesh: MeshInstance3D in scene.get_node("World").find_children("*", "MeshInstance3D", true, false):
		for si in mesh.mesh.get_surface_count():
			var mat: Material = mesh.get_active_material(si)
			if mat is StandardMaterial3D:
				material_count += 1
				sharp = sharp and mat.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS and mat.metallic_specular == 0.0
				if mat.albedo_texture:
					textures_small = textures_small and mat.albedo_texture.get_width() <= 256 and mat.albedo_texture.get_height() <= 256
	print("RETRO_MATERIALS count=", material_count, " sharp=", sharp)
	check(material_count > 100 and sharp, "Scene uses sharp mipmapped matte materials")
	check(textures_small, "Imported scene textures limited to 256 pixels")
	var environment: Environment = scene.get_node("World/NightEnvironment").environment
	check(environment.ambient_light_energy <= 0.25 and environment.tonemap_mode == Environment.TONE_MAPPER_LINEAR, "Dark linear retro lighting")
	check(scene.post_material.shader != null and float(scene.post_material.get_shader_parameter("color_steps")) == 64.0, "Retro quantisation post-process attached")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_F3
	scene.player._unhandled_input(key)
	check(scene.player.fps_label.visible, "F3 toggles FPS display")
	var file := FileAccess.open("res://reports/retro_collision_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "failed": failed}, "  "))
	file.close()
	print("RETRO_COLLISION_TESTS passed=%d failed=%d" % [passed.size(), failed.size()])
	scene.queue_free()
	for i in 4:
		await process_frame
	quit(0 if failed.is_empty() else 1)
