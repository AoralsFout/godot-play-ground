extends SceneTree
## 运行命令：Godot --path . --script res://tests/水面场景渲染验收.gd
## 使用实际大地形、水面材质、雾和阳光，检查倒影裁剪不改变主视图材质。


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := load("res://scenes/根节点.tscn").instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	game.get_node("世界场景/世界环境").set_process(false)
	var avatar: CharacterBody3D = game.avatars[1]
	avatar.set_physics_process(false)
	avatar.global_position = Vector3(0, 15.8, 30)
	avatar.camera_pitch.rotation_degrees.x = -35.0
	game.water_material.set_shader_parameter("game_time", 2.0)
	for frame in 16:
		await process_frame
		await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://.godot/water_render")
	screenshot.save_png("res://.godot/water_render/world_after.png")
	var passed := true
	avatar.global_position = Vector3(12, 17.0, -10)
	avatar.camera_pitch.rotation_degrees.x = -18.0
	for frame in 16:
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/water_render/world_coast_after.png")
	# 隐藏海面以隔离主视图材质，比较倒影裁剪启用和恢复后的画面。
	game.get_node("世界场景/水面").visible = false
	for frame in 12:
		await process_frame
		await RenderingServer.frame_post_draw
	var dry_coast := root.get_texture().get_image()
	dry_coast.save_png("res://.godot/water_render/world_coast_dry_after.png")
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
	root.get_texture().get_image().save_png("res://.godot/water_render/world_underwater.png")
	game.queue_free()
	await process_frame
	print("RESULT world coast: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
