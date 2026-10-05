extends SceneTree
## 运行命令：Godot --headless --path . --script res://tests/水面验收.gd

const WATER_SCRIPT := preload("res://scripts/world/水面.gd")
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS ", description)
	else:
		failures += 1
		push_error("FAIL " + description)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var water := WATER_SCRIPT.new()
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/water/水面.gdshader")
	material.set_shader_parameter("use_game_time", true)
	water.water_material = material
	water.position.y = 15.0
	world.add_child(water)
	material = water.get_active_material(0) as ShaderMaterial
	var camera := Camera3D.new()
	camera.position = Vector3(10.3, 20.0, -20.3)
	world.add_child(camera)
	camera.make_current()
	await process_frame
	await process_frame
	var water_mesh: ArrayMesh = water.mesh
	var arrays := water_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	print("WATER_GEOMETRY vertices=%d triangles=%d (baseline=8396802)" % [vertices.size(), indices.size() / 3])
	_check(indices.size() / 3 < 85000, "三角形数比原水面降低至少 99%")
	_check(material.get_shader_parameter("use_distance_lod") == true, "运行时启用距离计算裁剪")
	_check(material.get_shader_parameter("lod_center") == Vector2(10.5, -20.5), "网格中心跟随实际摄像机")
	_check(material.get_shader_parameter("wave_full_distance") == 64.0 and material.get_shader_parameter("wave_end_distance") == 112.0, "近处完整波浪、远处停止计算")
	_check(water.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "水面不参与阴影绘制")
	_check(water.gi_mode == GeometryInstance3D.GI_MODE_DISABLED, "动态海面不使用烘焙体素光照")
	_check(water.custom_aabb.position == Vector3(-2000.0, -3.0, -1500.0), "包围盒包含位移和完整地图边界")
	var saved_scene := PackedScene.new()
	_check(saved_scene.pack(water) == OK, "程序网格可正常打包场景")
	var state := saved_scene.get_state()
	var saved_mesh := false
	var saved_material := false
	for property in state.get_node_property_count(0):
		saved_mesh = saved_mesh or state.get_node_property_name(0, property) == &"mesh"
		saved_material = saved_material or state.get_node_property_name(0, property) == &"water_material"
	_check(not saved_mesh and saved_material, "编辑器保存保留材质、不序列化程序生成的大网格")
	_validate_topology(vertices, indices)
	_check(vertices.has(Vector3(0.5, 0.0, 0.0)) and vertices.has(Vector3(31.5, 0.0, 31.5)), "近处使用 0.5 米细分")
	_check(vertices.has(Vector3(63.0, 0.0, 63.0)) and vertices.has(Vector3(126.0, 0.0, 126.0)), "外围逐级使用 1 米、2 米细分")
	# 主场景在水面子节点的 _ready() 执行后复制材质。
	var replacement := material.duplicate() as ShaderMaterial
	water.set_surface_override_material(0, replacement)
	await process_frame
	await process_frame
	_check(replacement.get_shader_parameter("lod_center") == Vector2(10.5, -20.5), "替换独立游戏材质后仍同步网格中心")
	camera.position = Vector3(1999.8, 20.0, 1499.8)
	await process_frame
	await process_frame
	_check(water.mesh == water_mesh and replacement.get_shader_parameter("lod_center") == Vector2(2000.0, 1500.0), "地图边缘移动只更新参数、不重建网格")
	_validate_bounds(arrays, Vector2(2000.0, 1500.0))
	_validate_bounds(arrays, Vector2(-2100.0, -1600.0))
	paused = true
	var frozen_center: Vector2 = replacement.get_shader_parameter("lod_center")
	camera.position = Vector3.ZERO
	await process_frame
	await process_frame
	_check(replacement.get_shader_parameter("lod_center") == frozen_center, "暂停时网格停止更新")
	paused = false
	world.queue_free()
	await process_frame
	print("RESULT water: %s" % ["PASS" if failures == 0 else "%d FAILED" % failures])
	quit(0 if failures == 0 else 1)


func _validate_topology(vertices: PackedVector3Array, indices: PackedInt32Array) -> void:
	# 按位置合并重复的远端角点，再统计与各点相连的三角形数量。
	var vertex_ids: Dictionary[Vector3, int] = {}
	var welded: Array[int] = []
	for point in vertices:
		if not vertex_ids.has(point):
			vertex_ids[point] = vertex_ids.size()
		welded.append(vertex_ids[point])
	var edges: Dictionary[Vector2i, int] = {}
	var area := 0.0
	var all_faces_up := true
	for triangle in range(0, indices.size(), 3):
		var a := vertices[indices[triangle]]
		var b := vertices[indices[triangle + 1]]
		var c := vertices[indices[triangle + 2]]
		var twice_area := -(b - a).cross(c - a).y
		all_faces_up = all_faces_up and twice_area > 0.0
		area += twice_area * 0.5
		for side in 3:
			var first := welded[indices[triangle + side]]
			var second := welded[indices[triangle + (side + 1) % 3]]
			var edge := Vector2i(mini(first, second), maxi(first, second))
			edges[edge] = edges.get(edge, 0) + 1
	var boundary_edges := 0
	var manifold := true
	for count: int in edges.values():
		boundary_edges += 1 if count == 1 else 0
		manifold = manifold and (count == 1 or count == 2)
	_check(all_faces_up, "全部三角形朝上且没有退化面")
	_check(manifold and boundary_edges == 4, "细分环和远景严格拼接、仅地图四边开放")
	_check(is_equal_approx(area, 4000.0 * 3000.0), "水面完整覆盖原地图且没有重叠")


func _validate_bounds(arrays: Array, center: Vector2) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var outer_flags: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var displaced := PackedVector3Array()
	for index in vertices.size():
		var point := Vector2(vertices[index].x, vertices[index].z)
		if outer_flags[index].x > 0.5:
			point = (uvs[index] * 2.0 - Vector2.ONE) * Vector2(2000.0, 1500.0)
		else:
			point = (point + center).clamp(Vector2(-2000.0, -1500.0), Vector2(2000.0, 1500.0))
		displaced.append(Vector3(point.x, 0.0, point.y))
	var area := 0.0
	var inverted := false
	for triangle in range(0, indices.size(), 3):
		var a := displaced[indices[triangle]]
		var b := displaced[indices[triangle + 1]]
		var c := displaced[indices[triangle + 2]]
		var twice_area := -(b - a).cross(c - a).y
		inverted = inverted or twice_area < 0.0
		area += twice_area * 0.5
	_check(not inverted and is_equal_approx(area, 12000000.0), "相机位于 %s 时边界裁剪完整且无翻面" % center)
