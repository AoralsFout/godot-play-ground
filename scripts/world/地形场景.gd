@tool
extends Node3D
## 统一导入地形的材质及主视图、小地图渲染层。

@export var terrain_material: ShaderMaterial:
	set(value):
		terrain_material = value
		if is_node_ready():
			_apply_terrain()
@export_node_path("Node3D") var water_path := NodePath("../水面")

var _sea_level := INF


func _ready() -> void:
	_apply_terrain()
	_sync_sea_level()


func _apply_terrain() -> void:
	var terrain := get_node_or_null("超大地形")
	if terrain == null:
		return
	for node in terrain.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		instance.layers = 3
		instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		if str(instance.name).begins_with("地形块_"):
			instance.material_override = terrain_material
	_sea_level = INF


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
