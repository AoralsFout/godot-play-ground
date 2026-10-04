@tool
extends Node3D
## 为导入的树干生成沿枝条分布的叶片。CUSTOM 保存固定的随机相位、叶色与风动权重。

@export var trees_root_path: NodePath = NodePath("..")
@export_group("树冠")
@export var distribution_seed := 20261004
@export_range(4, 80, 1) var leaves_per_cluster := 24
@export_range(0.08, 0.4, 0.01) var cluster_radius := 0.24
@export_range(0.04, 0.25, 0.01) var leaf_size := 0.14
@export var leaf_material: ShaderMaterial = preload("res://树叶材质.tres")
@export_group("微风与叶色")
@export var leaf_color := Color(0.25, 0.46, 0.13)
@export var light_leaf_color := Color(0.34, 0.52, 0.18)
@export_range(0.0, 1.0, 0.01) var color_variation := 0.22
@export var wind_direction := Vector2(0.94, 0.34)
@export_range(0.0, 1.0, 0.01) var wind_strength := 0.18
@export_range(0.0, 4.0, 0.05) var wind_speed := 0.85
@export_group("轻微落叶")
@export_range(0, 12, 1) var falling_leaves_per_tree := 4
@export_range(0.1, 4.0, 0.1) var fall_speed := 1.4
@export_range(0.0, 2.0, 0.05) var fall_drift := 0.25
@export_tool_button("重新生成树叶") var rebuild_action = rebuild

var leaf_time := 0.0
var tree_count := 0
var leaf_count := 0
var _canopy_material: ShaderMaterial
var _falling_material: ShaderMaterial
var _leaf_mesh: ArrayMesh
var _rebuild_pending := false
var _fall_bounds_settings := Vector2(-1, -1)


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	if not is_inside_tree() or _rebuild_pending:
		return
	_rebuild_pending = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_pending = false
	for child in get_children():
		child.free()
	tree_count = 0
	leaf_count = 0
	var trees_root := get_node_or_null(trees_root_path)
	if trees_root == null or leaf_material == null:
		return
	_canopy_material = leaf_material.duplicate() as ShaderMaterial
	_falling_material = leaf_material.duplicate() as ShaderMaterial
	_canopy_material.set_shader_parameter("use_game_time", true)
	_canopy_material.set_shader_parameter("falling_leaf", false)
	_falling_material.set_shader_parameter("use_game_time", true)
	_falling_material.set_shader_parameter("falling_leaf", true)
	_leaf_mesh = _make_leaf_mesh()
	_sync_materials()
	var candidates := trees_root.find_children("树干*", "MeshInstance3D", true, false)
	for candidate in candidates:
		var trunk := candidate as MeshInstance3D
		if trunk.mesh == null:
			continue
		var clusters := _branch_clusters(trunk.mesh)
		if clusters.is_empty():
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = distribution_seed + tree_count * 7919
		_build_tree(trunk, clusters, rng)
		tree_count += 1


func _process(delta: float) -> void:
	leaf_time += delta
	_sync_materials()


func _sync_materials() -> void:
	for material in [_canopy_material, _falling_material]:
		if material == null:
			continue
		material.set_shader_parameter("leaf_time", leaf_time)
		material.set_shader_parameter("leaf_color", leaf_color)
		material.set_shader_parameter("light_leaf_color", light_leaf_color)
		material.set_shader_parameter("color_variation", color_variation)
		material.set_shader_parameter("wind_direction", wind_direction)
		material.set_shader_parameter("wind_strength", wind_strength)
		material.set_shader_parameter("wind_speed", wind_speed)
		material.set_shader_parameter("fall_speed", fall_speed)
		material.set_shader_parameter("fall_drift", fall_drift)
	var bounds_settings := Vector2(fall_speed, fall_drift)
	if bounds_settings != _fall_bounds_settings:
		_fall_bounds_settings = bounds_settings
		for child in get_children():
			if child.has_meta("fall_bounds"):
				_update_falling_bounds(child)


func _branch_clusters(mesh: Mesh) -> PackedVector3Array:
	var bounds := mesh.get_aabb()
	var cell_size := bounds.size.y * 0.065
	var minimum_height := bounds.position.y + bounds.size.y * 0.56
	var cells: Dictionary = {}
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if vertex.y < minimum_height:
				continue
			var key := Vector3i((vertex / cell_size).floor())
			# 每个枝条单元只保留一个锚点，避免高细分网格改变树冠密度。
			if not cells.has(key):
				cells[key] = vertex
	var result := PackedVector3Array()
	for anchor: Vector3 in cells.values():
		result.append(anchor)
	return result


