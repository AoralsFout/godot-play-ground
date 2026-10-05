extends SceneTree
var viewport: SubViewport
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _capture(label: String) -> Image:
	for frame in 10:
		await process_frame
		await RenderingServer.frame_post_draw
	var picture := viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://.godot/water_render")
	picture.save_png("res://.godot/water_render/" + label + ".png")
	return picture

func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

func _check(condition: bool, label: String, value: float) -> void:
	print("COAST %s value=%.5f %s" % [label, value, "PASS" if condition else "FAIL"])
	if not condition:
		failures += 1
		push_error("FAIL " + label)

func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 480)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.65, 0.78, 0.94)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.65
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment.tonemap_exposure = 0.85
	viewport.add_child(world)
	var bed := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	bed.mesh = plane
	bed.rotation_degrees.x = 8.0
	bed.position.y = -0.3
	var sand := StandardMaterial3D.new()
	sand.albedo_color = Color(0.78, 0.69, 0.47)
	sand.roughness = 1.0
	bed.material_override = sand
	viewport.add_child(bed)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.1
	viewport.add_child(sun)
	var water := MeshInstance3D.new()
	var water_plane := PlaneMesh.new()
	water_plane.size = Vector2(80, 80)
	water.mesh = water_plane
	water.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/water/水面.gdshader")
	material.set_shader_parameter("wave_height", 0.0)
	material.set_shader_parameter("use_game_time", true)
	material.set_shader_parameter("game_time", 2.0)
	water.material_override = material
	viewport.add_child(water)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 2, -9)
	camera.look_at_from_position(camera.position, Vector3(0, -0.3, 2))
	viewport.add_child(camera)
	camera.make_current()
	water.visible = false
	var dry := await _capture("coast_dry")
	water.visible = true
	material.set_shader_parameter("transparency", 1.0)
	var clear := await _capture("coast_zero_water")
	var max_error := 0.0
	for y in range(160, 450):
		for x in range(30, 610):
			max_error = maxf(max_error, _distance(dry.get_pixel(x, y), clear.get_pixel(x, y)))
	_check(max_error < 0.015, "zero-depth water reproduces lit sand without a compositing seam", max_error)
	material.set_shader_parameter("transparency", 0.5)
	# 排除物理上尖锐的镜面闪光干扰，单独检查岸线的光照传递。
	material.set_shader_parameter("highlight_strength", 0.0)
	material.set_shader_parameter("foam_strength", 0.0)
	material.set_shader_parameter("reflection_strength", 0.0)
	material.set_shader_parameter("refraction_strength", 0.0)
	var coast := await _capture("coast_shallow")
	var max_jump := 0.0
	for y in range(238, 300):
		max_jump = maxf(max_jump, _distance(coast.get_pixel(320, y), coast.get_pixel(320, y + 1)))
	_check(max_jump < 0.055, "oblique sloping shoreline has no hard step", max_jump)
	# 使用新的浅水吸收效果后，一米深的海床颜色应更接近原本的沙色。
	bed.rotation = Vector3.ZERO
	bed.position.y = -1.0
	sun.light_energy = 1.0
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.0
	camera.position = Vector3(0, 8, 0)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	water.visible = false
	var sand_reference := await _capture("coast_sand_reference")
	water.visible = true
	var shallow := await _capture("coast_clear_shallow")
	material.set_shader_parameter("absorption", Vector3(0.32, 0.095, 0.055))
	material.set_shader_parameter("shallow_absorption", 1.0)
	var dense := await _capture("coast_dense_reference")
	var shallow_error := _distance(shallow.get_pixel(320, 240), sand_reference.get_pixel(320, 240))
	var dense_error := _distance(dense.get_pixel(320, 240), sand_reference.get_pixel(320, 240))
	_check(shallow_error < dense_error * 0.75, "shallow water preserves more of the sand color", shallow_error / maxf(dense_error, 0.001))
	water.queue_free()
	await process_frame
	bed.position.y = -8.0
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.position = Vector3(0, 2, -9)
	camera.look_at(Vector3(0, 0, 3))
	var mirror_water := preload("res://scripts/world/水面.gd").new()
	var mirror_material := ShaderMaterial.new()
	mirror_material.shader = load("res://shaders/water/水面.gdshader")
	mirror_material.set_shader_parameter("wave_height", 0.0)
	mirror_material.set_shader_parameter("use_game_time", true)
	mirror_material.set_shader_parameter("game_time", 2.0)
	mirror_material.set_shader_parameter("reflection_steps", 0)
	mirror_material.set_shader_parameter("refraction_strength", 0.0)
	mirror_material.set_shader_parameter("highlight_strength", 0.0)
	mirror_water.water_material = mirror_material
	viewport.add_child(mirror_water)
	var object := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2, 3, 2)
	object.mesh = box
	object.position = Vector3(0, 2, 4)
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(1, 0.015, 0.01)
	object.material_override = red
	viewport.add_child(object)
	mirror_water.reflections_enabled = false
	var no_mirror := await _capture("coast_mirror_off")
	mirror_water.reflections_enabled = true
	var mirror := await _capture("coast_mirror_on")
	var reflected_pixels := 0
	for y in range(260, 450):
		for x in range(220, 420):
			var color := mirror.get_pixel(x, y)
			if color.r - color.g > 0.12 and _distance(color, no_mirror.get_pixel(x, y)) > 0.08:
				reflected_pixels += 1
	_check(reflected_pixels > 150, "above-water object has a visible planar reflection with SSR disabled", float(reflected_pixels))
	var mirror_camera := mirror_water.get_node("OceanReflection").get_camera_3d() as Camera3D
	_check((mirror_camera.cull_mask & mirror_water.layers) == 0, "mirror camera excludes the water to avoid feedback", float(mirror_camera.cull_mask & mirror_water.layers))
	# 这些表面位于水下的倒影摄像机与水面平面之间。
	# 普通摄像机的近裁剪平面会保留这些表面，产生悬浮的前景重影。
	var submerged := MeshInstance3D.new()
	var submerged_box := BoxMesh.new()
	submerged_box.size = Vector3(4, 1, 2)
	submerged.mesh = submerged_box
	submerged.position = Vector3(0, -1.3, -1)
	var green := StandardMaterial3D.new()
	green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	green.albedo_color = Color(0.01, 1, 0.01)
	submerged.material_override = green
	viewport.add_child(submerged)
	await _capture("coast_submerged_foreground")
	var reflection_viewport := mirror_water.get_node("OceanReflection") as SubViewport
	var foreground := reflection_viewport.get_texture().get_image()
	foreground.save_png("res://.godot/water_render/reflection_foreground.png")
	var ghost_pixels := 0
	for y in foreground.get_height():
		for x in foreground.get_width():
			var color := foreground.get_pixel(x, y)
			if color.g - maxf(color.r, color.b) > 0.3:
				ghost_pixels += 1
	_check(ghost_pixels == 0, "submerged foreground cannot enter the planar reflection", float(ghost_pixels))
	# 跨越水面平面的网格必须只保留水面以上的部分。
	submerged.position = Vector3(-3, 0, 4)
	submerged_box.size = Vector3(2, 4, 2)
	await _capture("coast_crossing_object")
	var crossing := reflection_viewport.get_texture().get_image()
	var crossing_pixels := 0
	var below_plane_pixels := 0
	for y in crossing.get_height():
		for x in crossing.get_width():
			var color := crossing.get_pixel(x, y)
			if color.g - maxf(color.r, color.b) > 0.3:
				crossing_pixels += 1
				var ray_origin := mirror_camera.project_ray_origin(Vector2(x + 0.5, y + 0.5))
				var ray := mirror_camera.project_ray_normal(Vector2(x + 0.5, y + 0.5))
				# 最近的箱体表面位于 z=3；对于这些光线，z=5 的背面也在水面以下。
				if ray.z > 0.0 and (ray_origin + ray * ((5.0 - ray_origin.z) / ray.z)).y < -0.05:
					below_plane_pixels += 1
	_check(crossing_pixels > 100 and below_plane_pixels == 0, "crossing mesh keeps its dry half and clips its submerged half", float(below_plane_pixels))
	viewport.queue_free()
	await process_frame
	var world_scene := load("res://scenes/world/世界场景.tscn").instantiate() as Node3D
	root.add_child(world_scene)
	var map_water := world_scene.get_node("地图水面") as MeshInstance3D
	_check(map_water.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and map_water.gi_mode == GeometryInstance3D.GI_MODE_DISABLED, "minimap proxy cannot cast an invisible roof shadow or enter GI baking", float(map_water.cast_shadow))
	world_scene.queue_free()
	await process_frame
	print("RESULT coast: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
