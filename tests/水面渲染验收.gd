extends SceneTree
## 使用实际图形渲染器运行：Godot --path . --script res://tests/水面渲染验收.gd
## 浅水平坦海床与静止波浪相交，用于暴露岸线不透明度的突变。

var viewport: SubViewport
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.7, 0.6, 0.4)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	viewport.add_child(environment)
	var bed := MeshInstance3D.new()
	var bed_mesh := PlaneMesh.new()
	bed_mesh.size = Vector2(80, 80)
	bed.mesh = bed_mesh
	bed.position.y = -0.05
	var sand := StandardMaterial3D.new()
	sand.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sand.albedo_color = Color(0.7, 0.6, 0.4)
	bed.material_override = sand
	viewport.add_child(bed)
	var water := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(40, 40)
	mesh.subdivide_width = 399
	mesh.subdivide_depth = 399
	water.mesh = mesh
	var shader := Shader.new()
	# 此测试场景不使用直射光，以测量实际合成着色器的岸线效果。
	# 无光照模式会绕过透射与自发光的分离处理，从而改变材质效果。
	shader.code = FileAccess.get_file_as_string("res://水面.gdshader")
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("use_game_time", true)
	material.set_shader_parameter("game_time", 2.0)
	material.set_shader_parameter("wave_height", 0.258)
	# 用较高吸收隔离岸线覆盖率；清浅水不再靠重复照明制造深色边界。
	material.set_shader_parameter("absorption", Vector3.ONE * 2.0)
	material.set_shader_parameter("shore_fade_distance", 0.4)
	water.material_override = material
	viewport.add_child(water)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.0
	camera.position = Vector3(0, 8, 0)
	camera.rotation_degrees.x = -90
	viewport.add_child(camera)
	camera.make_current()
	await _capture("shore_top")
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 45.0
	camera.position = Vector3(0, 8, 8)
	camera.look_at(Vector3.ZERO)
	await _capture("shore_oblique")
	# 仅禁用波浪细节层级（LOD）时，平坦浅水海床应保持原有颜色。
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 8, 0)
	camera.rotation_degrees.x = -90
	bed.position.y = -0.3
	material.set_shader_parameter("wave_height", 0.0)
	material.set_shader_parameter("highlight_strength", 0.0)
	var near_image := await _capture("shallow_full_detail", false)
	material.set_shader_parameter("use_distance_lod", true)
	material.set_shader_parameter("wave_full_distance", 1.0)
	material.set_shader_parameter("wave_end_distance", 2.0)
	var far_image := await _capture("shallow_no_detail", false)
	var near_color := near_image.get_pixel(420, 256)
	var far_color := far_image.get_pixel(420, 256)
	var lod_jump := Vector3(near_color.r - far_color.r, near_color.g - far_color.g, near_color.b - far_color.b).length()
	print("SHALLOW_LOD color_difference=%.5f" % lod_jump)
	if lod_jump > 0.015:
		failures += 1
		push_error("FAIL distant shallow water changed color when wave detail stopped")
	# 向上观察时，无论背景是天空还是不透明几何体，都必须显示水面底面。
	# 正视水面仅反射约 2%，用斜视角检查全内反射，而非要求正视天空变暗。
	camera.fov = 110.0
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	material.set_shader_parameter("use_distance_lod", false)
	bed.visible = false
	camera.position = Vector3(0, -8, 0)
	camera.rotation_degrees.x = 90
	for backdrop in ["sky", "geometry"]:
		if backdrop == "geometry":
			bed.visible = true
			bed.position.y = 4.0
			sand.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.set_shader_parameter("transparency", 1.0)
		var clear_image := await _capture("underwater_%s_clear" % backdrop, false)
		material.set_shader_parameter("transparency", 0.5)
		var water_image := await _capture("underwater_%s" % backdrop, false)
		var clear_color := clear_image.get_pixel(20, 20)
		var water_color := water_image.get_pixel(20, 20)
		var visibility := Vector3(water_color.r - clear_color.r, water_color.g - clear_color.g, water_color.b - clear_color.b).length()
		print("UNDERWATER %s color_difference=%.5f" % [backdrop, visibility])
		if visibility < 0.05:
			failures += 1
			push_error("FAIL underwater surface is invisible against %s" % backdrop)
	print("RESULT water rendering: %s" % ("PASS" if failures == 0 else "FAIL shoreline or underwater visibility"))
	viewport.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _capture(label: String, check_edges := true) -> Image:
	for frame in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	var screenshot := viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://.godot/water_render")
	screenshot.save_png("res://.godot/water_render/%s.png" % label)
	if not check_edges:
		return screenshot
	var max_jump := 0.0
	var hard_edges := 0
	var water_pixels := 0
	var sand_color := screenshot.get_pixel(2, 2)
	for y in range(2, 510):
		for x in range(2, 510):
			var color := screenshot.get_pixel(x, y)
			if Vector3(color.r - sand_color.r, color.g - sand_color.g, color.b - sand_color.b).length() > 0.02:
				water_pixels += 1
			for next in [screenshot.get_pixel(x + 1, y), screenshot.get_pixel(x, y + 1)]:
				var jump := Vector3(color.r - next.r, color.g - next.g, color.b - next.b).length()
				max_jump = maxf(max_jump, jump)
				if jump > 0.08:
					hard_edges += 1
	print("SHORE %s max_neighbor_color_jump=%.5f hard_edges=%d water_pixels=%d" % [label, max_jump, hard_edges, water_pixels])
	if hard_edges > 0 or water_pixels < 1000:
		failures += 1
		push_error("FAIL %s: shoreline must be smooth and water must remain visible" % label)
	return screenshot
