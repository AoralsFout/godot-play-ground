extends SceneTree
## --headless --script res://tests/天空光照验收.gd：光照与昼夜验收。
## 正常图形运行并追加 -- --visual：真实海岛截图与亮度验收。

const OUTPUT := "res://.godot/sky_render/"
var failures := 0
var visual := false
var sky: WorldEnvironment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var camera: Camera3D


func _initialize() -> void:
	visual = "--visual" in OS.get_cmdline_user_args()
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	print("%s %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		failures += 1


func _frames(count := 8) -> void:
	for frame in count:
		await process_frame
		if visual:
			await RenderingServer.frame_post_draw


func _angle(elevation: float, evening := true) -> void:
	sun.rotation_degrees = Vector3(-180.0 + elevation if evening else -elevation, 0.0, 0.0)
	# 即使云动画停用，也执行角度检测，与编辑器静止预览使用同一路径。
	sky._process(0.0)
	if camera != null:
		var toward := sun.global_basis.z.normalized()
		camera.look_at(camera.global_position + Vector3(toward.x, 0.12, toward.z))


func _capture(name: String) -> Image:
	var result := root.get_texture().get_image()
	result.save_png(OUTPUT + name + ".png")
	return result


func _brightness(picture: Image, area: Rect2i) -> float:
	var total := 0.0
	var count := 0
	for y in range(area.position.y, area.end.y, 6):
		for x in range(area.position.x, area.end.x, 6):
			var pixel := picture.get_pixel(x, y)
			total += pixel.get_luminance()
			count += 1
	return total / count


func _run() -> void:
	var world: Node3D
	if visual:
		root.size = Vector2i(1280, 720)
		DirAccess.make_dir_recursive_absolute(OUTPUT)
		world = load("res://世界场景.tscn").instantiate() as Node3D
	else:
		world = Node3D.new()
		var environment := WorldEnvironment.new()
		environment.name = "世界环境"
		environment.set_script(load("res://体积云.gd"))
		world.add_child(environment)
		var daylight := DirectionalLight3D.new()
		daylight.name = "日光"
		world.add_child(daylight)
		var moonlight := DirectionalLight3D.new()
		moonlight.name = "月光"
		moonlight.rotation_degrees = Vector3(-25.0, 160.0, 0.0)
		world.add_child(moonlight)
		var water := MeshInstance3D.new()
		water.name = "水面"
		water.mesh = PlaneMesh.new()
		var material := ShaderMaterial.new()
		material.shader = load("res://水面.gdshader")
		water.mesh.material = material
		world.add_child(water)
		var gi := VoxelGI.new()
		gi.name = "VoxelGI 全局光照"
		gi.data = VoxelGIData.new()
		world.add_child(gi)
	var gi := world.get_node("VoxelGI 全局光照") as VoxelGI
	var source_gi := gi.data
	var source_energy := source_gi.energy
	root.add_child(world)
	current_scene = world
	sky = world.get_node("世界环境")
	sun = world.get_node("日光")
	moon = world.get_node("月光")
	sky.set_process(false)
	_check(gi.data == source_gi if Engine.is_editor_hint() else gi.data != source_gi,
		"GI preserves editor resource reference and isolates runtime worlds")
	sky.clouds_enabled = false
	if visual:
		camera = Camera3D.new()
		world.add_child(camera)
		camera.global_position = Vector3(20.0, 26.0, 50.0)
		camera.current = true
		var noise: NoiseTexture3D = sky.cloud_material.get_shader_parameter("cloud_noise")
		var deadline := Time.get_ticks_msec() + 20000
		while noise.get_data().is_empty() and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(not noise.get_data().is_empty(), "volume noise ready")

	_angle(40.0)
	var clear_energy := sun.light_energy
	var clear_ambient := sky.environment.ambient_light_energy
	_check(clear_energy > 1.0 and sky.sky_phase == "晴天", "high sun produces daylight")
	_check(is_zero_approx(moon.light_energy), "moonlight fades out in daytime")
	var original_moon_rotation := moon.rotation
	var phases := [[2.0, "日落"], [-4.0, "晚霞"], [-9.0, "蓝调时刻"], [-20.0, "夜晚"]]
	var day_zenith: Color = sky.cloud_material.get_shader_parameter("zenith_color")
	for phase in phases:
		_angle(phase[0])
		_check(sky.sky_phase == phase[1], "angle selects " + phase[1])
	_check(is_zero_approx(sun.light_energy), "sun below horizon cannot light ground")
	var night_zenith: Color = sky.cloud_material.get_shader_parameter("zenith_color")
	_check(night_zenith.get_luminance() < day_zenith.get_luminance() * 0.25, "moonlit sky retains night contrast")
	_check(sky.environment.ambient_light_energy > 0.04 and sky.environment.ambient_light_energy < 0.2, "moon provides gentle night ambient fill")
	_check(moon.light_energy > 0.1 and moon.light_energy < clear_energy * 0.3, "moon provides weak directional night illumination")
	_check(moon.rotation.is_equal_approx(original_moon_rotation), "changing sun angle never rotates moon")
	var fixed_sun := sun.global_basis.z
	moon.rotation_degrees = Vector3(-50.0, 100.0, 0.0)
	sky._process(0.0)
	var lunar_direction: Vector3 = sky.cloud_material.get_shader_parameter("sky_moon_direction")
	_check(lunar_direction.is_equal_approx(moon.global_basis.z.normalized()), "independent moon rotation updates sky disk")
	_check(sun.global_basis.z.is_equal_approx(fixed_sun), "moving moon leaves sun direction unchanged")
	var clear_moonlight := moon.light_energy
	sky.clouds_enabled = true
	sky.cloud_coverage = 1.0
	sky.cloud_density = 2.0
	_check(moon.light_energy < clear_moonlight * 0.2, "thick clouds attenuate moonlight")
	sky.clouds_enabled = false
	moon.rotation_degrees.x = 20.0
	sky._process(0.0)
	_check(is_zero_approx(moon.light_energy) and is_zero_approx(float(sky.cloud_material.get_shader_parameter("moon_visibility"))), "moon below horizon cannot illuminate scene")
	moon.rotation = original_moon_rotation
	moon.hide()
	sky._process(0.0)
	_check(is_zero_approx(moon.light_energy) and sky.environment.ambient_light_energy <= 0.04, "hiding moon removes lunar lighting")
	moon.show()
	sky._process(0.0)
	sky.moon_enabled = false
	_check(is_zero_approx(moon.light_energy), "moon can be disabled in sky controller")
	sky.moon_enabled = true
	sky.cloud_coverage = 0.56
	sky.cloud_density = 1.1
	_check(is_equal_approx(source_gi.energy, source_energy), "day-night updates do not modify shared baked GI resource")
	if not Engine.is_editor_hint():
		_check(gi.data.energy > 0.0 and gi.data.energy <= source_energy * 0.3, "night GI retains only gentle lunar bounce")
	_angle(2.0, false)
	_check(sky.sky_phase == "日出", "opposite solar azimuth selects sunrise")
	var dawn: Color = sky.cloud_material.get_shader_parameter("horizon_color")
	_angle(2.0)
	var dusk: Color = sky.cloud_material.get_shader_parameter("horizon_color")
	_check(not dawn.is_equal_approx(dusk), "dawn and dusk have different palettes")
	sky.twilight_style = 1
	_check(sky.sky_phase == "日出", "manual dawn style overrides azimuth")
	sky.twilight_style = 0
	for height in [-18.0, -10.0, -5.0, 0.0, 7.0, 25.0]:
		_angle(height - 0.01)
		var before: Color = sky.cloud_material.get_shader_parameter("zenith_color")
		_angle(height + 0.01)
		var after: Color = sky.cloud_material.get_shader_parameter("zenith_color")
		_check(Vector3(before.r - after.r, before.g - after.g, before.b - after.b).length() < 0.005,
			"continuous palette at %.0f degrees" % height)

	_angle(40.0)
	sky.clouds_enabled = true
	sky.cloud_coverage = 1.0
	sky.cloud_density = 2.0
	var thick_energy := sun.light_energy
	_check(thick_energy < clear_energy * 0.20, "thick clouds strongly attenuate sunlight")
	_check(sky.environment.ambient_light_energy < clear_ambient * 0.6, "cloud cover dims ambient light")
	sky.cloud_coverage = 0.5
	_check(sun.light_energy > thick_energy and sun.light_energy < clear_energy, "partial clouds give intermediate illumination")
	var thin_energy := sun.light_energy
	sky.cloud_thickness = 320.0
	_check(sun.light_energy < thin_energy, "thicker cloud layer reduces transmitted sunlight")
	sky.cloud_thickness = 160.0
	sky.cloud_density = 0.0
	_check(is_equal_approx(sun.light_energy, clear_energy), "zero density restores clear illumination")
	sky.cloud_density = 2.0
	sky.cloud_light_influence = 0.0
	_check(is_equal_approx(sun.light_energy, clear_energy), "cloud lighting influence can be disabled")
	sky.cloud_light_influence = 1.0
	sky.clouds_enabled = false
	_check(is_equal_approx(sun.light_energy, clear_energy), "disabled clouds restore sunlight")
	var water := world.get_node("水面") as MeshInstance3D
	var replacement := water.get_active_material(0).duplicate() as ShaderMaterial
	water.set_surface_override_material(0, replacement)
	_angle(-9.0)
	_check(replacement.get_shader_parameter("sky_horizon") == sky.cloud_material.get_shader_parameter("horizon_color"),
		"replaced water material follows blue hour sky")
	sun.hide()
	sky._process(0.0)
	_check(is_zero_approx(float(sky.cloud_material.get_shader_parameter("sun_visibility"))), "hidden sun removes visible solar disk")
	sun.show()
	sky._process(0.0)

	if visual:
		sky.cloud_density = 1.1
		sky.cloud_coverage = 0.56
		sky.clouds_enabled = true
		sky.cloud_material.set_shader_parameter("cloud_time", 12.0)
		for sample in [[40.0, false, "day"], [2.0, false, "sunrise"], [2.0, true, "sunset"], [-4.0, true, "afterglow"], [-9.0, true, "blue_hour"], [-20.0, true, "night"]]:
			_angle(sample[0], sample[1])
			await _frames(16)
			_capture(sample[2])
		_angle(-20.0)
		# 同一视角与风场对比月光，避免把相机方向变化误认为照明变化。
		var moon_direction := moon.global_basis.z.normalized()
		camera.look_at(camera.global_position + Vector3(moon_direction.x, 0.12, moon_direction.z))
		sky.clouds_enabled = false
		await _frames(16)
		var moonlit := _capture("moonlit_night")
		sky.moon_enabled = false
		await _frames(16)
		var moonless := _capture("moonless_night")
		var lunar_ground := Rect2i(40, 480, 1200, 200)
		print("MOON brightness on=", _brightness(moonlit, lunar_ground), " off=", _brightness(moonless, lunar_ground))
		_check(_brightness(moonlit, lunar_ground) > _brightness(moonless, lunar_ground) + 0.015, "moonlight visibly brightens real island and sea")
		sky.moon_enabled = true
		sky.clouds_enabled = true
		sky.cloud_coverage = 1.0
		sky.cloud_density = 2.0
		await _frames(16)
		var clouded_moon := _capture("moon_overcast")
		_check(_brightness(clouded_moon, lunar_ground) < _brightness(moonlit, lunar_ground) * 0.8, "clouds dim rendered lunar illumination")
		_angle(40.0, false)
		sky.clouds_enabled = false
		await _frames(16)
		var clear := _capture("clear_day")
		sky.clouds_enabled = true
		sky.cloud_coverage = 1.0
		sky.cloud_density = 2.0
		await _frames(16)
		var overcast := _capture("overcast")
		var sky_area := Rect2i(40, 30, 1200, 250)
		var ground_area := Rect2i(40, 460, 1200, 220)
		print("BRIGHTNESS sky clear=", _brightness(clear, sky_area), " overcast=", _brightness(overcast, sky_area))
		print("BRIGHTNESS ground clear=", _brightness(clear, ground_area), " overcast=", _brightness(overcast, ground_area))
		_check(_brightness(overcast, sky_area) < _brightness(clear, sky_area) * 0.8, "rendered overcast sky is darker")
		_check(_brightness(overcast, ground_area) < _brightness(clear, ground_area) * 0.8, "rendered ground and water are darker")
	else:
		sky.animate_in_editor = true
		sky.set_process(true)
		await _frames(2)
		paused = true
		var frozen: float = sky.cloud_time
		await _frames(4)
		_check(is_equal_approx(sky.cloud_time, frozen), "pause freezes cloud animation")
		paused = false
		await _frames(2)
		_check(sky.cloud_time > frozen, "cloud animation resumes")
	print("RESULT sky lighting: %s" % ("PASS" if failures == 0 else "FAIL"))
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
