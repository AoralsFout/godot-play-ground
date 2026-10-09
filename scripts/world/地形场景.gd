## 统一第二版地图材质、渲染层与导入碰撞。
## 以路网整平地形替换原地表，为肋柱、道路和桥梁开启双面碰撞，并同步实际海平面。

@tool
extends Node3D
## 统一导入地形的材质及主视图、小地图渲染层。

## 地图地表共用的着色器材质；统一应用到地形网格，并接收实际海平面高度。
@export var terrain_material: ShaderMaterial:
	set(value):
		terrain_material = value
		if is_node_ready():
			_apply_terrain()
## 水面节点相对地图的路径；其世界 Y 坐标决定海拔分色，节点缺失时回退到 15 米。
@export_node_path("Node3D") var water_path := NodePath("../水面")

var _sea_level := INF


func _ready() -> void:
	_apply_terrain()
	_sync_sea_level()


func _apply_terrain() -> void:
	var terrain := get_node_or_null("超大地形v2")
	if terrain == null:
		return
	for node in terrain.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		instance.layers = 3
		instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		if str(instance.name).begins_with("巨构肋柱") or str(instance.name).begins_with("道路") or str(instance.name).begins_with("桥梁"):
			_enable_double_sided_collision(instance)
		if str(instance.name).begins_with("地形"):
			instance.material_override = terrain_material
	_disable_original_v2_terrain(terrain)
	_sea_level = INF


func _disable_original_v2_terrain(terrain: Node3D) -> void:
	# 削坡填方地形同时替换旧地表的渲染和碰撞，避免山体穿过平整路面。
	if terrain.get_node_or_null("路网/地形_整平") == null:
		return
	var original := terrain.get_node_or_null("地形") as MeshInstance3D
	if original == null:
		return
	original.visible = false
	for body: StaticBody3D in original.find_children("*", "StaticBody3D", true, false):
		body.collision_layer = 0
		body.collision_mask = 0


func _disable_hidden_terrain_collision() -> void:
	# 隐藏旧地图只影响渲染；它的碰撞也必须关闭，避免与 v2 重叠。
	var old_terrain := get_node_or_null("超大地形") as Node3D
	if old_terrain == null or old_terrain.visible:
		return
	for body: StaticBody3D in old_terrain.find_children("*", "StaticBody3D", true, false):
		body.collision_layer = 0
		body.collision_mask = 0


func _enable_double_sided_collision(instance: MeshInstance3D) -> void:
	# -col 导入的三角网格默认只有单面碰撞。镜像肋柱和道路的背面也需阻挡玩家。
	for collision: CollisionShape3D in instance.find_children("*", "CollisionShape3D", true, false):
		var shape := collision.shape as ConcavePolygonShape3D
		if shape == null or shape.backface_collision:
			continue
		# 导入资源可能由多个实例共享，避免修改资源影响其他模型。
		shape = shape.duplicate() as ConcavePolygonShape3D
		shape.backface_collision = true
		collision.shape = shape


func _process(_delta: float) -> void:
	_sync_sea_level()


func _sync_sea_level() -> void:
	if terrain_material == null:
		return
	var water := get_node_or_null(water_path) as Node3D
	var height := water.global_position.y if water != null else 15.0
	if not is_equal_approx(_sea_level, height):
		_sea_level = height
		terrain_material.set_shader_parameter("sea_level", height)
