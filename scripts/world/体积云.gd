## 配置并同步球壳体积云的密度、噪声、光照和后处理。
## 连接天空日月状态、地面云影与海面倒影，编辑器使用基础预览，运行时优先使用计算合成器。

@tool
extends Node3D
## 来自 volume-cloude 的球壳体积云，使用世界环境合成，摄像机由当前视口提供。

enum DensityMode { MAP_ONLY, PERLIN, PERLIN_WORLEY, CHANNELS }

const NOISE_MIPMAPS = preload("res://scripts/clouds/cloud_noise_mipmaps.gd")
const POST_EFFECT = preload("res://scripts/clouds/cloud_postprocess_effect.gd")
const CLOUD_SHADER = preload("res://shaders/clouds/minimal_volume_cloud.gdshader")

## 云覆盖和类型数据纹理；红绿通道参与覆盖，蓝通道影响类型，应使用数值纹理而非颜色贴图。
@export var cloud_map: Texture2D = preload("res://assets/clouds/cloud_map.png"):
	set(value):
		cloud_map = value
		_refresh_cloud()
## 红绿覆盖通道的混合比例；0 使用红通道，1 使用绿通道，影响大型云形分布。
@export_range(0.0, 1.0, 0.001) var coverage_blend: float = 0.5:
	set(value):
		coverage_blend = clampf(value, 0.0, 1.0)
		_refresh_cloud()
## 整体云量；0 清空，0.5 保留原图，1 最大化红绿覆盖，云图范围外仍保持无云。
@export_range(0.0, 1.0, 0.001) var coverage_amount: float = 0.5:
	set(value):
		coverage_amount = clampf(value, 0.0, 1.0)
		_refresh_cloud()
## 云类型偏置；改变高度剖面的类型混合，不平移云图或噪声。
@export_range(-1.0, 1.0, 0.001) var cloud_type_bias: float = 0.0:
	set(value):
		cloud_type_bias = clampf(value, -1.0, 1.0)
		_refresh_cloud()
## 云密度倍率；越大云越厚重，0 不产生密度。
@export_range(0.0, 10.0, 0.01) var density_multiplier: float = 1.0:
	set(value):
		density_multiplier = clampf(value, 0.0, 10.0)
		_refresh_cloud()
@export_group("Spherical layer")
# 固定北极切平面基点；实际球心为这个位置向下 planet_radius 米。
## 星球北极切平面的世界基点（米）；球心位于此点下方一个半径，固定该点可避免云随相机漂移。
@export var planet_surface_origin := Vector3.ZERO:
	set(value):
		planet_surface_origin = value
		_refresh_cloud()
## 星球半径（米）；影响云层曲率、地平线和星球遮挡，不改变地图几何。
@export_range(100000.0, 20000000.0, 1000.0) var planet_radius: float = 6371000.0:
	set(value):
		planet_radius = clampf(value, 100000.0, 20000000.0)
		_refresh_cloud()
## 云层底部相对星球表面的高度（米）；应小于顶部高度，影响可进入云层的位置。
@export_range(100.0, 19900.0, 50.0) var cloud_bottom: float = 1500.0:
	set(value):
		cloud_bottom = clampf(value, 100.0, 19900.0)
		if cloud_top < cloud_bottom + 100.0:
			cloud_top = cloud_bottom + 100.0
		_refresh_cloud()
## 云层顶部相对星球表面的高度（米）；应大于底部高度，增厚后光程和云体积随之增加。
@export_range(200.0, 20000.0, 50.0) var cloud_top: float = 4000.0:
	set(value):
		cloud_top = clampf(value, cloud_bottom + 100.0, 20000.0)
		_refresh_cloud()
## 云图中心的世界 X/Z 坐标（米）；改变大型云形覆盖区域。
@export var cloud_map_center := Vector2.ZERO:
	set(value):
		cloud_map_center = value
		_refresh_cloud()
## 云图覆盖的边长（米）；越大同一图案越宽，边缘之外不重复采样。
@export_range(20000.0, 2000000.0, 10000.0) var cloud_map_extent: float = 600000.0:
	set(value):
		cloud_map_extent = clampf(value, 20000.0, 2000000.0)
		_refresh_cloud()
