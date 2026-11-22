extends SceneTree

var output: String = "res://reports/perf_before.json"
var samples: Array[Dictionary] = []
var scene: Node3D
var all_vehicles: bool = false
var flashlight_on: bool = false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = "res://reports/" + arg.trim_prefix("--output=")
		if arg == "--all":
			all_vehicles = true
		if arg == "--flashlight":
			flashlight_on = true
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.player.set_process_unhandled_input(false)
	scene.player.flashlight.visible = flashlight_on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	root.set_disable_3d(false)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for i in 15:
		await process_frame
	await sample("spawn_idle", 40)
	var ids: Array[String] = ["22110", "22111", "22114", "22113"]
	if all_vehicles:
		ids.clear()
		var level: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/level.json"))
		for p: Dictionary in level.props:
			if p.has("wheel_contacts"):
				ids.append(str(p.id))
	for id: String in ids:
		var pivot: Node3D = scene.get_node("World/Props/Prop_" + id)
		var box := AABB()
		var first: bool = true
		for mesh: MeshInstance3D in pivot.get_node("Model").find_children("*", "MeshInstance3D", true, false):
			var local_box: AABB = pivot.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			box = local_box if first else box.merge(local_box)
			first = false
		var side := Vector3.RIGHT if box.size.z > box.size.x else Vector3.BACK
		var center: Vector3 = box.get_center()
		center.y = 0.0
		var half_width: float = (box.size.x if side == Vector3.RIGHT else box.size.z) * 0.5
		var outward: Vector3 = pivot.basis.orthonormalized() * side
		var location: Vector3 = pivot.to_global(center) + outward * (half_width + 1.2)
		location.y = pivot.position.y + 0.12
		scene.player.global_position = location
		scene.player.rotation.y = atan2(outward.x, outward.z)
		scene.player.velocity = Vector3.ZERO
		Input.action_press("move_forward")
		for i in 24:
			await physics_frame
		await sample("touch_" + id, 40)
		Input.action_release("move_forward")
		print("PROFILE case=", id, " position=", scene.player.global_position)
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(), "samples": samples}, "  "))
	file.close()
	print("PROFILE_SAVED ", output)
	scene.queue_free()
	for i in 4:
		await process_frame
	quit()

func sample(label: String, frames: int) -> void:
	var physics: Array[float] = []
	var process: Array[float] = []
	var gpu: Array[float] = []
	var wall: Array[float] = []
	var controller: Array[float] = []
	var collision: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	for i in frames:
		await process_frame
		var now: int = Time.get_ticks_usec()
		wall.append(float(now - previous) / 1000.0)
		previous = now
		physics.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
		process.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		controller.append(float(scene.player.last_physics_us) / 1000.0)
		collision.append(float(scene.player.last_collision_us) / 1000.0)
	physics.sort()
	wall.sort()
	controller.sort()
	collision.sort()
	var row := {"case": label, "controller_median_ms": controller[frames/2], "collision_median_ms": collision[frames/2], "controller_p95_ms": controller[int(frames*0.95)], "process_mean_ms": mean(process), "gpu_mean_ms": mean(gpu), "wall_median_ms": wall[frames/2], "wall_p95_ms": wall[int(frames*0.95)]}
	samples.append(row)
	print(JSON.stringify(row))

func mean(values: Array[float]) -> float:
	var sum: float = 0.0
	for v: float in values:
		sum += v
	return sum / maxf(1.0, float(values.size()))
