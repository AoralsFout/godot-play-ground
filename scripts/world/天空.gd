@tool
extends WorldEnvironment
## 太阳角度驱动连续昼夜色彩，独立月光照亮夜空和海面。

const CLEAR_SKY := preload("res://materials/晴空.tres")

@export_group("天空 · 太阳与昼夜")
## 直接旋转这个日光节点即可改变天空，编辑器静止预览也会更新。
@export_node_path("DirectionalLight3D") var sun_path := NodePath("../日光"):
	set(value):
		sun_path = value
		_sun = null
		_apply_settings()
## 自动以太阳水平朝向区分早晚；相同高度也可手动指定日出或日落风格。
@export_enum("自动方位", "日出", "日落") var twilight_style := 0:
	set(value):
		twilight_style = value
		_apply_settings()
## 太阳落下的一侧，0° 为 +Z，180° 为 -Z。
@export_range(-180.0, 180.0, 1.0) var sunset_azimuth := 180.0:
	set(value):
		sunset_azimuth = value
		_apply_settings()
@export_range(0.0, 4.0, 0.05) var daylight_energy := 1.15:
	set(value):
		daylight_energy = value
		_apply_settings()
@export_range(0.0, 2.0, 0.01) var daylight_ambient_energy := 0.65:
	set(value):
		daylight_ambient_energy = value
		_apply_settings()
@export_range(0.0, 0.2, 0.005) var night_ambient_energy := 0.035:
	set(value):
		night_ambient_energy = value
		_apply_settings()

@export_group("天空 · 独立月亮")
## 使用独立的方向光控制月亮。旋转月光节点，X/Y 分别改变高度和方位。
@export_node_path("DirectionalLight3D") var moon_path := NodePath("../月光"):
	set(value):
		moon_path = value
		_moon = null
		_apply_settings()
@export var moon_enabled := true:
	set(value):
		moon_enabled = value
		_apply_settings()
## 夜间最大直射光强度，随月亮高度调节照明。
@export_range(0.0, 1.0, 0.01) var moonlight_energy := 0.25:
	set(value):
		moonlight_energy = value
		_apply_settings()
@export var moonlight_color := Color(0.76, 0.84, 1.0):
	set(value):
		moonlight_color = value
		_apply_settings()
## 天空中的月亮直径，单位为度。
@export_range(0.2, 4.0, 0.05) var moon_angular_size := 1.2:
	set(value):
		moon_angular_size = value
		_apply_settings()

# 每个高度包含天顶和地平线颜色，相邻关键帧平滑插值。
const PALETTE_HEIGHTS := [-18.0, -10.0, -5.0, 0.0, 7.0, 25.0, 90.0]
const SKY_PALETTE := [
	[Color(0.004, 0.008, 0.025), Color(0.018, 0.028, 0.065)],
	[Color(0.11, 0.21, 0.48), Color(0.32, 0.43, 0.68)],
	[Color(0.12, 0.20, 0.43), Color(0.52, 0.28, 0.40)],
	[Color(0.16, 0.25, 0.46), Color(0.95, 0.48, 0.25)],
	[Color(0.16, 0.36, 0.66), Color(0.93, 0.73, 0.51)],
	[Color(0.12, 0.36, 0.72), Color(0.66, 0.81, 0.94)],
	[Color(0.09, 0.29, 0.64), Color(0.67, 0.82, 0.94)],
]

var sky_material: ShaderMaterial
var solar_elevation := 0.0
var sky_phase := "晴天"
var _sun: DirectionalLight3D
var _last_sun_direction := Vector3(INF, INF, INF)
var _last_sun_visible := true
var _moon: DirectionalLight3D
var _last_moon_direction := Vector3(INF, INF, INF)
var _last_moon_visible := false
var _water_material: ShaderMaterial