# 消光按每米计；随厚度从 60 m 增至 2500 m 按比例降低默认值。
## 云消光系数（每米）；越大透光越少，需结合密度与云层厚度调节。
@export_range(0.0, 0.02, 0.0001) var extinction: float = 0.00192:
	set(value):
		extinction = value
		_refresh_cloud()
## 视线步进最大次数；越大细节越稳定且显卡成本越高，实际预算还会按方向和空域调整。
@export_range(16, 192, 1) var march_steps: int = 96:
	set(value):
		march_steps = value
		_refresh_cloud()
## 云视线的最远积分距离（米）；影响远景范围，也受场景深度截断。
@export_range(10000.0, 1000000.0, 10000.0) var max_distance: float = 300000.0:
	set(value):
		max_distance = clampf(value, 10000.0, 1000000.0)
		_refresh_cloud()
## 开始降低高频云细节的距离尺度（米）；增大保留更多远景细节并增加噪声采样成本。
@export_range(10000.0, 300000.0, 1000.0) var detail_distance: float = 80000.0:
	set(value):
		detail_distance = clampf(value, 10000.0, 300000.0)
		_refresh_cloud()
## 云层远景大气融合强度；越大远云越接近天空雾色。
@export_range(0.0, 1.0, 0.01) var haze_strength: float = 0.75:
	set(value):
		haze_strength = clampf(value, 0.0, 1.0)
		_refresh_cloud()

@export_group("Post processing")
## 计算后处理开关；运行时优先使用计算合成，关闭后回退基础云预览且不生成计算光束。
@export var post_processing_enabled: bool = true:
	set(value):
		post_processing_enabled = value
		_refresh_cloud()
## 大气总体密度倍率；提高会增强远景消光和大气融合。
@export_range(0.0, 3.0, 0.01) var atmosphere_density: float = 1.0:
	set(value):
		atmosphere_density = clampf(value, 0.0, 3.0)
		_refresh_cloud()
## 日月光束开关；仅在计算后处理有效时产生光束，基础预览不绘制。
@export var light_shafts_enabled: bool = true:
	set(value):
		light_shafts_enabled = value
		_refresh_cloud()
## 光束合成强度倍率；0 隐藏光束，不改变云密度。
@export_range(0.0, 3.0, 0.01) var light_shaft_strength: float = 1.0:
	set(value):
		light_shaft_strength = clampf(value, 0.0, 3.0)
		_refresh_cloud()
## 光束散射开始距离（米）；近景逐渐启用，几何深度会截断被遮挡部分。
@export_range(500.0, 10000.0, 100.0) var light_shaft_start: float = 500.0:
	set(value):
		light_shaft_start = clampf(value, 500.0, 10000.0)
		_refresh_cloud()
## 径向光束模糊采样次数；越大越平滑，同时增加计算成本。
@export_range(16, 64, 1) var light_shaft_samples: int = 64:
	set(value):
		light_shaft_samples = clampi(value, 16, 64)
		_refresh_cloud()
## 太阳周围高光的半强度角。扩大这个角度可让远离圆盘的云隙参与光束。
## 光源周围高光的半强度角（度）；越大越远的云隙也参与光束，不改变日月盘尺寸。
@export_range(5.0, 60.0, 1.0) var light_shaft_spread: float = 35.0:
	set(value):
		light_shaft_spread = clampf(value, 5.0, 60.0)
		_refresh_cloud()
## 径向光束延伸比例；越大条带延伸越远，受光源屏幕位置影响。
@export_range(0.1, 0.98, 0.01) var light_shaft_length: float = 0.94:
	set(value):
		light_shaft_length = clampf(value, 0.1, 0.98)
		_refresh_cloud()
## 光束高光源沿径向的偏移比例；改变条带起始分布，与延伸长度共同影响形状。
@export_range(0.0, 0.3, 0.01) var light_shaft_offset: float = 0.12:
	set(value):
		light_shaft_offset = clampf(value, 0.0, 0.3)
		_refresh_cloud()
