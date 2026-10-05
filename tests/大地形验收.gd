extends SceneTree
## --headless --script res://tests/大地形验收.gd；GPU 截图：去掉 --headless，末尾加 -- --render。

var failures := 0
var render_preview := false
const OUTPUT := "res://.godot/terrain_render/"


func _initialize() -> void:
	render_preview = "--render" in OS.get_cmdline_user_args()
	_run.call_deferred()


func _check(ok: bool, description: String) -> void:
	print("TERRAIN %s %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _frames(count: int = 3) -> void:
	for frame in count:
		await process_frame
		if render_preview:
			await RenderingServer.frame_post_draw


func _run() -> void:
	var game := load("res://scenes/根节点.tscn").instantiate() as Node3D
	root.add_child(game)
	await _frames()
	var world := game.get_node("世界场景")
	var map := world.get_node("地图")
	var terrain := map.get_node("超大地形")
	var chunks := terrain.find_children("地形块_*", "MeshInstance3D", true, false)
	_check(chunks.size() == 64, "实际游戏场景加载 64 个中文地形块")
	var materials_valid := true
	for chunk: MeshInstance3D in chunks:
		materials_valid = materials_valid and chunk.material_override == map.terrain_material and chunk.layers == 3
	_check(materials_valid, "所有分块共享新着色器并在主视图、小地图可见")
	_check(terrain.find_children("*", "StaticBody3D", true, false).size() == 111, "保留全部 111 个模型静态碰撞体")
	_check(not map.has_node("树林") and not world.has_node("草地"), "移除未使用的植被节点")
	_check(not world.has_node("VoxelGI 全局光照"), "移除旧地形体素烘焙节点")
	var water := world.get_node("水面") as MeshInstance3D
	_check(is_equal_approx(water.global_position.y, 15.0) and is_equal_approx(world.get_node("地图水面").global_position.y, 15.0), "两套海面高度都保持 15 米")
	_check(water.water_size == Vector2(8200,8200) and world.get_node("地图水面").mesh.size == Vector2(8200,8200), "真实海面和小地图海面覆盖新地形")
	_check(water.custom_aabb.size == Vector3(8200,6,8200) and water.get_active_material(0).get_shader_parameter("water_half_size") == Vector2(4100,4100), "海面包围盒和着色参数同步扩展")
	water.position.y = 16.0
	await _frames()
	_check(is_equal_approx(map.terrain_material.get_shader_parameter("sea_level"),16.0), "地形湿沙带跟随实际海面高度")
	water.position.y = 15.0
	await physics_frame
	await physics_frame
	var space := game.get_world_3d().direct_space_state
	for sample in [Vector2(-3500,3500),Vector2(3500,-3500),Vector2(1800,-1800),Vector2(0,0)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(sample.x,2000,sample.y),Vector3(sample.x,-2000,sample.y),1))
		_check(not hit.is_empty(), "地形碰撞射线命中 %s" % sample)
	var left := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(999.9,2000,-600),Vector3(999.9,-2000,-600),1))
	var right := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(1000.1,2000,-600),Vector3(1000.1,-2000,-600),1))
	_check(not left.is_empty() and not right.is_empty() and absf(left.position.y-right.position.y)<3.0, "地形分块接缝两侧碰撞连续")
	var avatar: Node3D = game.avatars.values()[0]
	_check(avatar.camera.far == 16000.0, "玩家摄像机可显示完整大地形")
	if render_preview:
		DirAccess.make_dir_recursive_absolute(OUTPUT)
		game.get_node("GUI").hide()
		avatar.set_physics_process(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.far = 18000.0
		camera.cull_mask = 1048573
		camera.make_current()
		# 全景用于检查材质和分块；公里外旧场景的大气雾会遮住地表，暂时关闭。
		var environment: Environment = world.get_node("世界环境").environment
		var fog_enabled := environment.fog_enabled
		var volume_enabled := environment.volumetric_fog_enabled
		environment.fog_enabled = false
		environment.volumetric_fog_enabled = false
		camera.look_at_from_position(Vector3(5600,6000,7200),Vector3(0,180,-500))
		await _frames(12)
		root.get_texture().get_image().save_png(OUTPUT+"全景_关闭雾效检查.png")
		environment.fog_enabled = fog_enabled
		environment.volumetric_fog_enabled = volume_enabled
		camera.look_at_from_position(Vector3(240,155,420),Vector3(-50,50,80))
		await _frames(12)
		root.get_texture().get_image().save_png(OUTPUT+"遗迹海岸.png")
		camera.look_at_from_position(Vector3(1600,750,-1000),Vector3(0,500,-1800))
		await _frames(12)
		root.get_texture().get_image().save_png(OUTPUT+"山地材质.png")
		avatar.camera.make_current()
		await _frames(8)
		root.get_texture().get_image().save_png(OUTPUT+"玩家视角.png")
	game.queue_free()
	await process_frame
	print("RESULT terrain integration: ", "PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
