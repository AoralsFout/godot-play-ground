extends SceneTree
## 固定云动画与朝阳视角，比较光束开关；需要窗口模式的 Forward+。

var _failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for frame in count:
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _capture(name: String) -> Image:
	await _frames(8)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://.godot/shaft-validation/%s.png" % name)
	return image

func _run() -> void:
	if RenderingServer.get_rendering_device() == null:
		push_error("光束验收需要窗口模式的 Forward+ GPU")
		quit(1)
		return
	var baseline := "--baseline" in OS.get_cmdline_user_args()
	var suffix := "_baseline" if baseline else ""
	DirAccess.make_dir_recursive_absolute("res://.godot/shaft-validation")
	var game := (load("res://scenes/根节点.tscn") as PackedScene).instantiate()
	root.add_child(game)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.get_node("GUI").hide()
	var world := game.get_node("世界场景")
	world.get_node("世界环境").sun_auto_rotate = false
	var clouds := world.get_node("体积云")
	# 本验收只比较太阳光束，月光的夜间渲染由月光专项验收覆盖。
	clouds.moon_lighting_enabled = false
	# 固定天气夹具，避免编辑器保存的昼夜/云形调参改变光束回归基准。
	clouds.planet_radius = 6371000.0
	clouds.cloud_top = 9100.0
	clouds.cloud_map_center = Vector2.ZERO
	clouds.coverage_amount = 0.5
	clouds.erosion_strength = 0.2
	clouds.density_multiplier = 1.0
	var fixture_sun := world.get_node("日光") as DirectionalLight3D
	fixture_sun.look_at(fixture_sun.global_position - Vector3(0.6665324, 0.42758733, 0.6106581))
	clouds.animation_enabled = false
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.cull_mask = 1048573
	camera.far = 16000.0
	var position := Vector3(1200, 150, 1900)
	camera.look_at_from_position(position, position + Vector3(0.55, 0.17, 0.8) * 1000.0)
	camera.make_current()
	# 固定水面波相位；海面的倒影本身也含光束，不能把倒影差分当作近景泄漏。
	game.set_process(false)
	var deadline := Time.get_ticks_msec() + 30000
	while clouds.cloud_material.get_shader_parameter("noise_ready") != true and Time.get_ticks_msec() < deadline:
		await process_frame
	await _frames(30)
	_check(RenderingServer.get_rendering_device() != null, "光束验收需要 Forward+ GPU")
	_check(not clouds._post_failed, "光束管线编译失败")
	var on := await _capture("on" + suffix)
	clouds.light_shafts_enabled = false
	var off := await _capture("off" + suffix)
	clouds.light_shafts_enabled = true
	clouds.post_debug_view = 5
	await _capture("mask" + suffix)
	clouds.post_debug_view = 4
	await _capture("opacity" + suffix)
	clouds.post_debug_view = 0
	if not baseline:
		clouds.post_debug_view = 6
		await _capture("highlight")
		clouds.post_debug_view = 7
		await _capture("mie")
		clouds.post_debug_view = 0
	var sky_delta := 0.0
	var sky_count := 0
	for y in range(on.get_height()):
		for x in range(on.get_width()):
			var a := on.get_pixel(x, y)
			var b := off.get_pixel(x, y)
			var delta := (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
			if y < on.get_height() / 2:
				sky_delta += delta
				sky_count += 1
	sky_delta /= maxf(sky_count, 1)
	print("光束天空平均差分：%f" % sky_delta)
	if not baseline:
		_check(sky_delta > 0.005, "朝阳天空中光束不可见")
		# 80 米处放置不透明物体，直接验证几何深度遮挡，避免水面倒影干扰。
		var blocker := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(30, 20, 5)
		blocker.mesh = box
		blocker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.4, 0.02, 0.35)
		blocker.material_override = material
		world.add_child(blocker)
		blocker.global_transform = camera.global_transform
		blocker.position += -camera.global_basis.z * 80.0 - camera.global_basis.y * 20.0
		var near_on := await _capture("near_on")
		clouds.light_shafts_enabled = false
		var near_off := await _capture("near_off")
		var center := camera.unproject_position(blocker.global_position)
		var near_delta := 0.0
		for y in range(int(center.y) - 16, int(center.y) + 16):
			for x in range(int(center.x) - 16, int(center.x) + 16):
				var a := near_on.get_pixel(x, y)
				var b := near_off.get_pixel(x, y)
				near_delta += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
		near_delta /= 32.0 * 32.0 * 3.0
		print("80 米不透明物体平均差分：%f" % near_delta)
		_check(near_delta < 0.001, "光束覆盖了近处不透明物体")
		blocker.hide()
		clouds.light_shafts_enabled = true
		var sun := world.get_node("日光") as DirectionalLight3D
		var saved_rotation := sun.rotation_degrees
		sun.rotation_degrees.x = -12.0
		await _frames(3)
		var to_sun := sun.global_basis.z.normalized()
		camera.look_at_from_position(position, position + Vector3(to_sun.x + 0.15, 0.0, to_sun.z - 0.1) * 1000.0)
		await _capture("sunset")
		clouds.post_debug_view = 5
		await _capture("sunset_mask")
		# 太阳在相机背后时，径向源应完全消失。
		camera.look_at_from_position(position, position + Vector3(-to_sun.x, 0.17, -to_sun.z) * 1000.0)
		var away := await _capture("away_mask")
		_check(_maximum_rgb(away) < 0.001, "背向太阳仍存在径向光束")
		clouds.post_debug_view = 7
		camera.look_at_from_position(position, position + Vector3(to_sun.x, 0.0, to_sun.z) * 1000.0)
		sun.hide()
		var hidden := await _capture("hidden_mie")
		_check(_maximum_rgb(hidden) < 0.001, "隐藏太阳后仍存在 Mie 光束")
		sun.show()
		sun.rotation_degrees.x = 25.0
		var night := await _capture("night_mie")
		_check(_maximum_rgb(night) < 0.001, "夜间仍存在太阳 Mie 光束")
		clouds.post_debug_view = 0
		sun.rotation_degrees = saved_rotation
		position = Vector3(0, 28, -10)
		camera.look_at_from_position(position, position + Vector3(0.55, 0.17, 0.8) * 1000.0)
		await _capture("gameplay")
		clouds.light_shafts_enabled = false
		await _capture("gameplay_off")
		clouds.light_shafts_enabled = true
		sun.rotation_degrees.x = -12.0
		await _frames(3)
		to_sun = sun.global_basis.z.normalized()
		camera.look_at_from_position(position, position + Vector3(to_sun.x + 0.15, 0.0, to_sun.z - 0.1) * 1000.0)
		await _capture("gameplay_sunset")
		# 较碎的云层覆盖更多云隙，检查高光遮罩对云形状变化的响应。
		sun.rotation_degrees = saved_rotation
		clouds.density_multiplier = 4.0
		clouds.noise_repeat_distance = 30000.0
		clouds.coverage_amount = 0.4
		camera.look_at_from_position(position, position + Vector3(0.55, 0.17, 0.8) * 1000.0)
		await _capture("broken_clouds")
	print("光束验收：%s" % ("通过" if _failures == 0 else "%d 项失败" % _failures))
	game.queue_free()
	await _frames(3)
	quit(0 if _failures == 0 else 1)

func _maximum_rgb(image: Image) -> float:
	var maximum := 0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			maximum = maxf(maximum, maxf(color.r, maxf(color.g, color.b)))
	return maximum