## 米氏散射气溶胶密度倍率；影响光束和大气融合的散射及消光。
@export_range(0.0, 3.0, 0.01) var atmosphere_mie_density: float = 1.0:
	set(value):
		atmosphere_mie_density = clampf(value, 0.0, 3.0)
		_refresh_cloud()
## 后处理输出通道；0 为最终画面，1 至 8 依次显示直射、大气、环境、不透明度、光束、种子高光、米氏贡献和月光。
@export_enum("Final", "Direct light", "Atmosphere blend", "Ambient light", "Opacity", "Light shafts", "Shaft highlight", "Mie contribution", "Moon direct light") var post_debug_view: int = 0:
	set(value):
		post_debug_view = clampi(value, 0, 8)
		_refresh_cloud()

@export_group("3D noise")
## 密度噪声模式；0 仅云图，1 柏林，2 柏林与沃利组合，3 按红绿通道分别使用两类噪声。
@export_enum("Map only", "Perlin", "Perlin-Worley", "R Perlin / G Perlin-Worley") var density_mode: int = DensityMode.CHANNELS:
	set(value):
		density_mode = clampi(value, DensityMode.MAP_ONLY, DensityMode.CHANNELS)
		_refresh_cloud()
## 三维基础噪声周期（米）；越大云团尺度越大，改变后云内光照和地面云影一起变化。
@export_range(10000.0, 100000.0, 5000.0) var noise_repeat_distance: float = 10000.0:
	set(value):
		noise_repeat_distance = maxf(value, 1.0)
		_refresh_cloud()
## 基础分形噪声层数；越大增加高频形状和采样成本。
@export_range(1, 6, 1) var noise_octaves: int = 4:
	set(value):
		noise_octaves = clampi(value, 1, 6)
		_refresh_cloud()
## 每层分形噪声的振幅倍率；越大高频细节越明显，使用归一化控制总体对比度。
@export_range(0.0, 1.0, 0.01) var noise_gain: float = 0.5:
	set(value):
		noise_gain = clampf(value, 0.0, 1.0)
		_refresh_cloud()
## 相邻分形噪声层的频率倍率；1 重复同频率，越大细节尺度分离越明显。
@export_range(1, 4, 1) var noise_lacunarity: int = 2:
	set(value):
		noise_lacunarity = clampi(value, 1, 4)
		_refresh_cloud()

@export_group("Detail erosion")
## 细节侵蚀强度；越大云边和云内孔洞越多，只减少密度。
@export_range(0.0, 1.0, 0.01) var erosion_strength: float = 0.5:
	set(value):
		erosion_strength = clampf(value, 0.0, 1.0)
		_refresh_cloud()
## 侵蚀噪声相对基础噪声的频率倍率；越大侵蚀细节越小。
@export_range(1.0, 16.0, 0.25) var erosion_frequency: float = 4.0:
	set(value):
		erosion_frequency = clampf(value, 1.0, 16.0)
		_refresh_cloud()

@export_group("Cloud animation")
## 云形动画开关；关闭冻结动态噪声位移，游戏暂停也冻结时间。
@export var animation_enabled: bool = true:
	set(value):
		animation_enabled = value
		_refresh_cloud()
## 风的水平方位角（度）；控制动态噪声运动和高度偏移方向。
@export_range(-180.0, 180.0, 1.0) var wind_azimuth: float = 90.0:
	set(value):
		wind_azimuth = clampf(value, -180.0, 180.0)
		_refresh_cloud()
## 风速（米/秒）；控制动态噪声位移速度，0 冻结风运动。
@export_range(0.0, 200.0, 1.0) var wind_speed: float = 30.0:
	set(value):
		wind_speed = clampf(value, 0.0, 200.0)
		_refresh_cloud()
# 原文高度偏移系数为 500 m；保持归一化高度，云层底部偏移为零。
## 从云底到云顶的风向偏移幅度（米）；底部为 0，高处逐渐增大。
@export_range(0.0, 1500.0, 10.0) var wind_height_skew: float = 500.0:
	set(value):
		wind_height_skew = clampf(value, 0.0, 1500.0)
		_refresh_cloud()

@export_group("Anvil clouds")
## 砧状云偏置强度；越大顶部扩张和偏移越明显。
@export_range(0.0, 1.0, 0.01) var anvil_bias: float = 0.0:
	set(value):
		anvil_bias = clampf(value, 0.0, 1.0)
		_refresh_cloud()
