extends SceneTree
## --headless --script res://tests/树叶验收.gd
## GPU 验收：去掉 --headless，添加 -- --render。截图写入 .godot/leaf_render。

const Leaves := preload("res://树叶.gd")
const OUTPUT := "res://.godot/leaf_render/"
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	print("LEAVES %s %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		failures += 1


func _frames(count: int = 4) -> void:
	for frame in count:
		await process_frame
		if "--render" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw


func _capture(file_name: String) -> Image:
	var image := root.get_texture().get_image()
	image.save_png(OUTPUT + file_name + ".png")
	return image


func _difference(a: Image, b: Image) -> float:
	var total := 0.0
	var count := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += Vector3(ca.r - cb.r, ca.g - cb.g, ca.b - cb.b).length()
			count += 1
	return total / count


func _run() -> void:
	var map := load("res://map.tscn").instantiate() as Node3D
	root.add_child(map)
	await _frames(2)
	var leaves := map.get_node("树叶")
	_check(leaves.tree_count == 51, "地图全部 51 棵树均有树冠")
	_check(leaves.leaf_count > 10000, "生成真实叶片网格")
	_check(leaves.get_child_count() == 102, "每棵树各有一个树冠和稀疏落叶批次")
	print("LEAVES trees=", leaves.tree_count, " canopy_leaves=", leaves.leaf_count)
	var original_mesh: Mesh = map.find_children("树干*", "MeshInstance3D", true, false)[0].mesh
	var original_transform: Transform3D = leaves.get_child(0).global_transform
	_check(original_transform.is_equal_approx(map.find_children("树干*", "MeshInstance3D", true, false)[0].global_transform), "树冠继承导入树干的旋转和十倍缩放")
	var before: float = leaves.leaf_time
	paused = true
	await _frames()
	_check(is_equal_approx(leaves.leaf_time, before), "暂停冻结树叶与落叶时间")
	paused = false
	await _frames()
	_check(leaves.leaf_time > before, "恢复后继续动画")
	leaves.falling_leaves_per_tree = 0
	leaves.rebuild()
	await _frames(2)
	_check(leaves.get_child_count() == 51, "落叶数量设为零时仅保留树冠")
	map.free()
	if "--render" in OS.get_cmdline_user_args():
		await _render_preview(original_mesh)
		await _render_world()
	quit(0 if failures == 0 else 1)


func _render_preview(trunk_mesh: Mesh) -> void:
	root.size = Vector2i(960, 720)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var scene := Node3D.new()
	root.add_child(scene)
	var trunk := MeshInstance3D.new()
	trunk.name = "树干"
	trunk.mesh = trunk_mesh
	trunk.scale = Vector3.ONE * 10.0
	scene.add_child(trunk)
	var leaves := Leaves.new()
	leaves.trees_root_path = NodePath("..")
	scene.add_child(leaves)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.66, 0.75, 0.81)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.85, 0.92, 1.0)
	environment.environment.ambient_light_energy = 0.6
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	light.shadow_enabled = true
	scene.add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.39, 0.43, 0.30)
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	scene.add_child(ground)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.look_at_from_position(Vector3(27, 21, 33), Vector3(0, 14, 0))
	await _frames(8)
	leaves.set_process(false)
	leaves.get_child(1).hide()
	leaves.leaf_time = 0.0
	leaves._sync_materials()
	await _frames(4)
	var still := _capture("tree_breeze_0")
	leaves.leaf_time = 2.5
	leaves._sync_materials()
	await _frames(4)
	var moving := _capture("tree_breeze_2")
	var wind_difference := _difference(still, moving)
	print("LEAVES wind_image_difference=", wind_difference)
	_check(wind_difference > 0.0004, "GPU 渲染可见微风位移")
	leaves.get_child(1).show()
	leaves.wind_strength = 0.0
	leaves.leaf_time = 0.0
	leaves._sync_materials()
	await _frames(4)
	var fall_start := _capture("fall_0")
	leaves.leaf_time = 6.0
	leaves._sync_materials()
	await _frames(4)
	_check(_difference(fall_start, _capture("fall_6")) > 0.00002, "无风时仍有少量叶片独立下落")
	leaves.wind_strength = 0.0
	leaves.falling_leaves_per_tree = 0
	leaves.rebuild()
	await _frames(4)
	leaves.leaf_time = 0.0
	leaves._sync_materials()
	await _frames(4)
	var calm := _capture("tree_calm_0")
	leaves.leaf_time = 3.0
	leaves._sync_materials()
	await _frames(4)
	_check(_difference(calm, _capture("tree_calm_3")) < 0.0001, "风力为零且关闭落叶后画面静止")
	leaves.falling_leaves_per_tree = 4
	leaves.wind_strength = 0.18
	leaves.rebuild()
	await _frames(4)
	var palette := _capture("tree_preview")
	leaves.color_variation = 0.0
	leaves._sync_materials()
	await _frames(4)
	_check(_difference(palette, _capture("tree_uniform_color")) > 0.0001, "GPU 渲染可见稳定的轻微叶色差异")
	scene.free()


func _render_world() -> void:
	var world := load("res://世界场景.tscn").instantiate() as Node3D
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.look_at_from_position(Vector3(105, 89, -373), Vector3(81, 88, -322))
	await _frames(12)
	_capture("world_trees")
	_check(world.get_node("地图/map/树叶").tree_count == 51, "实际世界场景正确加载树冠")
	world.free()
