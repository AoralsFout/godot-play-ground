extends SceneTree
## 运行参数：--headless --script res://tests/草地验收.gd
## 截图和 GPU 风动检查时，去掉 --headless 并添加 -- --render。

const Distribution := preload("res://草地分布.gd")
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	print("GRASS %s: %s" % [label, "PASS" if condition else "FAIL"])
	if not condition:
		failures += 1
		push_error(label)


func _settle(grass: Node3D) -> void:
	await process_frame
	await process_frame
	var deadline := Time.get_ticks_msec() + 15000
	while not grass._pending.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(grass._pending.is_empty(), "区块生成在限时内完成")


func _run() -> void:
	var bare := 0
	var dense := 0
	for z in range(-100, 101, 4):
		for x in range(-100, 101, 4):
			var density := Distribution.density_at(Vector2(x, z), 7319, 0.055, 0.58)
			if density < 0.01: bare += 1
			if density > 0.95: dense += 1
	_check(bare > 100 and dense > 100, "噪声同时形成空白和茂密斑块")
	_check(Distribution.density_at(Vector2(13, 27), 7319, 0.055, 0.0) == 0.0, "覆盖率零关闭草地")
	var started := Time.get_ticks_msec()
	var world := load("res://世界场景.tscn").instantiate() as Node3D
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	camera.look_at_from_position(Vector3(12, 24, -10), Vector3(0, 18, -30))
	var grass := world.get_node("草地")
	await _settle(grass)
	print("GRASS initial_load_ms=", Time.get_ticks_msec() - started, " indexed_cells=", grass._cells.size())
	var total := 0
	var min_height := INF
	var max_ground_error := 0.0
	var empty_patches := 0
	var normal_violations := 0
	var count_mismatches := 0
	var data_key := Vector2i.ZERO
	for key: Vector2i in grass._chunks:
		var chunk: MultiMeshInstance3D = grass._chunks[key]
		if chunk == null:
			empty_patches += 1
			continue
		data_key = key
		# 使用空渲染器的无界面渲染不会保留 MultiMesh 的 GPU 缓冲区。
		var data: Dictionary = grass._generate_chunk(key)
		var transforms: Array[Transform3D] = data.transforms
		if transforms.size() != chunk.multimesh.instance_count:
			count_mismatches += 1
		for transform in transforms:
			var position_world := chunk.global_transform * transform.origin
			min_height = minf(min_height, position_world.y)
			var surface: Vector4 = grass.surface_at(Vector2(position_world.x, position_world.z))
			max_ground_error = maxf(max_ground_error, absf(position_world.y - surface.w - 0.015))
			if surface.y < cos(deg_to_rad(grass.max_slope_degrees)):
				normal_violations += 1
			total += 1
	print("GRASS tufts=%d empty_chunks=%d min_root_y=%.4f ground_error=%.6f" % [total, empty_patches, min_height, max_ground_error])
	_check(total > 1000, "真实地图中生成可见草丛")
	_check(count_mismatches == 0, "生成数量与提交的实例数量一致")
	_check(min_height > world.get_node("水面").global_position.y + grass.shore_clearance, "全部草根高于海平面并保留岸边缓冲")
	_check(max_ground_error < 0.0001 and normal_violations == 0, "草根贴合地形并避开陡坡")
	var snapshot: Dictionary = grass._generate_chunk(data_key)
	grass._chunks[data_key].free()
	grass._chunks.erase(data_key)
	grass._build_chunk(data_key)
	_check(snapshot == grass._generate_chunk(data_key), "卸载重建后草的位置完全一致")
	var before: float = grass._time
	paused = true
	await create_timer(0.1, true).timeout
	_check(grass._time == before, "单人暂停时微风停止")
	paused = false
	await process_frame
	await process_frame
	_check(grass._time > before, "恢复游戏后微风继续")
	var previous: Array = grass._chunks.keys()
	camera.position = Vector3(500, 40, 500)
	await _settle(grass)
	var removed := 0
	for key in previous:
		if not grass._chunks.has(key): removed += 1
	_check(removed == previous.size(), "移动到远处会卸载旧草丛")
	camera.look_at_from_position(Vector3(12, 24, -10), Vector3(0, 18, -30))
	await _settle(grass)
	if OS.get_cmdline_user_args().has("--render"):
		await _render(world, grass, camera)
	grass.set_process(true)
	grass.grass_coverage = 0.0
	await _settle(grass)
	var any_grass := false
	for chunk in grass._chunks.values():
		any_grass = any_grass or chunk != null
	_check(not any_grass, "修改覆盖率为零会清除全部草叶")
	grass.grass_coverage = 0.58
	world.get_node("水面").position.y = 22.0
	await _settle(grass)
	var raised_sea_valid := true
	for key: Vector2i in grass._chunks:
		var data: Dictionary = grass._generate_chunk(key)
		for transform: Transform3D in data.transforms:
			raised_sea_valid = raised_sea_valid and transform.origin.y > 22.0 + grass.shore_clearance
	_check(raised_sea_valid and grass._sea_level == 22.0, "抬高水面后重新排除淹没区域")
	world.queue_free()
	await process_frame
	print("RESULT grass: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _capture(label: String) -> Image:
	for frame in 12:
		await process_frame
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://.godot/grass_render/" + label + ".png")
	return image


func _render(world: Node3D, grass: Node3D, camera: Camera3D) -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/grass_render")
	world.get_node("世界环境").set_process(false)
	var water: MeshInstance3D = world.get_node("水面")
	water.get_active_material(0).set_shader_parameter("game_time", 2.0)
	water.set_process(false)
	grass.set_process(false)
	camera.look_at_from_position(Vector3(12, 21, -10), Vector3(0, 18, -30))
	grass._material.set_shader_parameter("wind_time", 0.0)
	var first := await _capture("coast_breeze_0")
	grass._material.set_shader_parameter("wind_time", 2.0)
	var second := await _capture("coast_breeze_2")
	var changed := 0
	for y in range(0, first.get_height(), 2):
		for x in range(0, first.get_width(), 2):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() > 0.03:
				changed += 1
	print("GRASS wind_changed_pixels=", changed)
	_check(changed > 100, "GPU 渲染中微风改变草叶姿态")
	camera.look_at_from_position(Vector3(0, 65, -5), Vector3(0, 18, -25))
	await _capture("patches_overhead")
	# 从实际分布中选取茂密的水外草地，展示草叶近景。
	var chunk: MultiMeshInstance3D
	for candidate: MultiMeshInstance3D in grass._chunks.values():
		if candidate != null and candidate.multimesh.instance_count > 200:
			chunk = candidate
			break
	if chunk != null:
		var point := chunk.global_transform * chunk.multimesh.get_instance_transform(100).origin
		camera.look_at_from_position(point + Vector3(3, 2, 5), point + Vector3.UP * 0.3)
		await _capture("blades_closeup")
