extends SceneTree
## 使用实际 Forward+ 渲染进行像素对比：折射、水面阴影和摄像机浸水效果。
var viewport: SubViewport
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _capture(label: String) -> Image:
	for frame in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://.godot/water_render")
	image.save_png("res://.godot/water_render/" + label + ".png")
	return image

func _difference(a: Image, b: Image, region := Rect2i(40, 40, 432, 432)) -> float:
	var total := 0.0
	for y in range(region.position.y, region.end.y, 2):
		for x in range(region.position.x, region.end.x, 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += Vector3(ca.r - cb.r, ca.g - cb.g, ca.b - cb.b).length()
	return total / float(region.get_area() / 4)

func _check(condition: bool, label: String, difference: float) -> void:
	print("OCEAN %s difference=%.5f %s" % [label, difference, "PASS" if condition else "FAIL"])
	if not condition:
		failures += 1
		push_error("FAIL " + label)

func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.6, 0.75, 0.9)
	viewport.add_child(environment)
	var bed := MeshInstance3D.new()
	var bed_mesh := PlaneMesh.new()
	bed_mesh.size = Vector2(100, 100)
	bed.mesh = bed_mesh
	bed.position.y = -4
	var pattern := ShaderMaterial.new()
	var pattern_shader := Shader.new()
	pattern_shader.code = "shader_type spatial; render_mode unshaded, cull_disabled; void fragment() { float c = mod(floor(UV.x * 100.0) + floor(UV.y * 100.0), 2.0); ALBEDO = mix(vec3(0.15, 0.12, 0.06), vec3(0.8, 0.72, 0.5), c); }"
	pattern.shader = pattern_shader
	bed.material_override = pattern
	viewport.add_child(bed)
	var water := preload("res://水面.gd").new()
	var material := ShaderMaterial.new()
	material.shader = load("res://水面.gdshader")
	material.set_shader_parameter("use_game_time", true)
	material.set_shader_parameter("game_time", 2.0)
	water.water_material = material
	viewport.add_child(water)
	material = water.get_active_material(0)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14
	camera.position = Vector3(0, 12, 0)
	camera.rotation_degrees.x = -90
	viewport.add_child(camera)
	camera.make_current()
	material.set_shader_parameter("refraction_strength", 0.0)
	var straight := await _capture("ocean_no_refraction")
	material.set_shader_parameter("refraction_strength", 0.035)
	var refracted := await _capture("ocean_refraction")
	var difference := _difference(straight, refracted)
	_check(difference > 0.01, "underwater geometry refracts", difference)
	# 海床使用无光照材质，只有水面实际接收到的阴影才能改变像素。
	var blocker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3, 0.5, 3)
	blocker.mesh = box
	blocker.position = Vector3(0, 4, 0)
	viewport.add_child(blocker)
	material.set_shader_parameter("wave_height", 0.0)
	sun.shadow_enabled = false
	var lit := await _capture("ocean_shadow_off")
	sun.shadow_enabled = true
	var shadowed := await _capture("ocean_shadow_on")
	difference = _difference(lit, shadowed, Rect2i(305, 135, 60, 60))
	_check(difference > 0.04, "shadow falls on water above unshaded bed", difference)
	blocker.queue_free()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	water.underwater_enabled = false
	bed.visible = false
	camera.position = Vector3(0, -2, 0)
	camera.rotation_degrees = Vector3(90, 0, 0)
	camera.fov = 110
	var window := await _capture("ocean_snell_window")
	var center := window.get_pixel(256, 256)
	var edge := window.get_pixel(20, 20)
	var window_contrast := center.get_luminance() - edge.get_luminance()
	_check(window_contrast > 0.15, "sky visible through Snell window with internal reflection at edges", window_contrast)
	bed.visible = true
	camera.fov = 75
	camera.position = Vector3(0, -1.5, 8)
	camera.look_at(Vector3(0, -2, 0))
	water.underwater_enabled = false
	var dry := await _capture("ocean_underwater_disabled")
	water.underwater_enabled = true
	var wet := await _capture("ocean_underwater")
	difference = _difference(dry, wet)
	_check(difference > 0.04, "immersed camera sees absorption and underwater fog", difference)
	_check(camera.environment != null and camera.environment.fog_enabled, "underwater camera owns distance fog", 1.0)
	water.underwater_enabled = false
	await _capture("ocean_exit_disabled")
	_check(camera.environment == null, "disabling effect restores original camera environment", 0.0)
	water.underwater_enabled = true
	camera.position.y = 2.0
	await _capture("ocean_above_again")
	_check(camera.environment == null, "surfacing restores original camera environment", 0.0)
	camera.position.y = -1.5
	await _capture("ocean_submerged_again")
	# 俯视小地图不能继承主摄像机的水下效果。
	camera.cull_mask = 2
	var minimap := await _capture("ocean_minimap")
	water.underwater_enabled = false
	var minimap_clear := await _capture("ocean_minimap_clear")
	difference = _difference(minimap, minimap_clear)
	_check(difference < 0.001, "minimap excludes underwater overlay", difference)
	_check(camera.environment == null, "camera mask change restores original environment", 0.0)
	viewport.queue_free()
	await process_frame
	print("RESULT ocean: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
