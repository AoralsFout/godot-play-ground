## 路网功能验收。
## 检查实际道路导入、碰撞、横向平整、坡度及整平地形，并验证玩家落地和跳跃。

extends SceneTree
## 验证实际导入路网的碰撞、海拔、地形贴合和玩家落地。
var failures := 0
var probes := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func ray(point: Vector3, mask: int) -> Dictionary:
	return root.world_3d.direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(point + Vector3.UP * 3.0, point - Vector3.UP * 3.0, mask))

func run() -> void:
	var map := (load("res://scenes/world/地图.tscn") as PackedScene).instantiate()
	root.add_child(map)
	var network := map.get_node("超大地形v2/路网")
	var meshes := network.find_children("道路*", "MeshInstance3D", true, false)
	var original := map.get_node("超大地形v2/地形")
	check(not original.visible, "原地形仍在遮挡整平路面")
	for body: StaticBody3D in original.find_children("*", "StaticBody3D", true, false):
		check(body.collision_layer == 0, "原地形碰撞未停用")
	check(meshes.size() == 15, "应导入 10 段道路和 5 个路口")
	for body: StaticBody3D in map.find_children("*", "StaticBody3D", true, false):
		body.collision_layer = 0
	for mesh: MeshInstance3D in meshes:
		check(mesh.layers == 3, "路网必须同时显示在主视图和小地图")
		var bodies := mesh.find_children("*", "StaticBody3D", true, false)
		check(bodies.size() == 1, str(mesh.name) + " 缺少碰撞")
		for body: StaticBody3D in bodies:
			body.collision_layer = 2
			for collision: CollisionShape3D in body.find_children("*", "CollisionShape3D", true, false):
				check(collision.shape is ConcavePolygonShape3D and collision.shape.backface_collision,
					str(mesh.name) + " 未启用双面碰撞")
	var terrain := network.get_node_or_null("地形_整平")
	check(terrain != null, "找不到 v2 地形")
	if terrain:
		for body: StaticBody3D in terrain.find_children("*", "StaticBody3D", true, false):
			body.collision_layer = 4
	await physics_frame
	await physics_frame
	var floor_point := Vector3.ZERO
	# 使用真实三角面内部采样，避免公里级坐标下顶点/共边射线的浮点歧义。
	for mesh: MeshInstance3D in meshes:
		var faces := mesh.mesh.get_faces()
		var stride := maxi(1, faces.size() / 3 / 40) * 3
		for i in range(0, faces.size(), stride):
			var point := mesh.to_global((faces[i] + faces[i + 1] + faces[i + 2]) / 3.0)
			var road_hit := ray(point, 2)
			var ground_hit := ray(point, 4)
			probes += 1
			check(not road_hit.is_empty(), "路面碰撞缺口：" + str(point))
			check(not ground_hit.is_empty(), "路网未贴合当前游戏地形：" + str(point))
			if road_hit.is_empty() or ground_hit.is_empty():
				continue
			var clearance: float = road_hit.position.y - ground_hit.position.y
			check(clearance >= -0.03 and clearance < 0.5, "路面穿地或悬空：" + str(clearance) + " " + str(mesh.name) + " " + str(point))
			check(road_hit.position.y > 15.5, "路面进入海面")
			if floor_point == Vector3.ZERO and road_hit.normal.y > 0.995:
				floor_point = road_hit.position
	var road_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://source_art/terrain/路网数据.json"))
	var cross_checks := 0
	for route: Dictionary in road_data.routes:
		for pair: Array in route.cross_sections:
			var hits: Array[Dictionary] = []
			for sample: Array in pair:
				var point := Vector3(sample[0], sample[1], sample[2]) + Vector3(0.001, 0.0, -0.001)
				hits.append(ray(point, 2))
			if hits[0].is_empty() or hits[1].is_empty():
				check(false, "横截面两侧缺少碰撞：" + route.name + str(pair))
				continue
			cross_checks += 1
			check(absf(hits[0].position.y - hits[1].position.y) < 0.03, "横截面左右高差过大：" + route.name + str(pair) + str(hits[0].position.y - hits[1].position.y))
	print("平整路面：", cross_checks, " 个横截面")
	check(floor_point != Vector3.ZERO, "找不到平缓路段执行玩家验证")
	if floor_point != Vector3.ZERO:
		var player := (load("res://scenes/player/玩家.tscn") as PackedScene).instantiate() as CharacterBody3D
		root.add_child(player)
		player.set_physics_process(false)
		player.set_process(false)
		player.collision_layer = 0
		player.collision_mask = 2
		root.get_node("Session").input_blocked = false
		player.global_position = floor_point + Vector3.UP * 4.0
		for frame in 120:
			player._physics_process(1.0 / 60.0)
		check(player.is_on_floor(), "玩家无法在路网上落地")
		var baseline := player.global_position.y
		player.velocity.y = player.jump_speed
		for frame in 15:
			player._physics_process(1.0 / 60.0)
		check(player.global_position.y > baseline + 0.5, "路面起跳失败")
		for frame in 120:
			player._physics_process(1.0 / 60.0)
		check(player.is_on_floor(), "跳跃后未回到路面")
		player.queue_free()
	print("路网验收：", meshes.size(), " 个网格，", probes, " 个采样点，", failures, " 项失败")
	map.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
