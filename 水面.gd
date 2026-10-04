@tool
extends MeshInstance3D
## 以摄像机为中心的环形水面。几何体只构建一次，之后仅移动中心位置。

const WATER_SIZE := Vector2(4000.0, 3000.0)
const NEAR_STEP := 0.5
const FULL_WAVE_DISTANCE := 64.0
const END_WAVE_DISTANCE := 112.0
const RINGS := [
	# 外侧半尺寸、网格间距、内侧半尺寸。
	Vector3(32.0, NEAR_STEP, 0.0),
	Vector3(64.0, 1.0, 32.0),
	Vector3(128.0, 2.0, 64.0),
]

@export var water_material: ShaderMaterial
@export var underwater_enabled := true
@export_range(0.0, 0.3, 0.005) var underwater_fog_density := 0.065
@export var reflections_enabled := true
@export_range(0.25, 1.0, 0.05) var reflection_resolution_scale := 0.5

const WATER_LAYER := 524288 # 第 20 层：让倒影摄像机排除海面。
const REFLECTION_CAMERA_MARKER := 262144 # 第 19 层用于标记倒影裁剪渲染通道。

var _reflection_viewport: SubViewport
var _reflection_camera: Camera3D
var _reflection_environment_source: Environment
var _reflection_clip: RefCounted

const SWELLS := [
	Vector4(0.94, 0.342, 0.42, 0.55),
	Vector4(0.643, -0.766, 0.71, 0.25),
	Vector4(-0.259, 0.966, 1.13, 0.13),
	Vector4(0.819, 0.574, 1.91, 0.07),
]
const WAVE_PHASES := [0.0, 1.7, 3.1, 0.8]

var _underwater_layer: CanvasLayer
var _underwater_material: ShaderMaterial
var _effect_camera: Camera3D
var _original_environment: Environment
var _underwater_environment: Environment
var _editor_time := 0.0
var _clock_material: ShaderMaterial

var _vertices := PackedVector3Array()
var _indices := PackedInt32Array()
var _uvs := PackedVector2Array()
var _outer_flags := PackedVector2Array()
var _vertex_ids: Dictionary[Vector2, int] = {}
var _last_center := Vector2(INF, INF)
var _last_material: ShaderMaterial


func _ready() -> void:
	var material := water_material.duplicate() as ShaderMaterial if water_material != null else get_active_material(0) as ShaderMaterial
	mesh = build_water_mesh()
	mesh.surface_set_material(0, material)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	layers = WATER_LAYER
	# 着色器位移和移动网格都必须保持在剔除包围盒内。
	custom_aabb = AABB(Vector3(-2000.0, -3.0, -1500.0), Vector3(4000.0, 6.0, 3000.0))
	_update_center()
	if not Engine.is_editor_hint():
		# 独立运行的世界场景也使用支持暂停的时钟和浸水查询。
		# 游戏可替换此材质，改用游戏自身共享的时钟。
		if material != null and material.get_shader_parameter("use_game_time") != true:
			_clock_material = material
			material.set_shader_parameter("use_game_time", true)
			material.set_shader_parameter("game_time", 0.0)
		_create_underwater_effect()
		_create_reflection()


func _validate_property(property: Dictionary) -> void:
	# 保存场景时不包含生成的网格，从编辑器保存时也一样。
	if property["name"] == "mesh":
		property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_STORAGE


func _process(delta: float) -> void:
	_editor_time += delta
	if _clock_material != null and get_active_material(0) == _clock_material:
		_clock_material.set_shader_parameter("game_time", _editor_time)
	_update_center()
	if not Engine.is_editor_hint():
		_update_underwater()
		_update_reflection()


func _exit_tree() -> void:
	_restore_camera_environment()
	if _reflection_clip != null:
		_reflection_clip.restore()
	if _last_material != null:
		_last_material.set_shader_parameter("use_planar_reflection", false)
		_last_material.set_shader_parameter("planar_reflection", null)


