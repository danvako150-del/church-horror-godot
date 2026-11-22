extends SceneTree

var tag: String = "before"
var retro: bool = false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
		if arg == "--retro":
			retro = true
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var world: Node3D = load("res://scenes/church_world.tscn").instantiate()
	root.add_child(world)
	if retro:
		var canvas := CanvasLayer.new()
		canvas.layer = -1
		root.add_child(canvas)
		var rect := ColorRect.new()
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var material := ShaderMaterial.new()
		material.shader = load("res://scripts/atmosphere.gdshader")
		rect.material = material
		canvas.add_child(rect)
	var camera := Camera3D.new()
	camera.fov = 65
	world.add_child(camera)
	camera.current = true
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var views: Array[Dictionary] = [
		{"name":"street", "position":Vector3(37.5, 1.65, -24.5), "target":Vector3(45.77,12.0,-24.5)},
		{"name":"front", "position":Vector3(36.0, 7.65, -22.45), "target":Vector3(45.77,7.65,-22.45)},
		{"name":"angle", "position":Vector3(41.0, 6.2, -17.5), "target":Vector3(45.77,7.65,-22.45)},
		{"name":"warm", "position":Vector3(37.0, 7.65, 12.5), "target":Vector3(45.77,7.65,9.04)},
		{"name":"dark", "position":Vector3(37.5, 8.5, -35.0), "target":Vector3(45.77,11.7,-35.0)}
	]
	DirAccess.make_dir_recursive_absolute("res://reports/screenshots/windows")
	var timings: Array[Dictionary] = []
	for v: Dictionary in views:
		camera.global_position = v.position
		camera.look_at(v.target)
		for i in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/screenshots/windows/" + tag + "_" + str(v.name) + ".png")
		var gpu: float = 0.0
		var began: int = Time.get_ticks_usec()
		for i in 40:
			await process_frame
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		timings.append({"view":v.name,"gpu_mean_ms":gpu/40.0,"wall_mean_ms":float(Time.get_ticks_usec()-began)/40000.0})
	var file := FileAccess.open("res://reports/windows_perf_"+tag+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(timings,"  "))
	file.close()
	print("WINDOW_REVIEW ", tag, " ", JSON.stringify(timings))
	world.queue_free()
	for i in 4:
		await process_frame
	quit()