## 砧状云顶部相对风向的附加角（度）；改变云顶延展方向。
@export_range(-180.0, 180.0, 1.0) var anvil_direction_offset: float = 45.0:
	set(value):
		anvil_direction_offset = clampf(value, -180.0, 180.0)
		_refresh_cloud()
## 砧状云顶部额外偏移距离（米）；影响高层形状，不等同于随时间位移。
@export_range(0.0, 3000.0, 10.0) var anvil_skew_distance: float = 1000.0:
	set(value):
		anvil_skew_distance = clampf(value, 0.0, 3000.0)
		_refresh_cloud()

@export_group("Lighting")
## 太阳方向光节点；其方向、颜色和能量用于云直射、自阴影、光束及地面云影。
@export var sun: DirectionalLight3D:
	set(value):
		sun = value
		_refresh_cloud()
## 留空时跟随天空控制器配置的月光节点。
## 月光方向光节点；留空时跟随天空控制器的月光，影响夜间散射和光束。
@export var moon: DirectionalLight3D:
	set(value):
		moon = value
		_refresh_cloud()
## 云月光开关；关闭云的月光直射和月光束，天空控制器的夜间环境补光继续生效。
@export var moon_lighting_enabled := true:
	set(value):
		moon_lighting_enabled = value
		_refresh_cloud()
## 月光直射与月光束强度；夜间环境补光仍由天空控制器管理。
## 云月光及月光束能量倍率；不改变世界环境补光或地表月光。
@export_range(0.0, 3.0, 0.01) var moon_light_multiplier := 1.0:
	set(value):
		moon_light_multiplier = clampf(value, 0.0, 3.0)
		_refresh_cloud()
## 云内环境补光颜色；用于无直射区域，运行时还与天空环境状态协调。
@export_color_no_alpha var ambient_color := Color(0.65, 0.75, 1.0):
	set(value):
		ambient_color = value
		_refresh_cloud()
## 云内环境补光强度；越大背光区域越亮，降低明暗对比。
@export_range(0.0, 1.0, 0.01) var ambient_intensity: float = 0.25:
	set(value):
		ambient_intensity = clampf(value, 0.0, 1.0)
		_refresh_cloud()
## 云内自阴影开关；开启沿光源方向查询透射率，增加立体感及采样成本。
@export var self_shadow: bool = true:
	set(value):
		self_shadow = value
		_refresh_cloud()
## 每次光照查询的采样预算；越大自阴影更稳定，太阳和月光使用同一预算。
@export_range(1, 16, 1) var light_steps: int = 6:
	set(value):
		light_steps = clampi(value, 1, 16)
		_refresh_cloud()

@export_subgroup("Nubis scattering")
## 增强散射模型开关；开启使用方向散射、银边、多重散射和入散射近似。
@export var nubis_lighting: bool = true:
	set(value):
		nubis_lighting = value
		_refresh_cloud()
## 散射相函数偏心率；正值增强朝光源的前向散射，负值增强背向散射。
@export_range(-0.95, 0.95, 0.01) var phase_eccentricity: float = 0.6:
	set(value):
		phase_eccentricity = clampf(value, -0.95, 0.95)
		_refresh_cloud()
## 云边银色高光强度；越大逆光银边越亮。
@export_range(0.0, 2.0, 0.01) var silver_intensity: float = 0.5:
	set(value):
		silver_intensity = clampf(value, 0.0, 2.0)
		_refresh_cloud()
## 银边散射展宽参数；控制高光角分布，应结合散射偏心率和强度调节。
@export_range(0.01, 0.98, 0.01) var silver_spread: float = 0.2:
	set(value):
		silver_spread = clampf(value, 0.01, 0.98)
		_refresh_cloud()
## 多重散射补光强度；越大厚云内部越亮，朝光源方向会按角度减弱。
@export_range(0.0, 1.0, 0.01) var multi_scatter_strength: float = 1.0:
	set(value):
		multi_scatter_strength = clampf(value, 0.0, 1.0)
		_refresh_cloud()
