## 生成贴地的蓄力攻击范围提示网格。
## 与战斗逻辑共用半径和角度，向下采样地面适应坡道，仅承担视觉提示。

extends MeshInstance3D
## 显示和命中共用半径与角度；显示网格向下采样地面，适应坡道。
var radius := 5.0
var angle_degrees := 34.0
var _material := StandardMaterial3D.new()
var _refresh := 0.0

func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.no_depth_test = false
	material_override = _material
	visible = false

func set_charge(ratio: float) -> void:
	_material.albedo_color = Color(1.0, 0.65, 0.65, 0.20).lerp(Color(0.85, 0.08, 0.12, 0.64), ratio)

func _process(delta: float) -> void:
	if not visible:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.05
		_rebuild()

func _ground_point(local_point: Vector3) -> Vector3:
	var world_point := to_global(local_point)
	var query := PhysicsRayQueryParameters3D.create(world_point + Vector3.UP * 1.8, world_point + Vector3.DOWN * 4.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		world_point.y = hit.position.y + 0.035
	return to_local(world_point)

func _rebuild() -> void:
	var vertices := PackedVector3Array()
	var points: Array[Vector3] = [_ground_point(Vector3.ZERO)]
	const SEGMENTS := 24
	var half_angle := deg_to_rad(angle_degrees * 0.5)
	for i in SEGMENTS + 1:
		var angle := lerpf(-half_angle, half_angle, float(i) / SEGMENTS)
		points.append(_ground_point(Vector3(sin(angle), 0.0, -cos(angle)) * radius))
	for i in SEGMENTS:
		vertices.append(points[0])
		vertices.append(points[i + 1])
		vertices.append(points[i + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var surface := ArrayMesh.new()
	surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = surface

static func contains(offset: Vector3, forward: Vector3, reach: float, angle: float, body_radius: float = 0.0) -> bool:
	if absf(offset.y) > 1.8:
		return false
	var flat := Vector2(offset.x, offset.z)
	var distance := flat.length()
	if distance > reach + body_radius:
		return false
	if distance <= body_radius:
		return true
	var facing := Vector2(forward.x, forward.z).normalized()
	var angular_padding := asin(clampf(body_radius / distance, 0.0, 1.0))
	return acos(clampf(facing.dot(flat / distance), -1.0, 1.0)) <= deg_to_rad(angle * 0.5) + angular_padding
