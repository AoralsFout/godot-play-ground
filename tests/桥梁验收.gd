extends SceneTree
## Test the actual imported bridge, graded approaches and player capsule.
var failures := 0
var probes := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func vec(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

func ray(p: Vector3, mask: int, depth := 3.0) -> Dictionary:
	return root.world_3d.direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0, p - Vector3.UP * depth, mask))

func run() -> void:
	var map := (load("res://scenes/world/地图.tscn") as PackedScene).instantiate()
	root.add_child(map)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://source_art/terrain/桥梁数据.json"))
	var network := map.get_node("超大地形v2/路网")
	var meshes := network.find_children("桥梁*", "MeshInstance3D", true, false)
	check(meshes.size() >= 10, "桥梁模型未完整导入")
	check(float(data.max_grade) < 0.08, "引道坡度超出 8%")
	var direction := vec(data.direction)
	var sideways := vec(data.cross_direction)
	for body: StaticBody3D in map.find_children("*", "StaticBody3D", true, false):
		body.collision_layer = 0
	for mesh: MeshInstance3D in network.find_children("*", "MeshInstance3D", true, false):
		var label := str(mesh.name)
		var layer := 0
		if label.begins_with("道路"):
			layer = 32
		elif label == "地形_整平":
			layer = 16
		elif label in ["桥梁_桥面", "桥梁_主岛引道", "桥梁_副岛引道", "桥梁_副岛落地点"]:
			layer = 2
		elif label in ["桥梁_护栏", "桥梁_扶手", "桥梁_栏杆立柱"]:
			layer = 4
		elif label.begins_with("桥梁"):
			layer = 8
		for body: StaticBody3D in mesh.find_children("*", "StaticBody3D", true, false):
			body.collision_layer = layer
		if label.begins_with("桥梁"):
			check(mesh.layers == 3, "桥梁未显示在小地图：" + label)
	await physics_frame
	await physics_frame
	for sample: Dictionary in data.samples:
		var center := vec(sample.center)
		var hits: Array[Dictionary] = []
		for key in ["left", "center", "right"]:
			var p := vec(sample[key]) + Vector3(0.001, 0.0, 0.001)
			var hit := ray(p, 2)
			probes += 1
			check(not hit.is_empty(), "桥面/引道碰撞缺口：" + str(p))
			if not hit.is_empty():
				check(absf(hit.position.y - p.y) < 0.035, "路面高度与设计不符：" + str(p))
			hits.append(hit)
		if not hits[0].is_empty() and not hits[2].is_empty():
			check(absf(hits[0].position.y - hits[2].position.y) < 0.03, "桥面横向不平整")
		var station := float(sample.station)
		if (station > 35.0 and station < 348.0) or (station > 1192.0 and station < float(data.length_m) - 25.0):
			for key in ["left", "right"]:
				var p := vec(sample[key])
				var hit := ray(p, 16)
				check(not hit.is_empty(), "引道路基未支撑路面：" + str(p))
				if not hit.is_empty():
					check(p.y - hit.position.y > -0.025 and p.y - hit.position.y < 0.6, "引道穿地/悬空：" + str(p))
		if station > 380.0 and station < 1160.0:
			check(center.y - 3.6 - float(data.sea_level) > 25.0, "桥底海面净空不足")
	# Verify original route and approach genuinely meet.
	var start := vec(data.start)
	check(not ray(start, 32).is_empty(), "引道没有接入原环路")
	check(not ray(start + direction * 10.0, 2).is_empty(), "主岛桥头缺口")
	var player := (load("res://scenes/player/玩家.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.collision_layer = 0
	player.collision_mask = 2 | 4 | 8 | 16 | 32
	player.global_position = start - direction * 2.0 + Vector3.UP * 2.0
	for frame in 120:
		await physics_frame
		player.velocity = Vector3(0, player.velocity.y - 20.0 / 60.0, 0)
		player.move_and_slide()
	check(player.is_on_floor(), "玩家无法在主岛桥头落地")
	# Use the real player's capsule, gravity, floor snapping and slide solver along the entire crossing.
	var lost_floor := 0
	for frame in range(ceili((float(data.length_m) + 2.0) / 12.0 * 60.0)):
		await physics_frame
		player.velocity = direction * 12.0 + Vector3.UP * (player.velocity.y - 20.0 / 60.0)
		player.move_and_slide()
		if not player.is_on_floor():
			lost_floor += 1
	var finish := vec(data.end)
	check(Vector2(player.position.x - finish.x, player.position.z - finish.z).length() < 3.0,
		"玩家未走完整条跨岛路线：" + str(player.position))
	check(player.is_on_floor(), "玩家没有在副岛落地")
	check(lost_floor < 10, "跨桥期间存在明显脱离路面的接缝：" + str(lost_floor))
	# Walk sideways into a real safety parapet at midspan.
	var middle := start + direction * 760.0
	middle.y = float(data.deck_height)
	player.position = middle + Vector3.UP * 2.0
	player.velocity = Vector3.ZERO
	for frame in 120:
		await physics_frame
		player.velocity = Vector3(0, player.velocity.y - 20.0 / 60.0, 0)
		player.move_and_slide()
	for frame in 120:
		await physics_frame
		player.velocity = sideways * 12.0 + Vector3.UP * (player.velocity.y - 20.0 / 60.0)
		player.move_and_slide()
	var lateral := (player.position - middle).dot(sideways)
	check(lateral > 6.0 and lateral < 7.5, "护栏没有阻挡玩家：" + str(lateral))
	check(player.is_on_floor(), "玩家穿过护栏跌落")
	print("桥梁验收：", meshes.size(), " 个网格，", probes, " 次路面射线，完整跨岛行走及护栏碰撞，", failures, " 项失败")
	player.queue_free()
	map.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
