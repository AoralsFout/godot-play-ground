extends SceneTree
## headless 验证越界、视距、相机切换及浸水；-- --render 额外验证实际海面覆盖并截图。

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

func _capture(name: String) -> Image:
	await _frames(8)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://.godot/ocean-validation/%s.png" % name)
	return image

func _coverage(water: MeshInstance3D, camera: Camera3D) -> void:
	var bounds := water.custom_aabb
	var viewport_size := camera.get_viewport().get_visible_rect().size
	for depth: float in [camera.near, camera.far]:
		for uv: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
			var point := water.to_local(camera.project_position(uv * viewport_size, depth))
			point.y = 0.0
			_check(bounds.has_point(point), "海面覆盖范围没有包含视锥角点：%s" % point)

func _run() -> void:
	var render := "--render" in OS.get_cmdline_user_args()
	var world := (load("res://scenes/world/世界场景.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.get_node("世界环境").sun_auto_rotate = false
	world.get_node("体积云").clouds_enabled = false
	var water := world.get_node("水面") as MeshInstance3D
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.cull_mask = 1048573
	camera.far = 16000.0
	camera.make_current()
	# 与游戏相同，替换运行时水面材质，确保跟随参数重新同步。
	var material := water.get_active_material(0).duplicate() as ShaderMaterial
	water.set_surface_override_material(0, material)
	water._clock_material = null
	material.set_shader_parameter("use_game_time", true)
	material.set_shader_parameter("game_time", 17.0)
	var original_mesh := water.mesh as ArrayMesh
	var vertex_count := original_mesh.surface_get_array_len(0)
	var fixed_point := Vector3(4300, 15, 4300)
	var fixed_height: float = water.surface_height_at(fixed_point)
	for position: Vector3 in [Vector3(3900, 25, 3900), Vector3(4300, 25, 4300), Vector3(50000, 25, -50000), Vector3(-50000, 25, 50000)]:
		camera.look_at_from_position(position, position + Vector3(0.7, -0.1, -1.0))
		await _frames(3)
		_check(material.get_shader_parameter("infinite_ocean") == true, "替换材质后未启用无限海面")
		_check(water.mesh == original_mesh and original_mesh.surface_get_array_len(0) == vertex_count, "移动相机重建或增加了海面网格")
		_check(is_equal_approx(water.surface_height_at(fixed_point), fixed_height), "移动相机改变了固定世界位置的海浪相位")
		_coverage(water, camera)
	camera.far = 40000.0
	camera.fov = 110.0
	await _frames(3)
	_coverage(water, camera)
	var overhead := Camera3D.new()
	world.add_child(overhead)
	overhead.projection = Camera3D.PROJECTION_ORTHOGONAL
	overhead.size = 20000.0
	overhead.far = 40000.0
	overhead.look_at_from_position(Vector3(-60000, 10000, -60000), Vector3(-60000, 15, -60000), Vector3.FORWARD)
	overhead.make_current()
	await _frames(3)
	_coverage(water, overhead)
	camera.make_current()
	camera.far = 16000.0
	camera.fov = 75.0
	camera.position = Vector3(50000, 10, -50000)
	await _frames(3)
	_check(water._underwater_layer.visible and camera.environment == water._underwater_environment, "地图外潜水没有启用水下效果")
	water.infinite_ocean = false
	await _frames(3)
	_check(not water._underwater_layer.visible and camera.environment == null, "有限海面模式在地图外仍有水下效果")
	_check(water.custom_aabb.get_center().is_equal_approx(Vector3.ZERO), "有限海面没有恢复固定边界")
	water.infinite_ocean = true
	camera.look_at_from_position(Vector3(50000, 25, -50000), Vector3(50700, 10, -51000))
	await _frames(3)
	_check(not water._underwater_layer.visible and camera.environment == null, "出水后没有恢复相机环境")
	_check(water._reflection_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "地图外没有启用海面倒影")
	_check(is_equal_approx(water._reflection_camera.global_position.y, 5.0), "地图外倒影相机没有关于海平面镜像")
	if render:
		DirAccess.make_dir_recursive_absolute("res://.godot/ocean-validation")
		var sea := await _capture("outside_map")
		water.hide()
		var sky := await _capture("outside_map_without_water")
		water.show()
		# 地图外没有地形，画面下方三个方向都应出现海面，而不是透出天空。
		for fraction: Vector2 in [Vector2(0.1, 0.85), Vector2(0.5, 0.85), Vector2(0.9, 0.85)]:
			var pixel := Vector2i(fraction * Vector2(sea.get_size()))
			var a := sea.get_pixelv(pixel)
			var b := sky.get_pixelv(pixel)
			var difference := absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			_check(difference > 0.03, "地图外画面下方缺少海面：%s，差分 %f" % [pixel, difference])
		camera.look_at_from_position(Vector3(4300, 600, 4300), Vector3(5300, 15, 3300))
		await _capture("map_edge_overhead")
		camera.position.y = 10.0
		await _capture("outside_map_underwater")
	print("无限海面验收：%s，顶点数 %d" % ["通过" if _failures == 0 else "%d 项失败" % _failures, vertex_count])
	world.queue_free()
	await _frames(3)
	quit(0 if _failures == 0 else 1)