func _create_reflection() -> void:
	_reflection_clip = preload("res://海面倒影裁剪.gd").new()
	_reflection_clip.setup(get_viewport(), global_position.y + 0.02)
	_reflection_viewport = SubViewport.new()
	_reflection_viewport.name = "OceanReflection"
	_reflection_viewport.world_3d = get_world_3d()
	_reflection_viewport.use_hdr_2d = true
	_reflection_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_reflection_viewport)
	_reflection_camera = Camera3D.new()
	_reflection_viewport.add_child(_reflection_camera)
	_reflection_camera.make_current()


func _update_reflection() -> void:
	if _reflection_viewport == null:
		return
	_reflection_clip.update(global_position.y + 0.02)
	var camera := get_viewport().get_camera_3d()
	var material := get_active_material(0) as ShaderMaterial
	var active := reflections_enabled and camera != null and material != null
	if active:
		active = (camera.cull_mask & WATER_LAYER) != 0 and camera.global_position.y > global_position.y + 0.05
	_reflection_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if material == null:
		return
	material.set_shader_parameter("use_planar_reflection", active)
	if not active:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_reflection_viewport.size = Vector2i(maxi(int(viewport_size.x * reflection_resolution_scale), 64), maxi(int(viewport_size.y * reflection_resolution_scale), 64))
	_reflection_camera.cull_mask = (camera.cull_mask & ~(WATER_LAYER | 2)) | REFLECTION_CAMERA_MARKER
	_reflection_camera.projection = camera.projection
	_reflection_camera.fov = camera.fov
	_reflection_camera.size = camera.size
	_reflection_camera.keep_aspect = camera.keep_aspect
	_reflection_camera.near = camera.near
	_reflection_camera.far = camera.far
	_reflection_camera.frustum_offset = camera.frustum_offset
	var mirror_position := camera.global_position
	mirror_position.y = global_position.y * 2.0 - mirror_position.y
	var forward := -camera.global_basis.z
	forward.y = -forward.y
	var up := camera.global_basis.y
	up.y = -up.y
	_reflection_camera.look_at_from_position(mirror_position, mirror_position + forward, up)
	# 保持 HDR 倒影光照为线性值，由主摄像机应用曝光和色调映射。
	var source := get_world_3d().environment
	if source != _reflection_environment_source:
		_reflection_environment_source = source
		_reflection_camera.environment = source.duplicate() as Environment if source != null else Environment.new()
		_reflection_camera.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		_reflection_camera.environment.tonemap_exposure = 1.0
		_reflection_camera.environment.glow_enabled = false
		_reflection_camera.environment.ssr_enabled = false
	if source != null:
		# 昼夜和天气会原地更新 Environment，倒影不能停留在创建时的光照与雾色。
		for parameter in ["ambient_light_source", "ambient_light_color", "ambient_light_energy", "ambient_light_sky_contribution",
			"fog_enabled", "fog_light_color", "fog_light_energy", "fog_sun_scatter", "fog_density", "fog_aerial_perspective", "fog_sky_affect",
			"volumetric_fog_enabled", "volumetric_fog_density", "volumetric_fog_gi_inject"]:
			if _reflection_camera.environment.get(parameter) != source.get(parameter):
				_reflection_camera.environment.set(parameter, source.get(parameter))
	material.set_shader_parameter("planar_reflection", _reflection_viewport.get_texture())
	var view_projection := _reflection_camera.get_camera_projection() * Projection(_reflection_camera.global_transform.affine_inverse())
	material.set_shader_parameter("reflection_view_projection", view_projection)
	material.set_shader_parameter("reflection_plane_height", global_position.y)


func _create_underwater_effect() -> void:
	_underwater_layer = CanvasLayer.new()
	_underwater_layer.name = "UnderwaterEffect"
	# 在所有三维透明物体之后、游戏状态界面和小地图之前绘制。
	_underwater_layer.layer = -1
	_underwater_layer.visible = false
	add_child(_underwater_layer)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_underwater_material = ShaderMaterial.new()
	_underwater_material.shader = preload("res://水下.gdshader")
	rect.material = _underwater_material
	_underwater_layer.add_child(rect)


func _restore_camera_environment() -> void:
	if is_instance_valid(_effect_camera) and _effect_camera.environment == _underwater_environment:
		_effect_camera.environment = _original_environment
	_effect_camera = null
	_original_environment = null
	_underwater_environment = null


