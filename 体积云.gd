@tool
extends WorldEnvironment
## 天空体积云：编辑器可预览，运行时随场景树暂停。高度使用世界坐标。

const CLOUD_SKY := preload("res://体积云天空.tres")

@export_group("体积云 · 形态")
@export var clouds_enabled := true:
	set(value):
		clouds_enabled = value
		_apply_settings()
@export_range(0.0, 1.0, 0.01) var cloud_coverage := 0.56:
	set(value):
		cloud_coverage = value
		_apply_settings()
@export_range(0.0, 3.0, 0.05) var cloud_density := 1.1:
	set(value):
		cloud_density = value
		_apply_settings()
@export_range(20.0, 2000.0, 10.0) var cloud_base := 180.0:
	set(value):
		cloud_base = value
		_apply_settings()
@export_range(20.0, 1000.0, 10.0) var cloud_thickness := 160.0:
	set(value):
		cloud_thickness = value
		_apply_settings()
@export_range(100.0, 3000.0, 10.0) var cloud_scale := 700.0:
	set(value):
		cloud_scale = value
		_apply_settings()

@export_group("体积云 · 动画与质量")
## X/Z 方向的风速，单位为米/秒。
@export var wind_velocity := Vector2(6.0, 2.0):
	set(value):
		wind_velocity = value
		_apply_settings()
@export_enum("低:24", "中:48", "高:72") var ray_steps := 48:
	set(value):
		ray_steps = value
		_apply_settings()
@export var animate_in_editor := false

var cloud_time := 0.0
var cloud_material: ShaderMaterial


func _ready() -> void:
	# 每个世界独立持有动画和材质，仅共享不可变的噪声资源。
	environment = environment.duplicate() if environment != null else Environment.new()
	environment.sky = CLOUD_SKY.duplicate()
	cloud_material = CLOUD_SKY.sky_material.duplicate() as ShaderMaterial
	environment.sky.sky_material = cloud_material
	environment.background_mode = Environment.BG_SKY
	_apply_settings()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not animate_in_editor:
		return
	cloud_time += delta
	cloud_material.set_shader_parameter("cloud_time", cloud_time)


func _apply_settings() -> void:
	if cloud_material == null:
		return
	cloud_material.set_shader_parameter("cloud_coverage", cloud_coverage if clouds_enabled else 0.0)
	cloud_material.set_shader_parameter("cloud_density", cloud_density)
	cloud_material.set_shader_parameter("cloud_base", cloud_base)
	cloud_material.set_shader_parameter("cloud_thickness", cloud_thickness)
	cloud_material.set_shader_parameter("cloud_scale", cloud_scale)
	cloud_material.set_shader_parameter("wind_velocity", wind_velocity)
	cloud_material.set_shader_parameter("ray_steps", ray_steps)
