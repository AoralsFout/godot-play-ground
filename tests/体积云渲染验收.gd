extends SceneTree
## 用正常图形渲染运行：Godot --path . --script res://tests/体积云渲染验收.gd
## 对比真实场景里的晴空、体积云、风与相机位移，并验证暂停。

var failures := 0
const OUTPUT := "res://.godot/cloud_render/"


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int = 8) -> void:
	for frame in count:
		await process_frame
		await RenderingServer.frame_post_draw


func _check(condition: bool, description: String) -> void:
	print("%s %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		failures += 1


func _difference(a: Image, b: Image, area := Rect2i(40, 30, 1200, 250)) -> float:
	var total := 0.0
	var count := 0
	# 仅采样天空，避开地形和水面，并通过足够多的像素排除噪声干扰。
	for y in range(area.position.y, area.end.y, 4):
		for x in range(area.position.x, area.end.x, 4):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += Vector3(ca.r - cb.r, ca.g - cb.g, ca.b - cb.b).length()
			count += 1
	return total / count


func _capture(name: String) -> Image:
	var result := root.get_texture().get_image()
	result.save_png(OUTPUT + name + ".png")
	return result


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var game := load("res://scenes/根节点.tscn").instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	game.get_node("GUI").hide()
	var avatar: CharacterBody3D = game.avatars[1]
	avatar.set_physics_process(false)
	# SpringArm 自带物理更新，否则会把验收手动移动的相机拉回玩家身边。
	avatar.camera_arm.process_mode = Node.PROCESS_MODE_DISABLED
	var camera: Camera3D = avatar.camera
	camera.global_position = Vector3(20.0, 26.0, 50.0)
	camera.look_at(Vector3(0.0, 105.0, -180.0))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var clouds: WorldEnvironment = game.get_node("世界场景/世界环境")
	# 云层验收固定白天，不依赖用户当前保存的太阳角度。
	game.get_node("世界场景/日光").rotation_degrees = Vector3(-35.0, 26.0, 0.0)
	clouds._process(0.0)
	clouds.set_process(false)
	clouds.cloud_material.set_shader_parameter("cloud_time", 12.0)
	var noise: NoiseTexture3D = clouds.cloud_material.get_shader_parameter("cloud_noise")
	var deadline := Time.get_ticks_msec() + 20000
	while noise.get_data().is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not noise.get_data().is_empty(), "3D noise generated")
	await _frames(16)
	_check(clouds.solar_elevation > 15.0, "daylight fixture has sun above horizon")
	var cloudy := _capture("world_clouds")
	clouds.clouds_enabled = false
	await _frames()
	var clear := _capture("world_clear")
	var visible := _difference(cloudy, clear)
	print("CLOUD visibility_difference=%.5f" % visible)
	_check(visible > 0.015, "clouds visible in the real world")
	clouds.clouds_enabled = true
	clouds.cloud_density = 0.0
	await _frames()
	_check(_difference(clear, _capture("world_zero_density")) < 0.002, "zero density produces clear sky")
	clouds.cloud_density = 1.1
	clouds.cloud_material.set_shader_parameter("cloud_time", 72.0)
	await _frames()
	_check(_difference(cloudy, _capture("world_wind")) > 0.01, "wind advects cloud volume")
	clouds.cloud_material.set_shader_parameter("cloud_time", 12.0)
	camera.global_position.x += 160.0
	await _frames()
	_check(_difference(cloudy, _capture("world_parallax")) > 0.01, "camera movement changes world-space cloud view")
	# 位于云层内部或上方的摄像机也必须正确渲染光线与云层的相交部分。
	camera.global_position = Vector3(20.0, 245.0, 50.0)
	camera.look_at(camera.global_position + Vector3(0.0, 0.4, -1.0))
	await _frames()
	var inside := _capture("inside_cloud_layer")
	clouds.clouds_enabled = false
	await _frames()
	_check(_difference(inside, _capture("inside_clear")) > 0.01, "camera inside cloud layer")
	clouds.clouds_enabled = true
	camera.global_position.y = 450.0
	camera.look_at(camera.global_position + Vector3(0.0, -0.15, -1.0))
	await _frames()
	var above := _capture("above_cloud_layer")
	clouds.clouds_enabled = false
	await _frames()
	# 朝下观察的天空位于地平线下方，采样时排除上方天空和地形。
	_check(_difference(above, _capture("above_clear"), Rect2i(40, 315, 1200, 75)) > 0.01,
		"camera above cloud layer looking down")
	clouds.clouds_enabled = true
	clouds.set_process(true)
	await _frames(2)
	paused = true
	var frozen_time: float = clouds.cloud_time
	await _frames(4)
	_check(is_equal_approx(clouds.cloud_time, frozen_time), "single-player pause freezes clouds")
	paused = false
	await _frames(2)
	_check(clouds.cloud_time > frozen_time, "cloud animation resumes")
	print("RESULT volumetric clouds: %s" % ("PASS" if failures == 0 else "FAIL"))
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
