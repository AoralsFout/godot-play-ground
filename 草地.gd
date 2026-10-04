@tool
extends Node3D
## 草地斑块的分布可复现，通过小型 MultiMesh 在摄像机周围动态加载。

const Distribution := preload("res://草地分布.gd")
const CHUNK_SIZE := 16.0
const ROOT_OFFSET := 0.015
const BUILD_BUDGET_USEC := 3000

@export var terrain_path: NodePath
@export var water_path: NodePath
@export var exclusion_paths: Array[NodePath] = []
@export_group("Distribution")
@export var distribution_seed := 7319
@export_range(0.01, 0.2, 0.005) var grass_patch_scale := 0.055
@export_range(0.0, 1.0, 0.01) var grass_coverage := 0.58
@export_range(0.25, 1.5, 0.05) var spacing := 0.45
@export_range(0.05, 3.0, 0.05) var shore_clearance := 0.65
@export_range(0.0, 70.0, 1.0) var max_slope_degrees := 42.0
@export_group("Appearance")
@export_range(0.1, 1.5, 0.05) var blade_height := 0.6
@export_range(32.0, 128.0, 8.0) var view_distance := 72.0
@export var root_color := Color(0.12, 0.25, 0.045)
@export var tip_color := Color(0.44, 0.62, 0.19)
@export_group("Breeze")
@export var wind_direction := Vector2(0.94, 0.34)
@export_range(0.0, 0.5, 0.01) var wind_strength := 0.12
@export_range(0.0, 4.0, 0.05) var wind_speed := 1.15

var _terrain: MeshInstance3D
var _water: Node3D
var _material: ShaderMaterial
var _mesh: ArrayMesh
var _faces := PackedVector3Array()
var _normals := PackedVector3Array()
var _cells: Dictionary[Vector2i, Array] = {}
var _chunks: Dictionary[Vector2i, MultiMeshInstance3D] = {}
var _pending: Array[Vector2i] = []
var _exclusions: Array[AABB] = []
var _last_center := Vector2i(2147483647, 2147483647)
var _settings: Array = []
var _sea_level := 15.0
var _time := 0.0


func _ready() -> void:
	# 整个场景进入场景树后，导入网格和同级节点的变换才准备就绪。
	_initialize.call_deferred()


func _initialize() -> void:
	_terrain = get_node_or_null(terrain_path) as MeshInstance3D
	_water = get_node_or_null(water_path) as Node3D
	if _terrain == null or _terrain.mesh == null:
		return
	_material = ShaderMaterial.new()
	_material.shader = preload("res://草叶.gdshader")
	_mesh = _build_tuft()
	_mesh.surface_set_material(0, _material)
	_rebuild()


func _process(delta: float) -> void:
	if _material == null or not is_instance_valid(_terrain):
		return
	_time += delta
	var sea := _water.global_position.y if is_instance_valid(_water) else 15.0
	var settings: Array = [distribution_seed, grass_patch_scale, grass_coverage, spacing,
		shore_clearance, max_slope_degrees, blade_height, view_distance, sea, _terrain.global_transform]
	if settings != _settings:
		_rebuild()
	_material.set_shader_parameter("wind_time", _time)
	_material.set_shader_parameter("wind_direction", wind_direction)
	_material.set_shader_parameter("wind_strength", wind_strength)
	_material.set_shader_parameter("wind_speed", wind_speed)
	_material.set_shader_parameter("root_color", root_color)
	_material.set_shader_parameter("tip_color", tip_color)
	var camera := get_viewport().get_camera_3d()
	if Engine.is_editor_hint():
		# 动态获取编辑器单例，确保导出的游戏也能解析此脚本。
		var editor := Engine.get_singleton("EditorInterface")
		var editor_viewport: SubViewport = editor.get_editor_viewport_3d(0) if editor != null else null
		if editor_viewport != null:
			camera = editor_viewport.get_camera_3d()
	var viewer := camera.global_position if camera != null else global_position
	_material.set_shader_parameter("viewer_position", viewer)
	var center := _chunk_at(Vector2(viewer.x, viewer.z))
	if center != _last_center:
		_request_chunks(center)
	var deadline := Time.get_ticks_usec() + BUILD_BUDGET_USEC
	while not _pending.is_empty() and Time.get_ticks_usec() < deadline:
		_build_chunk(_pending.pop_front())


