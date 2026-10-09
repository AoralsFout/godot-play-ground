## 地图碰撞功能验收。
## 使用真实玩家胶囊探测肋柱、道路、塔及地形，验证双面阻挡、贴墙移动、落地与跳跃。

extends SceneTree
## Godot --headless --path . --script res://tests/world/地图碰撞验收.gd
## 用实际地图与玩家胶囊验证外侧阻挡、道路上下表面、贴墙及落地跳跃。

var _failures := 0
var _probes := 0
var _wall_checked := false
var _floor_checked := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _probe(player: CharacterBody3D, point: Vector3, direction: Vector3, label: String) -> void:
	player.global_position = point - direction * 3.0
	var collision := player.move_and_collide(direction * 4.0)
	_probes += 1
	_check(collision != null and (player.global_position - point).dot(direction) <= 0.05,
		"%s 外侧穿透：%s，方向 %s" % [label, point, direction])

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 2)
	query.hit_back_faces = true
	return root.world_3d.direct_space_state.intersect_ray(query)

func _check_wall_motion(player: CharacterBody3D, hit: Dictionary, label: String) -> void:
	var normal: Vector3 = hit.normal
	if _wall_checked or absf(normal.y) > 0.15:
		return
	var point: Vector3 = hit.position
	player.global_position = point + normal * 3.0
	for frame in 90:
		player.velocity = -normal * player.move_speed
		player.move_and_slide()
	_check((player.global_position - point).dot(normal) > 0.1, label + " 连续行走穿进墙内")
	# 沿表面继续走，确认没有被困住。
	var tangent := normal.cross(Vector3.UP).normalized()
	var before := player.global_position
	for frame in 20:
		player.velocity = tangent * player.move_speed
		player.move_and_slide()
	_check((player.global_position - before).dot(tangent) > 1.0, label + " 贴墙后无法移动")
	_wall_checked = true

func _check_floor_motion(player: CharacterBody3D, hit: Dictionary) -> void:
	if _floor_checked or hit.normal.y < 0.99:
		return
	var point: Vector3 = hit.position
	player.global_position = point + Vector3.UP * 4.0
	player.velocity = Vector3.ZERO
	for frame in 90:
		player._physics_process(1.0 / 60.0)
	_check(player.is_on_floor(), "玩家无法在道路上落地")
	_check(player.global_position.y > point.y, "玩家落入道路内部")
	var floor_height := player.global_position.y
	player.velocity.y = player.jump_speed
	for frame in 15:
		player._physics_process(1.0 / 60.0)
	_check(player.global_position.y > floor_height + 0.5, "玩家在道路上不能起跳")
	for frame in 90:
		player._physics_process(1.0 / 60.0)
	_check(player.is_on_floor() and absf(player.global_position.y - floor_height) < 0.1,
		"玩家跳跃后没有回到道路表面")
	_floor_checked = true

func _probe_road(player: CharacterBody3D, mesh: MeshInstance3D) -> void:
	# 道路窄而长，包围盒采样容易错过；额外沿实际三角面的位置采样。
	var faces := mesh.mesh.get_faces()
	var bounds: AABB = mesh.global_transform * mesh.mesh.get_aabb()
	var stride := maxi(1, faces.size() / 3 / 160)
	var before := _probes
	for index in range(0, faces.size(), stride * 3):
		var point := mesh.to_global((faces[index] + faces[index + 1] + faces[index + 2]) / 3.0)
		for side in [-1.0, 1.0]:
			var from := Vector3(point.x, bounds.end.y + 10.0 if side > 0.0 else bounds.position.y - 10.0, point.z)
			var to := Vector3(point.x, bounds.position.y - 10.0 if side > 0.0 else bounds.end.y + 10.0, point.z)
			var hit := _ray(from, to)
			if hit.is_empty():
				continue
			_probe(player, hit.position, Vector3.DOWN * side, "道路")
			if side > 0.0:
				_check_floor_motion(player, hit)
	_check(_probes - before >= 100, "道路上下表面探测数量不足")

func _run() -> void:
	var map := (load("res://scenes/world/地图.tscn") as PackedScene).instantiate()
	root.add_child(map)
	_check(map.get_node_or_null("超大地形") == null, "地图仍加载已停用的旧版地形")
	var player := (load("res://scenes/player/玩家.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.collision_layer = 0
	player.collision_mask = 2
	root.get_node("Session").input_blocked = false
	# 单独探测每个对象，防止邻近碰撞体替缺陷对象挡住玩家。
	for body: StaticBody3D in map.find_children("*", "StaticBody3D", true, false):
		body.collision_layer = 0
	await physics_frame
	await physics_frame
	var meshes_checked := 0
	var roads_checked := 0
	for mesh: MeshInstance3D in map.get_node("超大地形v2").find_children("*", "MeshInstance3D", true, false):
		# 当前路网由分段道路组成；跳过路口及已被替换的原地表。
		var is_road := str(mesh.name).begins_with("道路_") and not str(mesh.name).begins_with("道路_路口")
		var is_terrain := str(mesh.name) == "地形_整平"
		if not (str(mesh.name).begins_with("巨构肋柱") or is_road or str(mesh.name) == "塔_01" or is_terrain):
			continue
		var bodies := mesh.find_children("*", "StaticBody3D", true, false)
		_check(not bodies.is_empty(), "缺少碰撞：" + str(mesh.name))
		if bodies.is_empty():
			continue
		var body := bodies[0] as StaticBody3D
		body.collision_layer = 2
		await physics_frame
		await physics_frame
		var before := _failures
		var count_before := _probes
		var bounds := mesh.mesh.get_aabb()
		for axis in 3:
			# 地形只有上表面，地形对照只测试从上方落下。
			if is_terrain and axis != 1:
				continue
			var u := (axis + 1) % 3
			var v := (axis + 2) % 3
			for side in [-1.0, 1.0]:
				if is_terrain and side < 0.0:
					continue
				for fraction_u in [0.25, 0.5, 0.75]:
					for fraction_v in [0.25, 0.5, 0.75]:
						var from := bounds.get_center()
						from[axis] += side * (bounds.size[axis] * 0.5 + 5.0)
						from[u] = bounds.position[u] + bounds.size[u] * fraction_u
						from[v] = bounds.position[v] + bounds.size[v] * fraction_v
						var to := from
						to[axis] -= side * (bounds.size[axis] + 10.0)
						from = mesh.to_global(from)
						to = mesh.to_global(to)
						var hit := _ray(from, to)
						if hit.is_empty():
							continue
						_probe(player, hit.position, (to - from).normalized(), str(mesh.name))
						if str(mesh.name) == "巨构肋柱_17":
							_check_wall_motion(player, hit, str(mesh.name))
		if is_road:
			roads_checked += 1
			_probe_road(player, mesh)
		_check(_probes > count_before, "没有探测到表面：" + str(mesh.name))
		meshes_checked += 1
		print("外表面 ", mesh.name, "：", _probes - count_before, " 次探测，", _failures - before, " 项失败")
		body.collision_layer = 0
	_check(roads_checked == 10, "没有覆盖当前路网的全部 10 段道路")
	_check(meshes_checked == 44, "没有覆盖全部 32 根肋柱、10 段道路、塔和整平地形")
	_check(_wall_checked, "没有执行连续贴墙行走验证")
	_check(_floor_checked, "没有执行道路落地与跳跃验证")
	print("地图碰撞验收：", _probes, " 次探测，", _failures, " 项失败")
	player.queue_free()
	map.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)
