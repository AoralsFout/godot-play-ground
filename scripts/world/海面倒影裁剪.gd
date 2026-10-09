## 为海面倒影中的导入模型提供平面裁剪。
## 在网格实例上覆盖材质并跟随源颜色，退出时还原覆盖，避免修改共享导入资源。

extends RefCounted
## 为世界中导入的纯色 PBR 材质添加仅用于倒影的裁剪。
## 覆盖设置保存在网格实例上，导入资源和烘焙的全局光照（GI）保持不变。

var _viewport: Viewport
var _height := 0.0
var _pending: Array[MeshInstance3D] = []
var _materials: Dictionary[BaseMaterial3D, ShaderMaterial] = {}
var _overrides: Array[Dictionary] = []

const CLIP_CODE := """
uniform float ocean_reflection_height;
void fragment() {
	// VERTEX 是包含蒙皮变形的最终视图空间片元位置。
	if ((CAMERA_VISIBLE_LAYERS & 786432u) == 262144u &&
		(INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y < ocean_reflection_height) {
		discard;
	}
	ALBEDO = ocean_albedo.rgb;
	METALLIC = ocean_metallic;
	ROUGHNESS = ocean_roughness;
	SPECULAR = ocean_specular;
	EMISSION = ocean_emission.rgb * ocean_emission_energy;
}
"""


func setup(viewport: Viewport, height: float) -> void:
	_viewport = viewport
	_height = height
	_collect(viewport)
	viewport.get_tree().node_added.connect(_node_added)


func _collect(node: Node) -> void:
	if node is Viewport and node != _viewport:
		return
	_node_added(node)
	for child in node.get_children():
		_collect(child)


func _node_added(node: Node) -> void:
	if node is MeshInstance3D and node.get_viewport() == _viewport:
		_pending.append(node)


func update(height: float) -> void:
	if not is_equal_approx(_height, height):
		_height = height
		for material in _materials.values():
			material.set_shader_parameter("ocean_reflection_height", height)
	# 等待新生成对象在 _ready() 中完成网格和材质的赋值。
	for node in _pending:
		if not is_instance_valid(node) or node.mesh == null or (node.layers & ~524290) == 0:
			continue
		if node.material_override is BaseMaterial3D:
			_overrides.append({"node": weakref(node), "surface": -1, "original": node.material_override})
			node.material_override = _clipped_material(node.material_override)
		else:
			for surface in node.mesh.get_surface_count():
				var source := node.get_active_material(surface) as BaseMaterial3D
				if source == null:
					continue
				_overrides.append({"node": weakref(node), "surface": surface, "original": node.get_surface_override_material(surface)})
				node.set_surface_override_material(surface, _clipped_material(source))
	_pending.clear()
	# 材质被替换后仍需跟随源颜色；albedo_color 的修改不触发 changed 信号。
	for source: BaseMaterial3D in _materials:
		var material: ShaderMaterial = _materials[source]
		if material.get_shader_parameter("ocean_albedo") != source.albedo_color:
			material.set_shader_parameter("ocean_albedo", source.albedo_color)


func _clipped_material(source: BaseMaterial3D) -> ShaderMaterial:
	if _materials.has(source):
		return _materials[source]
	# 海岛的导入材质仅使用均匀、不透明的反照率、PBR 和自发光参数。
	# 匹配材质原有的渲染模式和参数，保持光照效果一致。
	var shader := Shader.new()
	var modes := ["blend_mix", "depth_draw_opaque", "diffuse_burley", "specular_schlick_ggx"]
	modes.append(["cull_back", "cull_front", "cull_disabled"][source.cull_mode])
	if source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		modes.append("unshaded")
	elif source.shading_mode == BaseMaterial3D.SHADING_MODE_PER_VERTEX:
		modes.append("vertex_lighting")
	shader.code = "shader_type spatial;\nrender_mode " + ", ".join(modes) + ";\n" + """
uniform vec4 ocean_albedo : source_color;
uniform float ocean_metallic;
uniform float ocean_roughness;
uniform float ocean_specular;
uniform vec4 ocean_emission : source_color;
uniform float ocean_emission_energy;
""" + CLIP_CODE
	var result := ShaderMaterial.new()
	result.shader = shader
	result.render_priority = source.render_priority
	result.set_shader_parameter("ocean_albedo", source.albedo_color)
	result.set_shader_parameter("ocean_metallic", source.metallic)
	result.set_shader_parameter("ocean_roughness", source.roughness)
	result.set_shader_parameter("ocean_specular", source.metallic_specular)
	result.set_shader_parameter("ocean_emission", source.emission if source.emission_enabled else Color.BLACK)
	result.set_shader_parameter("ocean_emission_energy", source.emission_energy_multiplier)
	result.set_shader_parameter("ocean_reflection_height", _height)
	_materials[source] = result
	return result


func restore() -> void:
	if is_instance_valid(_viewport) and _viewport.get_tree().node_added.is_connected(_node_added):
		_viewport.get_tree().node_added.disconnect(_node_added)
	for entry in _overrides:
		var node: MeshInstance3D = entry.node.get_ref()
		if not is_instance_valid(node):
			continue
		if entry.surface == -1:
			node.material_override = entry.original
		else:
			node.set_surface_override_material(entry.surface, entry.original)
	_overrides.clear()
	_pending.clear()
	_materials.clear()
