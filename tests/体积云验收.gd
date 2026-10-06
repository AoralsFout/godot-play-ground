extends SceneTree
## headless 验证集成逻辑；-- --render 额外运行 GPU 合成与截图比较。

const WORLD_PATH := "res://scenes/根节点.tscn"
const SOURCE = preload("res://scripts/clouds/cloud_postprocess_source.gd")
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _frames(count: int) -> void:
	for frame in count:
		await process_frame


func _run() -> void:
	var render := "--render" in OS.get_cmdline_user_args()
	var scene := load(WORLD_PATH) as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world := game.get_node("世界场景")
	var clouds := world.get_node("体积云")
	var sky := world.get_node("世界环境") as WorldEnvironment
	var water := world.get_node("水面")
	var gui := game.get_node("GUI")
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.cull_mask = 1048573
	camera.far = 16000.0
	camera.look_at_from_position(Vector3(1200, 150, 1900), Vector3(1200, 1600, 0))
	camera.make_current()
	await _frames(3)
	_check(clouds.cloud_material != null, "世界场景未创建云材质")
	_check(gui.map_camera.compositor != null and gui.map_camera.compositor.compositor_effects.is_empty(), "小地图没有覆盖云合成器")
	_check(root.scaling_3d_scale == 1.0, "云集成改变了主视口分辨率")
	var built := SOURCE.build()
	_check(built.shaders.size() == 4, "云后处理没有构建四个计算通道")
	var saved_gain: float = clouds.noise_gain
	clouds.noise_gain = 0.0
	_check(is_equal_approx(float(clouds.cloud_material.get_shader_parameter("noise_normalization")), 1.0), "噪声归一化未同步")
	clouds.noise_gain = saved_gain
	clouds.clouds_enabled = false
	_check(clouds.cloud_material.get_shader_parameter("density_multiplier") == 0.0, "关闭云仍有密度")
	clouds.clouds_enabled = true
	var water_material := water.get_active_material(0) as ShaderMaterial
	_check(water_material.get_shader_parameter("ground_cloud_shadows") == true, "游戏替换水面材质后丢失云影")
	var before: Vector3 = clouds.cloud_material.get_shader_parameter("noise_motion_offset")
	await _frames(3)
	_check(before != clouds.cloud_material.get_shader_parameter("noise_motion_offset"), "云动画没有推进")
	clouds.animation_enabled = false
	before = clouds.cloud_material.get_shader_parameter("noise_motion_offset")
	await _frames(3)
	_check(before == clouds.cloud_material.get_shader_parameter("noise_motion_offset"), "关闭动画后仍在移动")
	paused = true
	await _frames(3)
	_check(before == clouds.cloud_material.get_shader_parameter("noise_motion_offset"), "暂停没有冻结云")
	paused = false
	var sun := world.get_node("日光") as DirectionalLight3D
	sun.rotation_degrees.x = 25.0
	await _frames(3)
	_check(clouds.cloud_material.get_shader_parameter("sun_direction").is_equal_approx(sun.global_basis.z.normalized()), "云光照未跟随太阳")
	_check(water_material.get_shader_parameter("cloud_ground_sun_direction").is_equal_approx(sun.global_basis.z.normalized()), "海面云影未跟随太阳")
	_check(clouds.cloud_material.get_shader_parameter("cloud_sky_horizon") == sky.sky_material.get_shader_parameter("horizon_color"), "云雾色未跟随天空")
	sun.rotation_degrees.x = -35.0
	await _frames(3)
	if render:
		_check(RenderingServer.get_rendering_device() != null, "GPU 验收需要 Forward+ 渲染器")
		var deadline := Time.get_ticks_msec() + 30000
		while clouds.cloud_material.get_shader_parameter("noise_ready") != true and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(clouds.cloud_material.get_shader_parameter("noise_ready") == true, "三维噪声纹理没有准备完成")
		_check(sky.compositor != null and sky.compositor.compositor_effects.size() >= 1, "云合成器未绑定世界环境")
		await _frames(40)
		_check(not clouds._post_failed and not clouds._post_effect._pipelines.is_empty(), "GPU 云计算通道没有成功执行")
		_check(clouds._reflection_effect != null and not clouds._reflection_effect._pipelines.is_empty(), "倒影云计算通道没有成功执行")
		DirAccess.make_dir_recursive_absolute("res://.godot/cloud-validation")
		var cloudy := await _capture("day")
		# 倒影差分只比较云，避免地面云影掩盖倒影中丢云的问题。
		clouds.ground_cloud_shadows = false
		camera.look_at_from_position(Vector3(3950, 80, 3950), Vector3(2400, 15, 1300))
		await _frames(8)
		await _capture("ocean")
		var reflection_cloudy: Image = water._reflection_viewport.get_texture().get_image()
		clouds.clouds_enabled = false
		await _frames(8)
		var reflection_clear: Image = water._reflection_viewport.get_texture().get_image()
		_check(reflection_cloudy.get_data() != reflection_clear.get_data(), "开关云没有改变海面倒影")
		reflection_cloudy.save_png("res://.godot/cloud-validation/reflection.png")
		clouds.ground_cloud_shadows = true
		camera.look_at_from_position(Vector3(1200, 150, 1900), Vector3(1200, 1600, 0))
		await _frames(8)
		var clear := await _capture("clear")
		_check(cloudy.get_data() != clear.get_data(), "开关云没有改变主视图")
		clouds.clouds_enabled = true
		clouds.post_processing_enabled = false
		await _frames(8)
		_check(clouds._fallback.visible, "关闭后处理没有恢复基础云")
		await _capture("fallback")
		clouds.post_processing_enabled = true
		sun.rotation_degrees.x = 25.0
		await _frames(8)
		await _capture("night")
	var effect: CompositorEffect = clouds._post_effect
	clouds.queue_free()
	await _frames(3)
	_check(sky.compositor == null, "离开云组件未恢复世界合成器")
	_check(effect == null or not effect.enabled, "云组件释放后后处理仍启用")
	_check(water_material.get_shader_parameter("ground_cloud_shadows") == false, "云组件释放后海面云影仍启用")
	game.queue_free()
	await _frames(3)
	# 再次进入场景覆盖菜单返回后重新进入游戏的路径。
	game = scene.instantiate()
	root.add_child(game)
	await _frames(3)
	_check(game.get_node("世界场景/体积云").cloud_material != null, "重新进入游戏未重建体积云")
	game.queue_free()
	await _frames(3)
	print("体积云验收：%s（%s）" % ["通过" if _failures == 0 else "%d 项失败" % _failures, "GPU" if render else "headless"])
	quit(0 if _failures == 0 else 1)


func _capture(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://.godot/cloud-validation/%s.png" % name)
	return image