## 入散射概率贡献；影响云内部和边缘的明暗塑形。
@export_range(0.0, 1.0, 0.01) var in_scatter_strength: float = 1.0:
	set(value):
		in_scatter_strength = clampf(value, 0.0, 1.0)
		_refresh_cloud()

@export_group("性能与动画")
## 体积云总开关；关闭云显示、云合成及地面云影。
@export var clouds_enabled := true:
	set(value):
		clouds_enabled = value
		_refresh_cloud()
## 自适应步进开关；按空域和观察方向减少无效采样，以降低显卡成本。
@export var adaptive_sampling := true:
	set(value):
		adaptive_sampling = value
		_refresh_cloud()
## 空域步长相对基础步长的倍率；越大空域遍历更快，但细小云团更容易漏采样。
@export_range(1, 4) var empty_step_scale := 3:
	set(value):
		empty_step_scale = value
		_refresh_cloud()
## 光照使用低频密度近似的开关；减少侵蚀查询以降低自阴影成本。
@export var light_low_frequency := true:
	set(value):
		light_low_frequency = value
		_refresh_cloud()
@export_group("高度剖面")
## 层云四端点高度剖面（0 至 1）；依次为增密开始、增密结束、消散开始和消散结束，应递增。
@export var stratus_profile := Vector4(0.0, 0.1, 0.2, 0.3):
	set(value):
		stratus_profile = value
		_refresh_cloud()
## 层积云四端点高度剖面（0 至 1）；决定密度在云底和云顶的过渡，端点应递增。
@export var stratocumulus_profile := Vector4(0.0, 0.2, 0.48, 0.625):
	set(value):
		stratocumulus_profile = value
		_refresh_cloud()
## 积云四端点高度剖面（0 至 1）；决定较厚积云的竖直密度分布，端点应递增。
@export var cumulus_profile := Vector4(0.0, 0.1625, 0.88, 0.98):
	set(value):
		cumulus_profile = value
		_refresh_cloud()
## 天空控制器的相对节点路径；用于共享昼夜颜色、日月光照和世界合成器。
@export_node_path("WorldEnvironment") var environment_path := NodePath("../世界环境")
@export_group("地面云影")
## 地面太阳云影开关；影响地形和海面直射光，小地图跳过云影。
@export var ground_cloud_shadows := true:
	set(value):
		ground_cloud_shadows = value
		_refresh_cloud()
## 地面太阳云影强度；0 不衰减直射光，1 使用完整云透射率。
@export_range(0.0, 1.0, 0.01) var ground_shadow_strength := 1.0:
	set(value):
		ground_shadow_strength = value
		_refresh_cloud()
## 地面云影密度采样次数；越大阴影更稳定，但增加每个地表片元的开销。
@export_range(4, 32) var ground_shadow_steps := 12:
	set(value):
		ground_shadow_steps = value
		_refresh_cloud()

const MATERIAL_PARAMETERS := [
	"planet_surface_origin", "planet_radius", "cloud_bottom", "cloud_top", "cloud_map_center", "cloud_map_extent",
	"cloud_map", "coverage_blend", "coverage_amount", "cloud_type_bias", "density_multiplier", "extinction",
	"march_steps", "max_distance", "detail_distance", "haze_strength", "atmosphere_density", "light_shafts_enabled",
	"light_shaft_strength", "light_shaft_start", "light_shaft_samples", "light_shaft_spread", "light_shaft_length",
	"light_shaft_offset", "atmosphere_mie_density", "post_debug_view", "density_mode",
	"noise_repeat_distance", "noise_octaves", "noise_gain", "noise_lacunarity", "erosion_strength", "erosion_frequency",
	"wind_height_skew", "anvil_bias", "anvil_skew_distance", "self_shadow", "light_steps", "nubis_lighting",
	"phase_eccentricity", "silver_intensity", "silver_spread", "multi_scatter_strength", "in_scatter_strength",
	"adaptive_sampling", "empty_step_scale", "light_low_frequency", "stratus_profile", "stratocumulus_profile", "cumulus_profile",
]

