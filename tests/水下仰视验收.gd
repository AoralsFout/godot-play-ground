extends SceneTree
## 使用真实场景与 Forward+ 渲染检查水下仰视的绿色覆盖层。
## Godot --path . --script res://tests/水下仰视验收.gd [-- --minimal]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures := 0
	# 最小复现：蓝色背景、无光照与雾，仅渲染真实水面着色器的底面。
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.08, 0.15, 0.4)
	viewport.add_child(environment)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	water.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/water/水面.gdshader")
	material.set_shader_parameter("use_game_time", true)
	material.set_shader_parameter("game_time", 2.0)
	material.set_shader_parameter("wave_height", 0.0)
	material.set_shader_parameter("refraction_strength", 0.0)
	material.set_shader_parameter("reflection_steps", 0)
	material.set_shader_parameter("water_ambient_light", Vector3.ZERO)
	water.material_override = material
	viewport.add_child(water)
	var camera := Camera3D.new()
	camera.position = Vector3(0, -2, 0)
	camera.rotation_degrees.x = 90
	camera.fov = 110
	viewport.add_child(camera)
	camera.make_current()
	for frame in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	var dark := viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://.godot/water_render")
	dark.save_png("res://.godot/water_render/underwater_unlit.png")
	var unlit := dark.get_pixel(10, 10).get_luminance()
	print("UNDERWATER_UP unlit_internal_reflection=%.5f" % unlit)
	if unlit > 0.01:
		failures += 1
	# 有环境光时仍需显示内反射，窗口中心也必须保留天空透射。
	material.set_shader_parameter("water_ambient_light", Vector3.ONE * 0.4)
	for frame in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	var lit := viewport.get_texture().get_image()
	var reflection_response := lit.get_pixel(10, 10).get_luminance() - unlit
	var window_contrast := dark.get_pixel(128, 128).get_luminance() - unlit
	print("UNDERWATER_UP ambient_response=%.5f sky_window_contrast=%.5f" % [reflection_response, window_contrast])
	if reflection_response < 0.05 or window_contrast < 0.05:
		failures += 1
	viewport.queue_free()
	await process_frame
	if OS.get_cmdline_user_args().has("--minimal"):
		print("RESULT underwater unlit reflection: %s" % ("PASS" if failures == 0 else "FAIL green emission"))
		quit(0 if failures == 0 else 1)
		return
	var game := load("res://scenes/根节点.tscn").instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	var sky := game.get_node("世界场景/世界环境")
	game.get_node("世界场景/日光").rotation_degrees = Vector3(-190, 0, 0)
	sky._process(0.0)
	sky.set_process(false)
	var avatar: CharacterBody3D = game.avatars[1]
	avatar.set_physics_process(false)
	avatar.global_position = Vector3(0, 11, 30)
	avatar.camera_pitch.rotation_degrees.x = 45
	game.water_material.set_shader_parameter("game_time", 2.0)
	for frame in 20:
		await process_frame
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://.godot/water_render")
	image.save_png("res://.godot/water_render/underwater_up.png")
	var green_pixels := 0
	var samples := 0
	for y in range(80, 600, 2):
		for x in range(40, 1100, 2):
			var color := image.get_pixel(x, y)
			samples += 1
			if color.g > color.r * 1.6 and color.g > color.b * 0.65 and color.g > 0.05:
				green_pixels += 1
	var coverage := float(green_pixels) / samples
	print("UNDERWATER_UP green_coverage=%.5f" % coverage)
	var passed := coverage < 0.1 and failures == 0
	print("RESULT underwater upward view: %s" % ("PASS" if passed else "FAIL green layer"))
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