func surface_height_at(world_position: Vector3) -> float:
	var material := get_active_material(0) as ShaderMaterial
	if material == null:
		return global_position.y
	var time := _editor_time
	if material.get_shader_parameter("use_game_time") == true:
		time = _float_parameter(material, "game_time", 0.0)
	time *= _float_parameter(material, "wave_speed", 1.0)
	var height := 0.0
	for index in SWELLS.size():
		var wave: Vector4 = SWELLS[index]
		var angle: float = Vector2(world_position.x, world_position.z).dot(Vector2(wave.x, wave.y)) * wave.z - sqrt(9.81 * wave.z) * time + WAVE_PHASES[index]
		height += (sin(angle) + 0.18 * sin(2.0 * angle)) * wave.w
	return global_position.y + height * _float_parameter(material, "wave_height", 0.55) * global_basis.y.length()


func _float_parameter(material: ShaderMaterial, parameter: StringName, fallback: float) -> float:
	# 空渲染器或无界面渲染不会提供着色器 uniform 参数的默认值。
	var value: Variant = material.get_shader_parameter(parameter)
	return float(value) if value != null else fallback


func _update_underwater() -> void:
	if _underwater_layer == null:
		return
	var camera := get_viewport().get_camera_3d()
	var material := get_active_material(0) as ShaderMaterial
	var immersion := 0.0
	var depth := 0.0
	if underwater_enabled and camera != null and material != null and (camera.cull_mask & layers) != 0:
		var local_camera := to_local(camera.global_position)
		if absf(local_camera.x) < WATER_SIZE.x * 0.5 and absf(local_camera.z) < WATER_SIZE.y * 0.5:
			depth = surface_height_at(camera.global_position) - camera.global_position.y
			immersion = smoothstep(-0.08, 0.18, depth)
	_underwater_layer.visible = immersion > 0.001
	if immersion <= 0.001:
		_restore_camera_environment()
		return
	if camera != _effect_camera:
		_restore_camera_environment()
		_effect_camera = camera
		_original_environment = camera.environment
		var source := camera.environment if camera.environment != null else camera.get_world_3d().environment
		_underwater_environment = source.duplicate() as Environment if source != null else Environment.new()
		camera.environment = _underwater_environment
	var base := _original_environment if _original_environment != null else camera.get_world_3d().environment
	_underwater_environment.fog_enabled = true
	_underwater_environment.fog_light_color = Color(0.025, 0.23, 0.28).lerp(base.fog_light_color if base != null else Color.WHITE, 1.0 - immersion)
	_underwater_environment.fog_density = lerpf(base.fog_density if base != null and base.fog_enabled else 0.0, underwater_fog_density, immersion)
	_underwater_environment.fog_sky_affect = immersion
	_underwater_environment.fog_aerial_perspective = 0.0
	_underwater_environment.fog_sun_scatter = 0.0
	_underwater_material.set_shader_parameter("immersion", immersion)
	_underwater_material.set_shader_parameter("camera_depth", maxf(depth, 0.0))
	var time := _float_parameter(material, "game_time", 0.0) if material.get_shader_parameter("use_game_time") == true else _editor_time
	_underwater_material.set_shader_parameter("game_time", time)


func _update_center() -> void:
	var material := get_active_material(0) as ShaderMaterial
	if material == null:
		return
	var center := Vector2.ZERO
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var local_camera := to_local(camera.global_position)
		center = Vector2(local_camera.x, local_camera.z).snapped(Vector2.ONE * NEAR_STEP)
	if center == _last_center and material == _last_material:
		return
	material.set_shader_parameter("lod_center", center)
	material.set_shader_parameter("use_distance_lod", true)
	material.set_shader_parameter("water_half_size", WATER_SIZE * 0.5)
	material.set_shader_parameter("wave_full_distance", FULL_WAVE_DISTANCE)
	material.set_shader_parameter("wave_end_distance", END_WAVE_DISTANCE)
	_last_center = center
	_last_material = material