var cloud_material: ShaderMaterial
var _environment_node: WorldEnvironment
var _environment: Environment
var _previous_compositor: Compositor
var _compositor: Compositor
var _post_effect: POST_EFFECT
var _fallback: MeshInstance3D
var _perlin_texture: NoiseTexture3D
var _worley_texture: NoiseTexture3D
var _perlin_mip_texture: ImageTexture3D
var _worley_mip_texture: ImageTexture3D
var _noise_motion_offset := Vector3.ZERO
var _post_failed := false
var _shadow_materials: Array[ShaderMaterial] = []
var _reflection_camera: Camera3D
var _reflection_effect: POST_EFFECT
var _reflection_compositor: Compositor
var _previous_reflection_compositor: Compositor

const SHADOW_PARAMETERS := [
	"planet_surface_origin", "planet_radius", "cloud_bottom", "cloud_top", "cloud_map_center", "cloud_map_extent",
	"cloud_map", "coverage_blend", "coverage_amount", "cloud_type_bias", "density_multiplier", "extinction",
	"density_mode", "noise_repeat_distance", "noise_octaves", "noise_gain", "noise_lacunarity", "erosion_strength",
	"erosion_frequency", "wind_height_skew", "anvil_bias", "anvil_skew_distance", "stratus_profile", "stratocumulus_profile",
	"cumulus_profile", "perlin_texture", "worley_texture", "noise_ready", "noise_normalization", "wind_direction", "anvil_skew_direction",
]


func _ready() -> void:
	_environment_node = get_node_or_null(environment_path) as WorldEnvironment
	if _environment_node == null or _environment_node.environment == null:
		push_error("体积云需要有效的世界环境。")
		return
	_environment = _environment_node.environment
	cloud_material = ShaderMaterial.new()
	cloud_material.shader = CLOUD_SHADER
	# 基础云先于透明海面绘制，海面仍能覆盖和反射天空。
	cloud_material.render_priority = -127
	_create_fallback()
	_refresh_cloud()
	_prepare_noise_textures()
	if not Engine.is_editor_hint() and RenderingServer.get_rendering_device() != null:
		_previous_compositor = _environment_node.compositor
		_post_effect = POST_EFFECT.new()
		_post_effect.prepare(cloud_material)
		_post_effect.failed.connect(_on_post_failure)
		_compositor = Compositor.new()
		var effects: Array[CompositorEffect] = []
		if _previous_compositor != null:
			effects.assign(_previous_compositor.compositor_effects)
		effects.push_front(_post_effect)
		_compositor.compositor_effects = effects
		_environment_node.compositor = _compositor
		_prepare_reflection_effect()
	_refresh_cloud()


func _create_fallback() -> void:
	_fallback = MeshInstance3D.new()
	_fallback.name = "云编辑器预览"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_fallback.mesh = quad
	_fallback.material_override = cloud_material
	_fallback.layers = 1
	_fallback.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fallback.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_fallback.extra_cull_margin = 16384.0
	add_child(_fallback)


func _prepare_reflection_effect() -> void:
	var water := get_node_or_null("../水面")
	if water == null:
		return
	_reflection_camera = water.get("_reflection_camera") as Camera3D
	if _reflection_camera == null:
		return
	_previous_reflection_compositor = _reflection_camera.compositor
	_reflection_effect = POST_EFFECT.new()
	_reflection_effect.prepare(cloud_material)
	_reflection_effect.failed.connect(_on_post_failure)
	_reflection_compositor = Compositor.new()
	var effects: Array[CompositorEffect] = []
	if _previous_reflection_compositor != null:
		effects.assign(_previous_reflection_compositor.compositor_effects)
	effects.push_front(_reflection_effect)
	_reflection_compositor.compositor_effects = effects
	_reflection_camera.compositor = _reflection_compositor


func _prepare_noise_textures() -> void:
	_perlin_texture = load("res://materials/clouds/cloud_perlin_3d.tres") as NoiseTexture3D
	_worley_texture = load("res://materials/clouds/cloud_worley_3d.tres") as NoiseTexture3D
	_perlin_texture.changed.connect(_on_noise_textures_changed.bind(_perlin_texture))
	_worley_texture.changed.connect(_on_noise_textures_changed.bind(_worley_texture))
	_on_noise_textures_changed()


