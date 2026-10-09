## 月光体积云功能验收。
## 检查月光参数同步、日夜遮罩和倒影；加 -- --render 检查方向散射、自阴影及基础预览。

extends SceneTree
## -- --render 验证月光方向、自阴影、昼夜遮罩、倒影与基础预览。

var _failures := 0
var _sky: WorldEnvironment
var _clouds: Node3D
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _frames(count: int) -> void:
	for frame in count:
		await process_frame

func _sun_elevation(degrees: float) -> void:
	var angle := deg_to_rad(degrees)
	var direction := Vector3(0.6 * cos(angle), sin(angle), 0.8 * cos(angle))
	_sun.look_at(_sun.global_position - direction)
	_sync()

func _sync() -> void:
	_sky._process(0.0)
	_clouds._sync_lighting()

func _capture(name: String) -> Image:
	await _frames(8)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://.godot/moon-validation/%s.png" % name)
	return image

func _difference(a: Image, b: Image) -> float:
	var total := 0.0
	var count := 0
	for y in range(a.get_height() / 2):
		for x in range(a.get_width()):
			var first := a.get_pixel(x, y)
			var second := b.get_pixel(x, y)
			total += absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b)
			count += 3
	return total / maxf(count, 1)

func _maximum(image: Image) -> float:
	var maximum := 0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			maximum = maxf(maximum, maxf(color.r, maxf(color.g, color.b)))
	return maximum