func _ready() -> void:
	# 每个世界独立持有环境和天空材质。
	environment = environment.duplicate() if environment != null else Environment.new()
	environment.sky = CLEAR_SKY.duplicate()
	sky_material = CLEAR_SKY.sky_material.duplicate() as ShaderMaterial
	environment.sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	_apply_settings()


func _process(_delta: float) -> void:
	if sky_material == null:
		return
	if not is_instance_valid(_sun):
		_sun = get_node_or_null(sun_path) as DirectionalLight3D
	var direction := _sun.global_basis.z.normalized() if _sun != null else Vector3(0.45, 0.46, 0.77).normalized()
	var sun_visible := _sun.is_visible_in_tree() if _sun != null else true
	if not is_instance_valid(_moon):
		_moon = get_node_or_null(moon_path) as DirectionalLight3D
	var moon_direction := _moon.global_basis.z.normalized() if _moon != null else Vector3.UP
	var moon_visible := _moon.is_visible_in_tree() if _moon != null else false
	if not direction.is_equal_approx(_last_sun_direction) or sun_visible != _last_sun_visible \
			or not moon_direction.is_equal_approx(_last_moon_direction) or moon_visible != _last_moon_visible:
		_update_atmosphere(direction, sun_visible)
	# 主场景会替换水面材质，使用实际正在渲染的材质。
	_sync_water()


func _apply_settings() -> void:
	if sky_material == null:
		return
	if is_inside_tree():
		_sun = get_node_or_null(sun_path) as DirectionalLight3D
		_update_atmosphere(_sun.global_basis.z.normalized() if _sun != null else Vector3(0.45, 0.46, 0.77).normalized(),
			_sun.is_visible_in_tree() if _sun != null else true)


func _palette_at(elevation: float, channel: int) -> Color:
	for index in range(1, PALETTE_HEIGHTS.size()):
		if elevation <= PALETTE_HEIGHTS[index]:
			var blend := smoothstep(PALETTE_HEIGHTS[index - 1], PALETTE_HEIGHTS[index], elevation)
			return SKY_PALETTE[index - 1][channel].lerp(SKY_PALETTE[index][channel], blend)
	return SKY_PALETTE[-1][channel]


