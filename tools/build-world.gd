extends SceneTree
const WindowSystem = preload("res://scripts/window_system.gd")

const UNIT: float = 0.0254
var world_root: Node3D
var light_count: int = 0
var vehicle_placements: Array[Dictionary] = []
var vehicle_collision_report: Array[Dictionary] = []

func own(node: Node, parent: Node) -> void:
	parent.add_child(node)
	node.owner = world_root
	for child in node.get_children():
		_own_recursive(child)

func _own_recursive(node: Node) -> void:
	node.owner = world_root
	for child in node.get_children():
		_own_recursive(child)

func vec(text: String) -> Vector3:
	var n := text.split(" ", false)
	return Vector3(float(n[0]), float(n[2]), -float(n[1])) * UNIT if n.size() >= 3 else Vector3.ZERO

func _initialize() -> void:
	call_deferred("build")

func build() -> void:
	var level: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/level.json"))
	world_root = Node3D.new()
	world_root.name = "ChurchV29"
	get_root().add_child(world_root)
	var geometry: Node3D = load("res://assets/map/church.gltf").instantiate()
	geometry.name = "Architecture"
	world_root.add_child(geometry)
	geometry.owner = world_root
	world_root.set_editable_instance(geometry, true)
	var window_records: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/windows.json"))
	var windows_by_id: Dictionary = WindowSystem.build(world_root, window_records)
	var tuned_window_lights: int = 0
	# Preserve imported scene as an editable scene instance.
	for kind: String in level.collision_kinds:
		var shell := StaticBody3D.new()
		shell.name = "MapCollision_" + kind
		shell.set_meta("footstep", kind)
		own(shell, world_root)
		var data := FileAccess.get_file_as_bytes("res://assets/map/collision_" + kind + ".bin").to_float32_array()
		var vertices := PackedVector3Array()
		vertices.resize(data.size() / 3)
		for i in vertices.size():
			vertices[i] = Vector3(data[i * 3], data[i * 3 + 1], data[i * 3 + 2])
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(vertices)
		shape.backface_collision = true
		var shape_path: String = "res://assets/map/collision_" + kind + ".res"
		ResourceSaver.save(shape, shape_path)
		var collision := CollisionShape3D.new()
		collision.shape = load(shape_path)
		own(collision, shell)
	var props := Node3D.new()
	if level.has("church_doors"):
		var body := StaticBody3D.new()
		body.name = "ChurchEntranceRamp"
		body.set_meta("footstep","concrete")
		own(body,world_root)
		var points := PackedVector3Array()
		for point: Array in level.church_doors.ramp_source_vertices:
			points.append(Vector3(point[0],point[2],-point[1])*UNIT)
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		var collider := CollisionShape3D.new()
		collider.shape = shape
		own(collider,body)
	props.name = "Props"
	own(props, world_root)
	# Query architecture before inserting any prop colliders, so neighboring cars
	# cannot become the ground for another vehicle.
	await physics_frame
	await process_frame
	var placements: Dictionary = {}
	for p: Dictionary in level.props:
		if p.has("wheel_contacts"):
			placements[str(p.id)] = _ground_vehicle(p)
	for p: Dictionary in level.props:
		var pivot := Node3D.new()
		pivot.name = "Prop_" + str(p.id)
		pivot.position = Vector3(p.origin[0], p.origin[1], p.origin[2])
		var a: Array = p.angles
		pivot.basis = Basis(Vector3.UP, deg_to_rad(float(a[1]))) * Basis(Vector3.FORWARD, deg_to_rad(float(a[0]))) * Basis(Vector3.RIGHT, deg_to_rad(float(a[2])))
		pivot.scale *= float(p.scale)
		if placements.has(str(p.id)):
			pivot.transform = placements[str(p.id)]
		pivot.set_meta("source_model", p.source)
		own(pivot, props)
		var model: Node3D = load("res://" + p.path).instantiate()
		model.name = "Model"
		pivot.add_child(model)
		model.owner = world_root
		world_root.set_editable_instance(model, true)
		if str(p.solid) == "0":
			continue
		if "pg_tree" in str(p.source):
			var body := StaticBody3D.new()
			body.set_meta("footstep", "grass")
			own(body, pivot)
			var trunk := CollisionShape3D.new()
			var cylinder := CylinderShape3D.new()
			cylinder.radius = 0.26
			cylinder.height = 4.0
			trunk.shape = cylinder
			trunk.position.y = 2.0
			own(trunk, body)
		elif p.has("wheel_contacts"):
			_vehicle_collision(model, pivot, p)
		else:
			_model_collision(model, pivot)
	var lights := Node3D.new()
	lights.name = "Lights"
	own(lights, world_root)
	for e: Dictionary in level.entities:
		var cls: String = e.get("classname", "")
		if cls != "light" and cls != "light_spot":
			continue
		var light: OmniLight3D = OmniLight3D.new() if cls == "light" else null
		var spot: SpotLight3D = SpotLight3D.new() if cls == "light_spot" else null
		var node: Light3D = light if light else spot
		node.name = "SourceLight_" + str(e.id)
		node.position = vec(e.get("origin", "0 0 0"))
		var rgb: PackedStringArray = str(e.get("_light", "255 220 180 100")).split(" ", false)
		node.light_color = Color(float(rgb[0]) / 255.0, float(rgb[1]) / 255.0, float(rgb[2]) / 255.0)
		var energy: float = float(rgb[3]) if rgb.size() > 3 else 100.0
		node.light_energy = clampf(energy / 85.0, 0.12, 3.0)
		node.light_bake_mode = Light3D.BAKE_STATIC
		node.distance_fade_enabled = true
		node.distance_fade_begin = 32.0
		node.distance_fade_length = 12.0
		var distance: float = float(e.get("_distance", e.get("_zero_percent_distance", "0"))) * UNIT
		if distance < 0.1:
			distance = clampf(sqrt(energy) * 0.85, 3.0, 12.0)
		if light:
			light.omni_range = distance
			light.omni_attenuation = 1.6
		if spot:
			spot.spot_range = distance
			spot.spot_angle = clampf(float(e.get("_cone", "50")), 10.0, 85.0)
			spot.spot_attenuation = 1.5
			var angles: PackedStringArray = str(e.get("angles", "0 0 0")).split(" ", false)
			var pitch: float = float(e.get("pitch", angles[0]))
			var yaw: float = float(angles[1])
			var direction := Vector3(cos(deg_to_rad(pitch)) * cos(deg_to_rad(yaw)), -sin(deg_to_rad(pitch)), -cos(deg_to_rad(pitch)) * sin(deg_to_rad(yaw)))
			own(node, lights)
			node.look_at(node.global_position + direction, Vector3.FORWARD if absf(direction.y) > 0.99 else Vector3.UP)
		else:
			own(node, lights)
		if WindowSystem.tune_light(node,e,windows_by_id):
			tuned_window_lights += 1
		light_count += 1
	var environment_node := WorldEnvironment.new()
	environment_node.name = "NightEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://scripts/night_sky.gdshader")
	for face: String in level.sky:
		sky_material.set_shader_parameter("face_" + face, load("res://" + str(level.sky[face])))
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.42, 0.37)
	env.ambient_light_energy = 0.20
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.background_energy_multiplier = 0.45
	env.fog_enabled = true
	env.fog_light_color = Color(0.028, 0.035, 0.030)
	env.fog_light_energy = 0.60
	env.fog_density = 0.016
	env.fog_sky_affect = 0.65
	environment_node.environment = env
	own(environment_node, world_root)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation_degrees = Vector3(-32, 220, 0)
	moon.light_color = Color(0.53, 0.61, 0.55)
	moon.light_energy = 0.10
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 70.0
	moon.shadow_bias = 0.025
	moon.shadow_normal_bias = 0.3
	own(moon, world_root)
	var glows := Node3D.new()
	glows.name = "LampGlows"
	own(glows, world_root)
	for e: Dictionary in level.sprites:
		var sprite := Sprite3D.new()
		sprite.name = "Glow_" + str(e.id)
		sprite.position = vec(e.origin)
		sprite.texture = load("res://" + str(e.texture))
		sprite.pixel_size = float(e.get("scale", "0.18")) * UNIT
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = false
		var glow_material := StandardMaterial3D.new()
		glow_material.albedo_texture = sprite.texture
		glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		glow_material.no_depth_test = false
		sprite.material_override = glow_material
		var rgb := str(e.get("rendercolor", "255 193 115")).split(" ", false)
		sprite.modulate = Color(float(rgb[0]) / 255.0, float(rgb[1]) / 255.0, float(rgb[2]) / 255.0, float(e.get("renderamt", "190")) / 255.0)
		own(sprite, glows)
	_apply_retro_materials()
	var packed := PackedScene.new()
	var result: Error = packed.pack(world_root)
	if result != OK:
		push_error("Cannot pack world: " + str(result))
		quit(1)
		return
	result = ResourceSaver.save(packed, "res://scenes/church_world.tscn")
	var placement_file := FileAccess.open("res://reports/transport_placement.json", FileAccess.WRITE)
	placement_file.store_string(JSON.stringify(vehicle_placements, "  "))
	placement_file.close()
	var collision_file := FileAccess.open("res://reports/vehicle_collision.json", FileAccess.WRITE)
	collision_file.store_string(JSON.stringify(vehicle_collision_report, "  "))
	collision_file.close()
	var window_file := FileAccess.open("res://reports/windows_build.json",FileAccess.WRITE)
	window_file.store_string(JSON.stringify({"windows":window_records.size(),"draw_batches":world_root.get_node("Windows").get_meta("draw_batches"),"retuned_lights":tuned_window_lights,"room_geometry":false,"transparent_passes":0},"  "))
	window_file.close()
	print("WORLD_BUILT props=%d lights=%d collision_triangles=%d result=%d" % [level.props.size(), light_count, level.collision_triangles, result])
	quit(0 if result == OK else 1)

