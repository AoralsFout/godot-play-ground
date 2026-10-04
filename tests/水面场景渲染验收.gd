extends SceneTree
## 运行命令：Godot --path . --script res://tests/水面场景渲染验收.gd
## 同时使用实际烘焙的 VoxelGI、水面材质、雾和阳光。


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var suffix := "_negative" if OS.get_cmdline_user_args().has("--negative-control") else ""
	var game := load("res://根节点.tscn").instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	game.get_node("世界场景/世界环境").set_process(false)
	# 比较岸线光照时，排除移动或动态加载的植被干扰。
	game.get_node("世界场景/草地").set_process(false)
	var avatar: CharacterBody3D = game.avatars[1]
	avatar.set_physics_process(false)
	avatar.global_position = Vector3(0, 15.8, 30)
	avatar.camera_pitch.rotation_degrees.x = -35.0
	game.water_material.set_shader_parameter("game_time", 2.0)
	if OS.get_cmdline_user_args().has("--negative-control"):
		var shader := Shader.new()
		shader.code = game.water_material.shader.code.replace(", ambient_light_disabled", "")
		game.water_material.shader = shader
		game.get_node("世界场景/水面").gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	for frame in 16:
		await process_frame
		await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://.godot/water_render")
	screenshot.save_png("res://.godot/water_render/world_after%s.png" % suffix)
	# 单独检查水面的全局光照（GI），排除折射或倒影中陆地的正常光照变化。
	game.get_node("世界场景/水面").reflections_enabled = false
	game.water_material.set_shader_parameter("absorption", Vector3.ONE * 1000.0)
	game.water_material.set_shader_parameter("shore_fade_distance", 0.001)
	game.water_material.set_shader_parameter("shallow_absorption", 1.0)
	game.water_material.set_shader_parameter("reflection_steps", 0)
	# 水面现在正常接收体积雾，雾中的 GI 光照属于预期效果。
	# 隔离材质 GI 时关闭体积雾，并排除浅水透明混合中海床的正常 GI。
	var environment: Environment = game.get_node("世界场景/世界环境").environment
	var volume_fog := environment.volumetric_fog_enabled
	environment.volumetric_fog_enabled = false
	for frame in 12:
		await process_frame
		await RenderingServer.frame_post_draw
	var gi_control := root.get_texture().get_image()
	# 固定波浪时间和太阳直射光，对比全局光照（GI）的开启与关闭效果。
	# 自然镜面闪光可能有硬像素边缘，这并非烘焙全局光照的不连续。
	game.get_node("世界场景/VoxelGI 全局光照").visible = false
	for frame in 16:
		await process_frame
		await RenderingServer.frame_post_draw
	var without_gi := root.get_texture().get_image()
	without_gi.save_png("res://.godot/water_render/world_without_gi%s.png" % suffix)
	var changed_pixels := 0
	var max_difference := 0.0
	for y in range(300, 620):
		for x in range(800, 1100):
			var color := gi_control.get_pixel(x, y)
			var other := without_gi.get_pixel(x, y)
			var difference := Vector3(color.r - other.r, color.g - other.g, color.b - other.b).length()
			max_difference = maxf(max_difference, difference)
			if difference > 0.025:
				changed_pixels += 1
	print("WORLD_WATER GI_max_color_difference=%.5f changed_pixels=%d" % [max_difference, changed_pixels])
	var passed := changed_pixels == 0
	print("RESULT world water: %s" % ("PASS" if passed else "FAIL two-color lighting boundary"))
	game.get_node("世界场景/VoxelGI 全局光照").visible = true
	environment.volumetric_fog_enabled = volume_fog
	game.get_node("世界场景/水面").reflections_enabled = true
	game.water_material.set_shader_parameter("absorption", null)
	game.water_material.set_shader_parameter("shore_fade_distance", null)
	game.water_material.set_shader_parameter("shallow_absorption", null)
	game.water_material.set_shader_parameter("reflection_steps", null)
	avatar.global_position = Vector3(12, 17.0, -10)
	avatar.camera_pitch.rotation_degrees.x = -18.0
	for frame in 16:
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/water_render/world_coast_after%s.png" % suffix)
	# 即使水面无法遮住地形的明暗变化，水外地形也必须保持连续。
	game.get_node("世界场景/水面").visible = false
	for frame in 12:
		await process_frame
		await RenderingServer.frame_post_draw
	var dry_coast := root.get_texture().get_image()
	dry_coast.save_png("res://.godot/water_render/world_coast_dry_after%s.png" % suffix)
	var coast_jump := 0.0
	for x in [960, 1000, 1040]:
		for y in range(410, 560):
			var a := dry_coast.get_pixel(x, y)
			var b := dry_coast.get_pixel(x, y + 1)
			coast_jump = maxf(coast_jump, Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length())
	print("WORLD_COAST dry_ground_max_neighbor_jump=%.5f" % coast_jump)
	passed = passed and coast_jump < 0.05
	# 倒影裁剪必须保留主视图中导入材质的原有效果。
	var ocean := game.get_node("世界场景/水面") as MeshInstance3D
	ocean.set_process(false)
	ocean._reflection_clip.restore()
	for frame in 12:
		await process_frame
		await RenderingServer.frame_post_draw
	var native_materials := root.get_texture().get_image()
	var material_error := 0.0
	for y in range(0, 680, 3):
		for x in range(0, 1100, 3):
			var a := dry_coast.get_pixel(x, y)
			var b := native_materials.get_pixel(x, y)
			material_error = maxf(material_error, Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length())
	print("WORLD_REFLECTION main_view_native_material_max_error=%.5f" % material_error)
	passed = passed and material_error < 0.015
	ocean._reflection_clip.setup(root, ocean.global_position.y + 0.02)
	ocean.set_process(true)
	game.get_node("世界场景/水面").visible = true
	avatar.global_position = Vector3(0, 11.0, 30)
	avatar.camera_pitch.rotation_degrees.x = -15.0
	for frame in 16:
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/water_render/world_underwater%s.png" % suffix)
	game.queue_free()
	await process_frame
	print("RESULT world coast: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