func _update_atmosphere(to_sun: Vector3, sun_visible: bool) -> void:
	_last_sun_direction = to_sun
	_last_sun_visible = sun_visible
	solar_elevation = rad_to_deg(asin(clampf(to_sun.y, -1.0, 1.0)))
	var daylight := smoothstep(-7.0, 22.0, solar_elevation)
	var direct_light := smoothstep(-1.5, 12.0, solar_elevation)
	var twilight := smoothstep(-13.0, -3.0, solar_elevation) * (1.0 - smoothstep(3.0, 20.0, solar_elevation))
	var azimuth := deg_to_rad(sunset_azimuth)
	var horizontal := Vector3(to_sun.x, 0.0, to_sun.z).normalized()
	var evening := smoothstep(-0.35, 0.35, horizontal.dot(Vector3(sin(azimuth), 0.0, cos(azimuth))))
	if twilight_style != 0:
		evening = 1.0 if twilight_style == 2 else 0.0
	_moon = get_node_or_null(moon_path) as DirectionalLight3D
	var to_moon := _moon.global_basis.z.normalized() if _moon != null else Vector3.UP
	var moon_visible := _moon.is_visible_in_tree() if _moon != null else false
	_last_moon_direction = to_moon
	_last_moon_visible = moon_visible
	# 只调节月光强度，始终不改变月光节点的位置、旋转或太阳的方向。
	var moon_visibility := (1.0 - smoothstep(-12.0, 2.0, solar_elevation)) * smoothstep(0.0, 0.18, to_moon.y)
	if not moon_enabled or not moon_visible:
		moon_visibility = 0.0
	var lunar_strength := moonlight_energy * moon_visibility
	var zenith := _palette_at(solar_elevation, 0)
	var horizon := _palette_at(solar_elevation, 1)
	# 日出偏清透珊瑚色，晚霞偏玫瑰紫；仍保留日光方向上的金橙色辉光。
	horizon = horizon.lerp(Color(0.73, 0.34, 0.48), twilight * evening * 0.32)
	zenith = zenith.lerp(Color(0.16, 0.14, 0.34), twilight * evening * 0.20)
	# 月光为夜空和水面反射提供低亮度底色，不抹去蓝调和晚霞。
	var lunar_fill := moon_visibility * clampf(moonlight_energy / 0.25, 0.0, 2.0)
	zenith += Color(0.035, 0.055, 0.10, 0.0) * lunar_fill
	horizon += Color(0.055, 0.075, 0.11, 0.0) * lunar_fill
	var sun_color := Color(1.0, 0.32, 0.10).lerp(Color(1.0, 0.97, 0.90), smoothstep(0.0, 24.0, solar_elevation))
	var sun_strength := daylight_energy * direct_light if sun_visible else 0.0
	sky_material.set_shader_parameter("sky_sun_direction", to_sun)
	sky_material.set_shader_parameter("sun_color", sun_color)
	sky_material.set_shader_parameter("sun_visibility", smoothstep(-4.0, -0.5, solar_elevation) if sun_visible else 0.0)
	sky_material.set_shader_parameter("daylight", daylight)
	sky_material.set_shader_parameter("twilight", twilight)
	sky_material.set_shader_parameter("zenith_color", zenith)
	sky_material.set_shader_parameter("horizon_color", horizon)
	sky_material.set_shader_parameter("sky_moon_direction", to_moon)
	sky_material.set_shader_parameter("moon_color", moonlight_color)
	sky_material.set_shader_parameter("moon_visibility", moon_visibility)
	sky_material.set_shader_parameter("moon_angular_radius", deg_to_rad(moon_angular_size * 0.5))
	if _sun != null:
		_sun.light_color = sun_color
		_sun.light_energy = sun_strength
	if _moon != null:
		_moon.light_color = moonlight_color
		_moon.light_energy = lunar_strength
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_sky_contribution = 0.0
	environment.ambient_light_color = horizon.lerp(zenith, 0.45).lerp(Color(0.80, 0.88, 1.0), daylight * 0.65)
	environment.ambient_light_color = environment.ambient_light_color.lerp(moonlight_color * 0.75, clampf(lunar_fill * 0.65, 0.0, 1.0))
	var ambient_daylight := smoothstep(-14.0, 18.0, solar_elevation)
	environment.ambient_light_energy = (lerpf(night_ambient_energy, daylight_ambient_energy, ambient_daylight)
		+ twilight * 0.06 + lunar_strength * 0.30)
	environment.fog_light_color = horizon
	environment.fog_light_energy = lerpf(0.12, 1.0, daylight)
	environment.fog_sun_scatter = 0.08 * direct_light
	environment.fog_density = 0.00035
	sky_phase = "夜晚" if solar_elevation < -12.0 else ("蓝调时刻" if solar_elevation < -6.0 else (
		"晚霞" if evening > 0.5 else "晨曦"))
	if solar_elevation >= -1.0:
		sky_phase = ("日落" if evening > 0.5 else "日出") if solar_elevation < 5.0 else ("金色时刻" if solar_elevation < 15.0 else "晴天")
	_sync_water(true)


func _sync_water(force := false) -> void:
	var water := get_node_or_null("../水面") as MeshInstance3D
	if water == null or water.mesh == null:
		return
	var material := water.get_active_material(0) as ShaderMaterial
	if material != null and (force or material != _water_material):
		_water_material = material
		material.set_shader_parameter("sky_zenith", sky_material.get_shader_parameter("zenith_color"))
		material.set_shader_parameter("sky_horizon", sky_material.get_shader_parameter("horizon_color"))
		var ambient := environment.ambient_light_color.srgb_to_linear()
		material.set_shader_parameter("water_ambient_light", Vector3(ambient.r, ambient.g, ambient.b) * environment.ambient_light_energy)