func _on_noise_textures_changed(source: NoiseTexture3D = null) -> void:
	if source == null or source == _perlin_texture:
		_perlin_mip_texture = NOISE_MIPMAPS.build(_perlin_texture.get_data()) if _noise_texture_ready(_perlin_texture) else null
	if source == null or source == _worley_texture:
		_worley_mip_texture = NOISE_MIPMAPS.build(_worley_texture.get_data()) if _noise_texture_ready(_worley_texture) else null
	_refresh_cloud()


func _noise_texture_ready(texture: NoiseTexture3D) -> bool:
	texture.get_rid()
	var slices := texture.get_data()
	return slices.size() == texture.depth and not slices.is_empty() \
		and slices[0].get_width() == texture.width and slices[0].get_height() == texture.height


func _refresh_cloud() -> void:
	if cloud_material == null:
		return
	for parameter in MATERIAL_PARAMETERS:
		cloud_material.set_shader_parameter(parameter, get(parameter))
	cloud_material.set_shader_parameter("density_multiplier", density_multiplier if clouds_enabled else 0.0)
	cloud_material.set_shader_parameter("perlin_texture", _perlin_mip_texture)
	cloud_material.set_shader_parameter("worley_texture", _worley_mip_texture)
	cloud_material.set_shader_parameter("noise_ready", _perlin_mip_texture != null and _worley_mip_texture != null)
	var amplitude := 1.0
	var weight := 0.0
	var squared_weight := 0.0
	for octave in range(noise_octaves):
		weight += amplitude
		squared_weight += amplitude * amplitude
		amplitude *= noise_gain
	cloud_material.set_shader_parameter("noise_normalization", weight if noise_lacunarity == 1 else sqrt(squared_weight))
	cloud_material.set_shader_parameter("wind_direction", _wind_direction())
	var anvil_angle := deg_to_rad(wind_azimuth + anvil_direction_offset)
	cloud_material.set_shader_parameter("anvil_skew_direction", Vector3(sin(anvil_angle), 0.0, cos(anvil_angle)))
	# 昼夜色彩、月光补光由本项目的天空控制器提供。
	cloud_material.set_shader_parameter("sky_link_lighting", false)
	_collect_shadow_materials()
	_apply_shadow_settings()
	_sync_lighting()
	if _post_effect != null:
		_post_effect.sync_material(cloud_material)
		_post_effect.enabled = clouds_enabled and post_processing_enabled and not _post_failed
	if _reflection_effect != null:
		_reflection_effect.sync_material(cloud_material)
		_reflection_effect.enabled = clouds_enabled and post_processing_enabled and not _post_failed
	_sync_reflection()
	_fallback.visible = clouds_enabled and (_post_effect == null or not _post_effect.enabled)


func _wind_direction() -> Vector3:
	var angle := deg_to_rad(wind_azimuth)
	return Vector3(sin(angle), 0.0, cos(angle))