func _rebuild() -> void:
	for chunk in _chunks.values():
		if is_instance_valid(chunk):
			chunk.queue_free()
	_chunks.clear()
	_pending.clear()
	_faces.clear()
	_normals.clear()
	_cells.clear()
	_exclusions.clear()
	_sea_level = _water.global_position.y if is_instance_valid(_water) else 15.0
	_settings = [distribution_seed, grass_patch_scale, grass_coverage, spacing,
		shore_clearance, max_slope_degrees, blade_height, view_distance, _sea_level, _terrain.global_transform]
	_material.set_shader_parameter("sea_level", _sea_level)
	_material.set_shader_parameter("view_distance", view_distance)
	# 同步现有地形材质，保留其海拔设置。
	var ground := _terrain.get_active_material(0) as ShaderMaterial
	if ground != null:
		ground.set_shader_parameter("sea_level", _sea_level)
		ground.set_shader_parameter("distribution_seed", distribution_seed)
		ground.set_shader_parameter("grass_patch_scale", grass_patch_scale)
		ground.set_shader_parameter("grass_coverage", grass_coverage)
	for surface in _terrain.mesh.get_surface_count():
		if _terrain.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays: Array = _terrain.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for index in range(0, count - 2, 3):
			var a := _terrain.global_transform * vertices[indices[index] if not indices.is_empty() else index]
			var b := _terrain.global_transform * vertices[indices[index + 1] if not indices.is_empty() else index + 1]
			var c := _terrain.global_transform * vertices[indices[index + 2] if not indices.is_empty() else index + 2]
			if maxf(a.y, maxf(b.y, c.y)) <= _sea_level + shore_clearance:
				continue
			var normal := (c - a).cross(b - a).normalized()
			if normal.y < 0.0:
				normal = -normal
			if normal.y < 0.001:
				continue
			var face := _normals.size()
			_faces.append_array(PackedVector3Array([a, b, c]))
			_normals.append(normal)
			var start := _chunk_at(Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z))))
			var end := _chunk_at(Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z))))
			for z in range(start.y, end.y + 1):
				for x in range(start.x, end.x + 1):
					var key := Vector2i(x, z)
					if not _cells.has(key):
						_cells[key] = []
					_cells[key].append(face)
	for path in exclusion_paths:
		var excluded := get_node_or_null(path)
		if excluded != null:
			_collect_exclusions(excluded)
	_last_center = Vector2i(2147483647, 2147483647)


func _collect_exclusions(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var bounds: AABB = node.global_transform * node.mesh.get_aabb()
		_exclusions.append(bounds.grow(0.3))
	for child in node.get_children():
		_collect_exclusions(child)


func _chunk_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CHUNK_SIZE), floori(point.y / CHUNK_SIZE))


func _request_chunks(center: Vector2i) -> void:
	_last_center = center
	_pending.clear()
	var radius := ceili(view_distance / CHUNK_SIZE) + 1
	for key in _chunks.keys():
		if Vector2(key - center).length() > radius + 2:
			if is_instance_valid(_chunks[key]):
				_chunks[key].queue_free()
			_chunks.erase(key)
	for z in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var key := center + Vector2i(x, z)
			if Vector2(x, z).length() <= radius and _cells.has(key) and not _chunks.has(key):
				_pending.append(key)
	_pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a - center).length_squared() < Vector2(b - center).length_squared())


## 垂直投影到最高的地形三角形，不依赖物理系统。
func surface_at(point: Vector2) -> Vector4:
	var highest := Vector4(0.0, 1.0, 0.0, -INF)
	for face: int in _cells.get(_chunk_at(point), []):
		var a := _faces[face * 3]
		var b := _faces[face * 3 + 1]
		var c := _faces[face * 3 + 2]
		var denominator := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(denominator) < 0.00001:
			continue
		var u := ((b.z - c.z) * (point.x - c.x) + (c.x - b.x) * (point.y - c.z)) / denominator
		var v := ((c.z - a.z) * (point.x - c.x) + (a.x - c.x) * (point.y - c.z)) / denominator
		if u < -0.00001 or v < -0.00001 or u + v > 1.00001:
			continue
		var height := a.y * u + b.y * v + c.y * (1.0 - u - v)
		if height > highest.w:
			var normal := _normals[face]
			highest = Vector4(normal.x, normal.y, normal.z, height)
	return highest


