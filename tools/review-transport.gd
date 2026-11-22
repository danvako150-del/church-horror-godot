extends SceneTree

func _initialize() -> void:
	call_deferred("review")

func review() -> void:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.player.set_process_unhandled_input(false)
	scene.player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for child: Node in scene.player.get_children():
		if child is CanvasLayer:
			child.hide()
	var camera := Camera3D.new()
	camera.fov = 65.0
	scene.add_child(camera)
	camera.current = true
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.65
	fill.rotation_degrees = Vector3(-40, -30, 0)
	scene.add_child(fill)
	DirAccess.make_dir_recursive_absolute("res://reports/screenshots/transport_fixed")
	var ids: Array[String] = ["22110", "22111", "22112", "22113", "22114", "22115", "22106", "22107", "22108", "22109", "22116", "22117"]
	for id: String in ids:
		var pivot: Node3D = scene.get_node("World/Props/Prop_" + id)
		var size: float = 11.0 if id in ["22112", "22113"] else 6.5
		var source: String = str(pivot.get_meta("source_model"))
		if id in ["22114", "22115"]:
			size = 8.5
		var side := Vector3(1.0, 0.34, 1.0).normalized() * size
		if "mercedes" in source or "minivan" in source or "church_" in source:
			side.z *= -1.0
		var target := pivot.global_position + Vector3.UP * (1.4 if size > 8 else 0.8)
		var excluded: Array[RID] = []
		for body: StaticBody3D in pivot.find_children("*", "StaticBody3D", true, false):
			excluded.append(body.get_rid())
		var best_score: float = -INF
		var best_position: Vector3 = target
		for angle: float in [0.0, 45.0, -45.0, 90.0, -90.0, 135.0, -135.0, 180.0]:
			var offset: Vector3 = pivot.basis.orthonormalized() * side.rotated(Vector3.UP, deg_to_rad(angle))
			var candidate: Vector3 = pivot.global_position + offset
			var query := PhysicsRayQueryParameters3D.create(target, candidate)
			query.exclude = excluded
			var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
			var available: float = target.distance_to(candidate) if hit.is_empty() else maxf(0.0, target.distance_to(hit.position) - 0.4)
			if available > best_score:
				best_score = available
				best_position = target + (candidate - target).normalized() * available
		camera.global_position = best_position
		camera.look_at(target)
		for i in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/screenshots/transport_fixed/vehicle_" + id + ".png")
	print("TRANSPORT_REVIEW_CAPTURED 12 vehicles")
	scene.queue_free()
	for i in 5:
		await process_frame
	quit()