func _ground_vehicle(p: Dictionary) -> Transform3D:
	var a: Array = p.angles
	var vehicle_basis := Basis(Vector3.UP, deg_to_rad(float(a[1]))) * Basis(Vector3.FORWARD, deg_to_rad(float(a[0]))) * Basis(Vector3.RIGHT, deg_to_rad(float(a[2])))
	vehicle_basis = vehicle_basis.scaled(Vector3.ONE * float(p.scale))
	var original := Vector3(p.origin[0], p.origin[1], p.origin[2])
	var contacts: Array[Vector3] = []
	var floors: Array[float] = []
	var sxx: float = 0.0
	var sxz: float = 0.0
	var szz: float = 0.0
	var sx: float = 0.0
	var sz: float = 0.0
	var sy: float = 0.0
	var sxy: float = 0.0
	var szy: float = 0.0
	for c: Array in p.wheel_contacts:
		var local := Vector3(c[0], c[1], c[2])
		var foot: Vector3 = vehicle_basis * local
		var floor_height: float = _ground_height(original + foot)
		contacts.append(local)
		floors.append(floor_height)
		var y: float = floor_height - foot.y
		sx += foot.x
		sz += foot.z
		sy += y
		sxx += foot.x * foot.x
		sxz += foot.x * foot.z
		szz += foot.z * foot.z
		sxy += foot.x * y
		szy += foot.z * y
	var system := Basis(Vector3(sxx, sxz, sx), Vector3(sxz, szz, sz), Vector3(sx, sz, float(contacts.size())))
	if absf(system.determinant()) > 0.00001:
		var coefficients: Vector3 = system.inverse() * Vector3(sxy, szy, sy)
		var up := Vector3(-coefficients.x, 1.0, -coefficients.y).normalized()
		if up.angle_to(Vector3.UP) < deg_to_rad(8.0):
			vehicle_basis = Basis(Quaternion(Vector3.UP, up)) * vehicle_basis
	var fitted := original
	fitted.y = -INF
	for i in contacts.size():
		var foot: Vector3 = vehicle_basis * contacts[i]
		floors[i] = _ground_height(original + foot)
		fitted.y = maxf(fitted.y, floors[i] - foot.y + 0.002)
	var clearances: Array[float] = []
	for i in contacts.size():
		clearances.append(fitted.y + (vehicle_basis * contacts[i]).y - floors[i])
	vehicle_placements.append({"id": str(p.id), "model": p.source, "old_position": [original.x, original.y, original.z], "position": [fitted.x, fitted.y, fitted.z], "wheel_clearance_m": clearances})
	return Transform3D(vehicle_basis, fitted)

