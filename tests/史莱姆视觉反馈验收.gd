extends Node3D
var slime
var reflection_clip
var failures: Array[String] = []
func _ready() -> void:
	_run.call_deferred()
func capture(label: String) -> Image:
	reflection_clip.update(15.0)
	await RenderingServer.frame_post_draw
	var image: Image = $Viewport.get_texture().get_image()
	image.save_png("res://.godot/slime-feedback/" + label + ".png")
	return image
func mean_color(image: Image) -> Color:
	var sum := Color(0, 0, 0, 0)
	var count := 0
	for y in range(40, 220):
		for x in range(40, 220):
			var pixel := image.get_pixel(x, y)
			if maxf(pixel.r, pixel.g) > 0.04:
				sum += pixel
				count += 1
	return sum / maxf(count, 1)
func difference(a: Image, b: Image) -> float:
	var total := 0.0
	for y in range(40, 220):
		for x in range(40, 220):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += absf(ca.r-cb.r) + absf(ca.g-cb.g) + absf(ca.b-cb.b)
	return total / (180.0 * 180.0)
func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/slime-feedback")
	var viewport: SubViewport = $Viewport
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 1.0
	viewport.add_child(environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.4
	viewport.add_child(camera)
	camera.position = Vector3(0, 0.7, 4)
	camera.look_at(Vector3(0, 0.7, 0))
	slime = load("res://scenes/enemies/史莱姆.tscn").instantiate()
	viewport.add_child(slime)
	reflection_clip = load("res://scripts/world/海面倒影裁剪.gd").new()
	reflection_clip.setup(viewport, 15.0)
	reflection_clip.update(15.0)
	slime.set_physics_process(false)
	slime.animation_tree.active = false
	slime.health_bar.hide()
	slime._time = 0.825
	slime._update_color()
	var normal := await capture("normal")
	slime.set_selected(true)
	slime._time = 0.825
	slime._update_color()
	var low := await capture("selected-low")
	slime._time = 0.275
	slime._update_color()
	var high := await capture("selected-high")
	slime.take_damage(20)
	var hit := await capture("hit")
	slime._hurt_time = 0.0
	slime.set_selected(false)
	slime._update_color()
	var recovered := await capture("recovered")
	var recovery_difference := difference(normal, recovered)
	if recovery_difference > 0.002:
		failures.append("受击结束且取消选择后未恢复原色")
	if slime.health != slime.max_health - 20:
		failures.append("受击伤害未正确扣除")
	var hit_color := mean_color(hit)
	var pulse_difference := difference(low, high)
	if pulse_difference < 0.005:
		failures.append("选中闪烁未改变实际渲染像素")
	if hit_color.r <= hit_color.g * 1.2:
		failures.append("受击后实际渲染未变红")
	var materials := []
	for i in slime.body.mesh.get_surface_count():
		var material: Material = slime.body.get_active_material(i)
		materials.append({"surface":i,"name":material.resource_name,"class":material.get_class(),"override":slime.body.get_surface_override_material(i) != null,"same_as_tinted":material == slime._body_material,"color":str(material.get("albedo_color"))})
	reflection_clip.restore()
	if slime.body.get_active_material(0) != slime._body_material:
		failures.append("关闭倒影裁剪后未还原源材质")
	var report := {"recovery_difference":recovery_difference,"failures":failures,"pulse_difference":pulse_difference,"normal_color":str(mean_color(normal)),"hit_color":str(hit_color),"materials":materials}
	var file := FileAccess.open("res://.godot/slime-feedback/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("史莱姆视觉反馈验收: ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