func _make_leaf_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 分段并轻微折叠的叶片，UV.y=0 为叶柄，UV.y=1 为叶尖。
	for segment in 3:
		var bottom := float(segment) / 3.0
		var top := float(segment + 1) / 3.0
		for uv in [Vector2(0, bottom), Vector2(0, top), Vector2(1, bottom),
				Vector2(1, bottom), Vector2(0, top), Vector2(1, top)]:
			surface.set_uv(uv)
			surface.add_vertex(Vector3((uv.x - 0.5) * leaf_size * 0.65,
				uv.y * leaf_size, sin(uv.y * PI) * leaf_size * 0.10))
	surface.generate_normals()
	return surface.commit()


func _build_tree(trunk: MeshInstance3D, clusters: PackedVector3Array, rng: RandomNumberGenerator) -> void:
	var canopy := _new_multimesh("树冠_%s" % trunk.name, clusters.size() * leaves_per_cluster, _canopy_material)
	canopy.transform = global_transform.affine_inverse() * trunk.global_transform
	var anchors := PackedVector3Array()
	var index := 0
	for cluster in clusters:
		for leaf in leaves_per_cluster:
			var offset := Vector3(rng.randfn(0, 0.48), rng.randfn(0, 0.35), rng.randfn(0, 0.48))
			offset = offset.limit_length(1.0) * cluster_radius
			var anchor := cluster + offset
			var basis := _leaf_basis(rng)
			canopy.multimesh.set_instance_transform(index, Transform3D(basis, anchor))
			canopy.multimesh.set_instance_custom_data(index, Color(rng.randf(), rng.randf(), rng.randf_range(0.65, 1.0), 0.0))
			anchors.append(anchor)
			index += 1
	leaf_count += index
	# shader 位移不会扩展自动包围盒，显式保留微风位移的余量。
	var scale_axes := trunk.global_basis.get_scale().abs()
	var trunk_scale := maxf(minf(scale_axes.x, minf(scale_axes.y, scale_axes.z)), 0.01)
	canopy.custom_aabb = trunk.mesh.get_aabb().grow(cluster_radius + leaf_size + 1.0 / trunk_scale)
	if falling_leaves_per_tree == 0 or anchors.is_empty():
		return
	var falling := _new_multimesh("落叶_%s" % trunk.name, falling_leaves_per_tree, _falling_material)
	falling.transform = canopy.transform
	falling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for leaf in falling_leaves_per_tree:
		var anchor := anchors[rng.randi_range(0, anchors.size() - 1)]
		var drop := maxf((trunk.global_transform * anchor).y - trunk.global_position.y - 0.05, 0.1)
		falling.multimesh.set_instance_transform(leaf, Transform3D(_leaf_basis(rng), anchor))
		falling.multimesh.set_instance_custom_data(leaf, Color(rng.randf(), rng.randf(), drop, rng.randf()))
	var bounds := canopy.custom_aabb
	var maximum_drop := trunk.mesh.get_aabb().end.y * trunk.global_basis.y.length()
	bounds.position.y = minf(bounds.position.y, -leaf_size)
	bounds.size.y = canopy.custom_aabb.end.y - bounds.position.y
	falling.set_meta("fall_bounds", bounds)
	falling.set_meta("maximum_drop", maximum_drop)
	falling.set_meta("trunk_scale", trunk_scale)
	_update_falling_bounds(falling)


func _update_falling_bounds(falling: MultiMeshInstance3D) -> void:
	var bounds: AABB = falling.get_meta("fall_bounds")
	var maximum_drop: float = falling.get_meta("maximum_drop")
	var trunk_scale: float = falling.get_meta("trunk_scale")
	var drift_margin := (maximum_drop / maxf(fall_speed, 0.1) * fall_drift + 1.0) / trunk_scale
	falling.custom_aabb = bounds.grow(drift_margin)


func _leaf_basis(rng: RandomNumberGenerator) -> Basis:
	var basis := Basis.from_euler(Vector3(rng.randf_range(-1.1, 1.1), rng.randf_range(-PI, PI), rng.randf_range(-PI, PI)))
	return basis.scaled(Vector3.ONE * rng.randf_range(0.75, 1.2))


func _new_multimesh(node_name: String, count: int, material: ShaderMaterial) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.layers = 3
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	instance.material_override = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _leaf_mesh
	multimesh.instance_count = count
	instance.multimesh = multimesh
	add_child(instance)
	return instance