func _sync_lighting() -> void:
	var light := sun if is_instance_valid(sun) else get_node_or_null("../日光") as DirectionalLight3D
	var moon_light := moon
	if not is_instance_valid(moon_light):
		var moon_path_value: Variant = _environment_node.get("moon_path")
		if moon_path_value is NodePath:
			moon_light = _environment_node.get_node_or_null(moon_path_value) as DirectionalLight3D
		else:
			moon_light = get_node_or_null("../月光") as DirectionalLight3D
	var solar_direction := light.global_basis.z.normalized() if light != null else Vector3.UP
	var solar_elevation := rad_to_deg(asin(clampf(solar_direction.y, -1.0, 1.0)))
	# 白天精确为零；日落后到太阳 -6° 平滑开启，日出时反向淡出。
	var night_weight := 1.0 - smoothstep(-6.0, 0.0, solar_elevation)
	var lunar_intensity := 0.0
	if moon_lighting_enabled and is_instance_valid(moon_light) and moon_light.is_visible_in_tree() and moon_light.global_basis.z.y > 0.0:
		lunar_intensity = moon_light.light_energy * moon_light_multiplier * night_weight
	var values := {
		"sun_direction": solar_direction,
		"sun_color": light.light_color if light != null else Color.WHITE,
		"sun_intensity": light.light_energy if light != null and light.is_visible_in_tree() else 0.0,
		"moon_direction": moon_light.global_basis.z.normalized() if is_instance_valid(moon_light) else Vector3.UP,
		"moon_color": moon_light.light_color if is_instance_valid(moon_light) else Color(0.76, 0.84, 1.0),
		"moon_intensity": lunar_intensity,
		"ambient_color": _environment.ambient_light_color * ambient_color,
		"ambient_intensity": _environment.ambient_light_energy * ambient_intensity,
		"noise_motion_offset": _noise_motion_offset,
	}
	var sky := _environment.sky.sky_material as ShaderMaterial if _environment.sky != null else null
	if sky != null:
		for pair in [["cloud_sky_zenith", "zenith_color"], ["cloud_sky_horizon", "horizon_color"],
			["cloud_sky_daylight", "daylight"], ["cloud_sky_twilight", "twilight"],
			["cloud_sky_sun_color", "sun_color"], ["cloud_sky_sun_visibility", "sun_visibility"]]:
			var value: Variant = sky.get_shader_parameter(pair[1])
			if value != null:
				values[pair[0]] = value
	for parameter in values:
		cloud_material.set_shader_parameter(parameter, values[parameter])
	if _post_effect != null:
		_post_effect.update_parameters(values)
	if _reflection_effect != null:
		_reflection_effect.update_parameters(values)
	_sync_reflection()
	for material in _shadow_materials:
		material.set_shader_parameter("cloud_ground_sun_direction", values.sun_direction)
		material.set_shader_parameter("cloud_ground_sun_intensity", values.sun_intensity)
		material.set_shader_parameter("noise_motion_offset", _noise_motion_offset)


func _sync_reflection() -> void:
	var water := get_node_or_null("../水面") as Node3D
	var height := water.global_position.y if water != null else planet_surface_origin.y
	cloud_material.set_shader_parameter("cloud_reflection_height", height)
	if _reflection_effect != null:
		_reflection_effect.update_parameters({"cloud_reflection_view": true, "cloud_reflection_height": height})


func _collect_shadow_materials() -> void:
	var materials: Array[ShaderMaterial] = []
	var terrain := get_node_or_null("../地图")
	if terrain != null and terrain.get("terrain_material") is ShaderMaterial:
		materials.append(terrain.get("terrain_material"))
	var water := get_node_or_null("../水面") as MeshInstance3D
	if water != null and water.mesh != null and water.get_active_material(0) is ShaderMaterial:
		materials.append(water.get_active_material(0))
	if materials != _shadow_materials:
		_shadow_materials = materials
		_apply_shadow_settings()


func _apply_shadow_settings() -> void:
	for material in _shadow_materials:
		for parameter in SHADOW_PARAMETERS:
			material.set_shader_parameter(parameter, cloud_material.get_shader_parameter(parameter))
		material.set_shader_parameter("ground_cloud_shadows", clouds_enabled and ground_cloud_shadows)
		material.set_shader_parameter("ground_shadow_strength", ground_shadow_strength)
		material.set_shader_parameter("ground_shadow_steps", ground_shadow_steps)


func _process(delta: float) -> void:
	if cloud_material == null:
		return
	if not Engine.is_editor_hint() and clouds_enabled and animation_enabled and density_mode != DensityMode.MAP_ONLY:
		_noise_motion_offset += _wind_direction() * wind_speed * delta
	_collect_shadow_materials()
	_sync_lighting()


func _on_post_failure(_message: String) -> void:
	_post_failed = true
	_refresh_cloud()


func _exit_tree() -> void:
	for material in _shadow_materials:
		material.set_shader_parameter("ground_cloud_shadows", false)
	_shadow_materials.clear()
	if is_instance_valid(_environment_node) and _environment_node.compositor == _compositor:
		_environment_node.compositor = _previous_compositor
	if _post_effect != null:
		_post_effect.enabled = false
	_post_effect = null
	if is_instance_valid(_reflection_camera) and _reflection_camera.compositor == _reflection_compositor:
		_reflection_camera.compositor = _previous_reflection_compositor
	if _reflection_effect != null:
		_reflection_effect.enabled = false
	_reflection_effect = null