func _ground_height(point: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, point.y + 1.5, point.z), Vector3(point.x, point.y - 3.0, point.z))
	var hit: Dictionary = world_root.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		push_error("No road under vehicle wheel at " + str(point))
		return point.y
	return float(hit.position.y)

func _model_collision(node: Node, parent: Node3D) -> void:
	if node is MeshInstance3D and node.mesh:
		var body := StaticBody3D.new()
		body.name = "Collision_" + str(parent.get_child_count())
		body.set_meta("footstep", "metal")
		own(body, parent)
		var collision := CollisionShape3D.new()
		collision.shape = node.mesh.create_trimesh_shape()
		collision.transform = parent.global_transform.affine_inverse() * node.global_transform
		own(collision, body)
	for child in node.get_children():
		_model_collision(child, parent)

func _vehicle_collision(model: Node3D, pivot: Node3D, data: Dictionary) -> void:
	# A static parked vehicle needs a solid outer hull, not collision triangles
	# for seats, wipers, rims, underside and glass. Keep the render mesh intact.
	var points := PackedVector3Array()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var relative: Transform3D = pivot.global_transform.affine_inverse() * mesh.global_transform
		for surface in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for point: Vector3 in vertices:
				points.append(relative * point)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var joined := ArrayMesh.new()
	joined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var hull: ConvexPolygonShape3D = joined.create_convex_shape(true, true)
	var body := StaticBody3D.new()
	body.name = "VehicleHull"
	body.set_meta("footstep", "metal")
	body.set_meta("collision_proxy", "simplified_convex")
	own(body, pivot)
	var collision := CollisionShape3D.new()
	collision.name = "Hull"
	collision.shape = hull
	own(collision, body)
	vehicle_collision_report.append({"id": str(data.id), "model": data.source, "render_triangles": int(data.triangles), "collision_shapes": 1, "hull_points": hull.points.size()})

func _apply_retro_materials() -> void:
	var cache: Dictionary = {}
	for mesh: MeshInstance3D in world_root.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var original: Material = mesh.get_active_material(surface)
			if not original is StandardMaterial3D:
				continue
			var key: int = original.get_instance_id()
			if not cache.has(key):
				var material: StandardMaterial3D = original.duplicate()
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
				material.metallic = 0.0
				material.metallic_specular = 0.0
				material.roughness = 1.0
				material.clearcoat_enabled = false
				material.rim_enabled = false
				material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
				if not material.emission_enabled:
					material.albedo_color *= Color(0.93, 0.94, 0.90, 1.0)
				cache[key] = material
			mesh.set_surface_override_material(surface, cache[key])

