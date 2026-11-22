extends SceneTree

var passed: Array[String] = []
var failed: Array[String] = []

func check(ok: bool, message: String) -> void:
	if ok:
		passed.append(message)
	else:
		failed.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var conversion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://reports/conversion.json"))
	for model: Dictionary in conversion.models:
		var instance: Node3D = load("res://" + str(model.path)).instantiate()
		var positive: int = 0
		var negative: int = 0
		for mesh: MeshInstance3D in instance.find_children("*", "MeshInstance3D", true, false):
			for si in mesh.mesh.get_surface_count():
				var a: Array = mesh.mesh.surface_get_arrays(si)
				var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
				var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
				for i in range(0, indices.size(), 3):
					var x: int = indices[i]
					var y: int = indices[i+1]
					var z: int = indices[i+2]
					var d: float = (verts[y]-verts[x]).cross(verts[z]-verts[x]).dot(normals[x]+normals[y]+normals[z])
					if d > 0.00000001:
						positive += 1
					if d < -0.00000001:
						negative += 1
		# Godot uses clockwise front faces, opposite the glTF input convention.
		check(float(negative) / maxf(1.0, float(negative + positive)) > 0.95, "Imported outward-facing mesh: " + str(model.source))
		instance.free()
	var world: Node3D = load("res://scenes/church_world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await process_frame
	var excluded: Array[RID] = []
	for body: StaticBody3D in world.get_node("Props").find_children("*", "StaticBody3D", true, false):
		excluded.append(body.get_rid())
	var level: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/level.json"))
	for p: Dictionary in level.props:
		if not p.has("wheel_contacts"):
			continue
		var pivot: Node3D = world.get_node("Props/Prop_" + str(p.id))
		var grounded: bool = true
		for c: Array in p.wheel_contacts:
			var point: Vector3 = pivot.to_global(Vector3(c[0], c[1], c[2]))
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point + Vector3.DOWN)
			query.exclude = excluded
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or absf(point.y - float(hit.position.y)) > 0.025:
				grounded = false
		check(grounded, "Saved scene has four grounded wheels: " + str(p.id))
	var file := FileAccess.open("res://reports/transport_runtime_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "failed": failed}, "  "))
	file.close()
	print("TRANSPORT_RUNTIME passed=%d failed=%d" % [passed.size(), failed.size()])
	world.queue_free()
	for i in 3:
		await process_frame
	quit(0 if failed.is_empty() else 1)
