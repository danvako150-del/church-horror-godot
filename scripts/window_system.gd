extends RefCounted

static func build(scene_root: Node3D, windows: Array) -> Dictionary:
	var container := Node3D.new()
	container.name = "Windows"
	scene_root.add_child(container)
	container.owner = scene_root
	var materials: Dictionary = {}
	for probe: String in ["courtyard", "street"]:
		var material := ShaderMaterial.new()
		material.shader = load("res://scripts/window_glass.gdshader")
		var path: String = "res://assets/windows/reflection_" + probe + ".res"
		if FileAccess.file_exists(path):
			material.set_shader_parameter("exterior_reflection", load(path))
			material.set_shader_parameter("has_reflection", true)
		else:
			material.set_shader_parameter("has_reflection", false)
		materials[probe] = material
	var batches: Dictionary = {}
	var by_id: Dictionary = {}
	for w: Dictionary in windows:
		by_id[str(w.id)] = w
		var center := Vector3(w.center[0],w.center[1],w.center[2])
		var n := Vector3(w.normal[0],w.normal[1],w.normal[2])
		var right := Vector3(w.right[0],w.right[1],w.right[2])
		var probe: String = "street" if center.x > 8.0 else "courtyard"
		var key: String = "%s_%d_%d" % [probe,floori(center.x/16.0),floori(center.z/16.0)]
		if not batches.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			batches[key] = {"tool":tool,"probe":probe,"count":0}
		var tool: SurfaceTool = batches[key].tool
		var polygon: Array = w.polygon
		for triangle in range(1,polygon.size()-1):
			for index: int in [0,triangle+1,triangle]:
				var p: Array = polygon[index]
				var point := Vector3(p[0],p[1],p[2])
				var uv := Vector2((point-center).dot(right)/float(w.width)+0.5,(point.y-center.y)/float(w.height)+0.5)
				tool.set_normal(n)
				tool.set_tangent(Plane(right,1.0))
				tool.set_uv(uv)
				tool.set_uv2(Vector2(float(w.seed)+(2.0 if w.get("kind","")=="hall" else 0.0),float(w.width)/float(w.height)))
				tool.set_color(Color(w.tint[0],w.tint[1],w.tint[2],w.strength))
				tool.add_vertex(point+n*0.003)
		batches[key].count += 1
	for key: String in batches:
		var batch: Dictionary = batches[key]
		var mesh := MeshInstance3D.new()
		mesh.name = "Glass_" + key
		mesh.mesh = batch.tool.commit()
		mesh.material_override = materials[batch.probe]
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.layers = 2
		mesh.set_meta("window_count",int(batch.count))
		container.add_child(mesh)
		mesh.owner = scene_root
	container.set_meta("window_count",windows.size())
	container.set_meta("draw_batches",batches.size())
	return by_id

static func tune_light(light: Light3D, entity: Dictionary, by_id: Dictionary) -> bool:
	var id: String = str(entity.get("window_id",""))
	if not by_id.has(id):
		return false
	var w: Dictionary = by_id[id]
	var center := Vector3(w.center[0],w.center[1],w.center[2])
	var normal := Vector3(w.normal[0],w.normal[1],w.normal[2])
	light.position = center+normal*0.12-Vector3.UP*float(w.height)*0.25
	light.light_color = Color(w.tint[0],w.tint[1],w.tint[2])
	light.shadow_enabled = false
	# Exterior spill lights illuminate real masonry/reveals, not their own glass.
	light.light_cull_mask = 1
	if light is OmniLight3D:
		light.omni_range = minf(1.8,float(w.width)*0.8)
		light.omni_attenuation = 2.2
		light.light_energy = 0.25*float(w.strength)
	if light is SpotLight3D:
		light.spot_range = clampf(float(w.height)*2.2,4.0,8.0)
		light.spot_angle = 52.0
		light.spot_angle_attenuation = 1.25
		light.spot_attenuation = 2.0
		light.light_energy = 1.4*float(w.strength)
		light.look_at(light.global_position+(normal*0.72+Vector3.DOWN*0.69).normalized(),Vector3.UP)
	light.set_meta("window_id",id)
	return true