func _run() -> void:
	var render := "--render" in OS.get_cmdline_user_args()
	var game := (load("res://scenes/core/根节点.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.set_process(false)
	game.get_node("GUI").hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world := game.get_node("世界场景")
	_sky = world.get_node("世界环境")
	_clouds = world.get_node("体积云")
	_sun = world.get_node("日光")
	_moon = world.get_node("月光")
	_sky.sun_auto_rotate = false
	_sky.moonlight_energy = 0.25
	_sky.moon_enabled = true
	_clouds.animation_enabled = false
	_clouds.planet_radius = 6371000.0
	_clouds.cloud_top = 9100.0
	_clouds.cloud_map_center = Vector2.ZERO
	_clouds.coverage_amount = 0.5
	_clouds.erosion_strength = 0.2
	_clouds.light_shafts_enabled = false
	var moon_direction := Vector3(0.6665324, 0.42758733, 0.6106581).normalized()
	_moon.look_at(_moon.global_position - moon_direction)
	_sun_elevation(30.0)
	_moon.light_energy = 1.0
	_clouds._sync_lighting()
	_check(_clouds.cloud_material.get_shader_parameter("moon_intensity") == 0.0, "白天没有关闭月光直射")
	_sun_elevation(-20.0)
	var night_intensity: float = _clouds.cloud_material.get_shader_parameter("moon_intensity")
	_check(night_intensity > 0.0, "夜间没有开启月光直射")
	_check(_clouds.cloud_material.get_shader_parameter("sun_intensity") == 0.0, "月光替换了太阳强度")
	_check(_clouds.cloud_material.get_shader_parameter("moon_direction").is_equal_approx(moon_direction), "月光方向没有同步")
	_check(_clouds.cloud_material.get_shader_parameter("moon_color") == _moon.light_color, "月光颜色没有同步")
	_sun_elevation(-3.0)
	var transition: float = _clouds.cloud_material.get_shader_parameter("moon_intensity")
	_check(transition > 0.0 and transition < night_intensity, "日落过渡没有平滑衰减月光")
	_sun_elevation(-20.0)
	_clouds.moon_lighting_enabled = false
	_check(_clouds.cloud_material.get_shader_parameter("moon_intensity") == 0.0, "月光云开关没有关闭直射")
	_clouds.moon_lighting_enabled = true
	_moon.hide()
	_sync()
	_check(_clouds.cloud_material.get_shader_parameter("moon_intensity") == 0.0, "隐藏月亮仍照亮云")
	_moon.show()
	_moon.look_at(_moon.global_position - Vector3(0.6, -0.5, 0.8).normalized())
	_sync()
	_moon.light_energy = 1.0
	_clouds._sync_lighting()
	_check(_clouds.cloud_material.get_shader_parameter("moon_intensity") == 0.0, "地平线下的月亮仍照亮云")
	_moon.look_at(_moon.global_position - moon_direction)
	_sync()
	_clouds.moon_light_multiplier = 2.0
	_check(is_equal_approx(float(_clouds.cloud_material.get_shader_parameter("moon_intensity")), night_intensity * 2.0), "月光强度倍率没有同步")
	_clouds.moon_light_multiplier = 1.0
	if render:
		_check(RenderingServer.get_rendering_device() != null, "月光 GPU 验收需要 Forward+")
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.cull_mask = 1048573
		camera.far = 16000.0
		var position := Vector3(1200, 150, 1900)
		camera.look_at_from_position(position, position + Vector3(0.55, 0.17, 0.8) * 1000.0)
		camera.make_current()
		var deadline := Time.get_ticks_msec() + 30000
		while _clouds.cloud_material.get_shader_parameter("noise_ready") != true and Time.get_ticks_msec() < deadline:
			await process_frame
		await _frames(30)
		_check(not _clouds._post_failed and not _clouds._post_effect._pipelines.is_empty(), "月光计算管线没有编译/运行")
		DirAccess.make_dir_recursive_absolute("res://.godot/moon-validation")
		var night_on := await _capture("night_on")
		var water := world.get_node("水面")
		var reflection_on: Image = water._reflection_viewport.get_texture().get_image()
		_clouds.moon_lighting_enabled = false
		var night_off := await _capture("night_off")
		var reflection_off: Image = water._reflection_viewport.get_texture().get_image()
		var direct_delta := _difference(night_on, night_off)
		print("月光直射天空差分：%f" % direct_delta)
		_check(direct_delta > 0.0005, "月光没有改变夜间云的光照")
		_check(reflection_on.get_data() != reflection_off.get_data(), "月光没有改变倒影中的云")
		_clouds.moon_lighting_enabled = true
		_clouds.post_debug_view = 8
		var direct_a := await _capture("direct_a")
		_clouds.self_shadow = false
		var unshadowed := await _capture("unshadowed")
		_check(_difference(direct_a, unshadowed) > 0.0005, "月光没有产生云内自阴影")
		_clouds.self_shadow = true
		_moon.look_at(_moon.global_position - Vector3(-moon_direction.x, moon_direction.y, -moon_direction.z))
		_sync()
		var direct_b := await _capture("direct_b")
		_check(_difference(direct_a, direct_b) > 0.0005, "改变月亮方向没有改变云的受光面")
		_moon.look_at(_moon.global_position - moon_direction)
		_sun_elevation(30.0)
		var daytime := await _capture("day_direct")
		_check(_maximum(daytime) < 0.001, "白天月光通道不是全黑")
		_sun_elevation(-20.0)
		_clouds.light_shafts_enabled = true
		_clouds.post_debug_view = 7
		var mie := await _capture("moon_mie")
		_check(_maximum(mie) > 0.001, "夜间没有月光 Mie 光束")
		_clouds.moon_lighting_enabled = false
		var disabled := await _capture("disabled_mie")
		_check(_maximum(disabled) < 0.001, "关闭月光云照明后仍有月光束")
		_clouds.moon_lighting_enabled = true
		_clouds.post_debug_view = 0
		_clouds.post_processing_enabled = false
		var fallback_on := await _capture("fallback_on")
		_clouds.moon_lighting_enabled = false
		var fallback_off := await _capture("fallback_off")
		_check(_difference(fallback_on, fallback_off) > 0.0005, "基础云预览没有月光直射")
	game.queue_free()
	await _frames(3)
	print("月光体积云验收：%s" % ("通过" if _failures == 0 else "%d 项失败" % _failures))
	quit(0 if _failures == 0 else 1)
