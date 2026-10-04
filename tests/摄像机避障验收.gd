extends SceneTree
## 运行命令：Godot --headless --path . --script res://tests/摄像机避障验收.gd

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS ", description)
	else:
		failures += 1
		push_error("FAIL " + description)


func _settle() -> void:
	for _index in 5:
		await physics_frame
	await process_frame


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var scene: PackedScene = load("res://玩家.tscn")
	var player: CharacterBody3D = scene.instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var arm: SpringArm3D = player.camera_arm
	var camera: Camera3D = player.camera
	player.camera_pitch.rotation.x = 0.0
	await _settle()
	_check(is_equal_approx(camera.position.z, 4.0), "空旷处保持原有四米距离")

	player.camera_yaw.position.y = 0.5
	await _settle()
	_check(is_equal_approx(arm.get_hit_length(), 4.0), "探测起点位于角色内部时忽略自身碰撞")
	player.camera_yaw.position.y = 1.5

	var wall := StaticBody3D.new()
	wall.position = Vector3(0.0, 1.5, 2.0)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.0, 6.0, 0.5)
	collider.shape = shape
	wall.add_child(collider)
	world.add_child(wall)
	await _settle()
	_check(arm.get_hit_length() > 0.0 and arm.get_hit_length() < 1.75,
		"墙壁挡住摄像机时自动缩短伸缩臂")
	_check(camera.global_position.z < 1.75,
		"摄像机留在墙前，未穿过墙壁")

	wall.collision_layer = 0
	await _settle()
	_check(is_equal_approx(camera.position.z, 4.0), "障碍移除后恢复四米距离")

	wall.position = Vector3(2.0, 1.5, 0.0)
	shape.size = Vector3(0.5, 6.0, 8.0)
	wall.collision_layer = 1
	player.camera_yaw.rotation.y = PI / 2.0
	player.camera_pitch.rotation.x = deg_to_rad(-30.0)
	await _settle()
	_check(arm.get_hit_length() > 0.0 and arm.get_hit_length() < 3.0
		and camera.global_position.x < 1.75,
		"转向和俯仰后仍沿实际摄像机方向避障")

	world.queue_free()
	await process_frame
	print("RESULT camera: ", "PASS" if failures == 0 else "%d FAILED" % failures)
	quit(0 if failures == 0 else 1)
