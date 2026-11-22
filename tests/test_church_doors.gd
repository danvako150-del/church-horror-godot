extends SceneTree

var passed: Array[String] = []
var failed: Array[String] = []
var scene: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed.append(message)
	else:
		failed.append(message)
		push_error(message)

func ray(a: Vector3,b: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(a,b)
	query.exclude = [scene.player.get_rid()]
	return scene.get_world_3d().direct_space_state.intersect_ray(query)

func run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.player.set_process_unhandled_input(false)
	for i in 8:
		await physics_frame
	for height: float in [2.4,4.5,7.5]:
		var hit := ray(Vector3(-43.18,height,29),Vector3(-43.18,height,25))
		check(not hit.is_empty() and absf(hit.position.z-26.67)<0.015,"Removed entrance exposes the continuous south wall at height %.1f" % height)
	var ground := ray(Vector3(-43.18,3,27.25),Vector3(-43.18,-1,27.25))
	check(not ground.is_empty() and absf(ground.position.y)<0.02,"No old step collider remains south of the church")
	var leaf := ray(Vector3(-43.18,1,-29),Vector3(-43.18,1,-25))
	check(not leaf.is_empty() and leaf.position.z> -27.05 and leaf.position.z< -26.8,"Lower door leaf is visible through the stone-base opening")
	for x: float in [-46.0,-40.3]:
		var jamb := ray(Vector3(x,1,-29),Vector3(x,1,-25))
		check(not jamb.is_empty() and absf(jamb.position.z+27.1272)<0.015,"Stone base remains beside the door at X %.1f" % x)
	for pair: Vector2 in [Vector2(-28.448,0.1524),Vector2(-28.1432,0.3048),Vector2(-27.8384,0.4572),Vector2(-27.35,0.6096)]:
		var step := ray(Vector3(-43.18,3,pair.x),Vector3(-43.18,-1,pair.x))
		check(not step.is_empty() and absf(step.position.y-pair.y)<0.01,"Entrance tread has the correct collision height %.4f" % pair.y)
	scene.player.global_position = Vector3(-43.18,0.1,-29.1)
	scene.player.rotation.y = PI
	scene.player.velocity = Vector3.ZERO
	for i in 15:
		await physics_frame
	Input.action_press("move_forward")
	for i in 100:
		await physics_frame
	Input.action_release("move_forward")
	print("DOOR_APPROACH position=",scene.player.position)
	check(scene.player.position.y>.55 and scene.player.position.y<.75,"Player climbs all four entrance steps to the threshold")
	check(scene.player.position.z< -27.10,"Closed door stops the player at the entrance")
	var file := FileAccess.open("res://reports/church_door_tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	file.close()
	print("CHURCH_DOOR_TESTS passed=%d failed=%d" % [passed.size(),failed.size()])
	scene.queue_free()
	for i in 4:
		await process_frame
	quit(0 if failed.is_empty() else 1)