func _generate_chunk(key: Vector2i) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	# 使用各区块独立的随机序列，使再次访问或重新加载时的分布保持一致。
	rng.seed = hash(Vector3i(key.x, distribution_seed, key.y))
	var transforms: Array[Transform3D] = []
	var custom_data: Array[Color] = []
	var steps := ceili(CHUNK_SIZE / maxf(spacing, 0.1))
	var step := CHUNK_SIZE / steps
	var origin := Vector3(key.x * CHUNK_SIZE, 0.0, key.y * CHUNK_SIZE)
	var minimum_y := INF
	var maximum_y := -INF
	var min_up := cos(deg_to_rad(max_slope_degrees))
	for z in steps:
		for x in steps:
			var point := Vector2(origin.x, origin.z) + Vector2(x + rng.randf_range(0.1, 0.9), z + rng.randf_range(0.1, 0.9)) * step
			var density := Distribution.density_at(point, distribution_seed, grass_patch_scale, grass_coverage)
			if density <= 0.0 or rng.randf() > density:
				continue
			var surface := surface_at(point)
			if surface.w <= _sea_level + shore_clearance or surface.y < min_up:
				continue
			var shore_weight := smoothstep(shore_clearance, shore_clearance + 1.5, surface.w - _sea_level)
			if rng.randf() > shore_weight:
				continue
			var position_world := Vector3(point.x, surface.w + ROOT_OFFSET, point.y)
			var excluded := false
			for bounds in _exclusions:
				if bounds.has_point(position_world + Vector3.UP * blade_height * 0.5):
					excluded = true
					break
			if excluded:
				continue
			var normal := Vector3(surface.x, surface.y, surface.z)
			var basis := Basis(Quaternion(Vector3.UP, normal)) * Basis(Vector3.UP, rng.randf() * TAU)
			var height_scale := blade_height * rng.randf_range(0.65, 1.3)
			basis = basis * Basis.from_scale(Vector3(rng.randf_range(0.75, 1.25), height_scale, rng.randf_range(0.75, 1.25)))
			transforms.append(Transform3D(basis, position_world - origin))
			custom_data.append(Color(rng.randf(), rng.randf(), 0.0, 1.0))
			minimum_y = minf(minimum_y, position_world.y)
			maximum_y = maxf(maximum_y, position_world.y + height_scale)
	return {"transforms": transforms, "custom_data": custom_data,
		"bounds": AABB(Vector3(-1.0, minimum_y - 1.0, -1.0), Vector3(CHUNK_SIZE + 2.0, maximum_y - minimum_y + 2.0, CHUNK_SIZE + 2.0)) if not transforms.is_empty() else AABB()}


func _build_chunk(key: Vector2i) -> void:
	var data := _generate_chunk(key)
	var transforms: Array[Transform3D] = data.transforms
	var custom_data: Array[Color] = data.custom_data
	_chunks[key] = null
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
		multimesh.set_instance_custom_data(index, custom_data[index])
	# 剔除包围盒须包含草叶宽度和风造成的最大位移。
	multimesh.custom_aabb = data.bounds
	var chunk := MultiMeshInstance3D.new()
	chunk.name = "Grass_%d_%d" % [key.x, key.y]
	chunk.multimesh = multimesh
	chunk.layers = 1
	chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(chunk)
	# 实例以世界空间定义，不继承控制节点的缩放。
	chunk.top_level = true
	chunk.global_transform = Transform3D(Basis.IDENTITY, Vector3(key.x * CHUNK_SIZE, 0.0, key.y * CHUNK_SIZE))
	_chunks[key] = chunk


func _build_tuft() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# 每簇草由五条渐窄的弯曲带状几何体组成，不使用透明纹理或四边形面片。
	for blade in 5:
		var angle := blade * TAU / 5.0
		var right := Vector3(cos(angle), 0.0, sin(angle))
		var forward := Vector3(-sin(angle), 0.0, cos(angle))
		var base := right * (0.055 + blade * 0.008)
		var height := 0.7 + float(blade % 3) * 0.15
		var start := vertices.size()
		for level in 4:
			var t := float(level) / 3.0
			var center := base + Vector3.UP * t * height + forward * t * t * 0.16
			var width := (1.0 - t) * 0.035
			for side in 2:
				vertices.append(center + right * width * (-1.0 if side == 0 else 1.0))
				normals.append((Vector3.UP * 0.65 + forward * 0.75).normalized())
				uvs.append(Vector2(side, t))
		for level in 3:
			var a := start + level * 2
			indices.append_array(PackedInt32Array([a, a + 2, a + 1]))
			if level < 2:
				indices.append_array(PackedInt32Array([a + 1, a + 2, a + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