func build_water_mesh() -> ArrayMesh:
	_vertices.clear()
	_indices.clear()
	_uvs.clear()
	_outer_flags.clear()
	_vertex_ids.clear()
	for ring: Vector3 in RINGS:
		_add_ring(ring.x, ring.y, ring.z)
	_add_far_border()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	var normals := PackedVector3Array()
	normals.resize(_vertices.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_TEX_UV2] = _outer_flags
	arrays[Mesh.ARRAY_INDEX] = _indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# 释放构建缓冲区，此时几何数据已由 ArrayMesh 持有。
	_vertices = PackedVector3Array()
	_indices = PackedInt32Array()
	_uvs = PackedVector2Array()
	_outer_flags = PackedVector2Array()
	_vertex_ids.clear()
	return result


func _vertex(point: Vector2) -> int:
	if _vertex_ids.has(point):
		return _vertex_ids[point]
	var index := _vertices.size()
	_vertex_ids[point] = index
	_vertices.append(Vector3(point.x, 0.0, point.y))
	_uvs.append(Vector2.ZERO)
	_outer_flags.append(Vector2.ZERO)
	return index


func _triangle(a: int, b: int, c: int) -> void:
	_indices.append(a)
	_indices.append(b)
	_indices.append(c)


func _add_ring(outer: float, step: float, inner: float) -> void:
	var cells := int(outer * 2.0 / step)
	for z_index in cells:
		var z := -outer + z_index * step
		for x_index in cells:
			var x := -outer + x_index * step
			if inner > 0.0 and x >= -inner and x < inner and z >= -inner and z < inner:
				continue
			var a := Vector2(x, z)
			var b := Vector2(x + step, z)
			var c := Vector2(x + step, z + step)
			var d := Vector2(x, z + step)
			# 在每条共享边上插入细网格环的中点，消除 T 形接缝，
			# 即使波浪使边缘发生垂直位移，也能保持接合。
			var split_top := inner > 0.0 and z == inner and x >= -inner and x < inner
			var split_right := inner > 0.0 and x + step == -inner and z >= -inner and z < inner
			var split_bottom := inner > 0.0 and z + step == -inner and x >= -inner and x < inner
			var split_left := inner > 0.0 and x == inner and z >= -inner and z < inner
			if not (split_top or split_right or split_bottom or split_left):
				_triangle(_vertex(a), _vertex(b), _vertex(c))
				_triangle(_vertex(a), _vertex(c), _vertex(d))
				continue
			var edge: Array[int] = [_vertex(a)]
			if split_top:
				edge.append(_vertex((a + b) * 0.5))
			edge.append(_vertex(b))
			if split_right:
				edge.append(_vertex((b + c) * 0.5))
			edge.append(_vertex(c))
			if split_bottom:
				edge.append(_vertex((c + d) * 0.5))
			edge.append(_vertex(d))
			if split_left:
				edge.append(_vertex((d + a) * 0.5))
			var middle := _vertex((a + c) * 0.5)
			for index in edge.size():
				_triangle(middle, edge[index], edge[(index + 1) % edge.size()])


func _add_far_border() -> void:
	# 四个平面梯形延伸至原始地图边界，其完整内边缘与精细网格共享。
	# UV2 为着色器标记位置固定的边界顶点。
	var corners: Array[Vector2] = [
		Vector2(-128.0, -128.0), Vector2(128.0, -128.0),
		Vector2(128.0, 128.0), Vector2(-128.0, 128.0),
	]
	for side in 4:
		var a := corners[side]
		var b := corners[(side + 1) % 4]
		var outer_a := _vertices.size()
		for corner: Vector2 in [a, b]:
			var uv := (corner / 128.0 + Vector2.ONE) * 0.5
			var point := (uv * 2.0 - Vector2.ONE) * WATER_SIZE * 0.5
			_vertices.append(Vector3(point.x, 0.0, point.y))
			_uvs.append(uv)
			_outer_flags.append(Vector2(1.0, 0.0))
		var outer_b := outer_a + 1
		for segment in 128:
			var inner_a := _vertex(a.lerp(b, segment / 128.0))
			var inner_b := _vertex(a.lerp(b, (segment + 1) / 128.0))
			_triangle(inner_a, outer_a, inner_b)
		_triangle(_vertex(b), outer_a, outer_b)
