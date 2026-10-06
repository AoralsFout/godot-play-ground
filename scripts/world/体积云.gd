@tool
extends Node3D
## 来自 volume-cloude 的球壳体积云，使用世界环境合成，摄像机由当前视口提供。

enum DensityMode { MAP_ONLY, PERLIN, PERLIN_WORLEY, CHANNELS }

const NOISE_MIPMAPS = preload("res://scripts/clouds/cloud_noise_mipmaps.gd")
const POST_EFFECT = preload("res://scripts/clouds/cloud_postprocess_effect.gd")
const CLOUD_SHADER = preload("res://shaders/clouds/minimal_volume_cloud.gdshader")

@export var cloud_map: Texture2D = preload("res://assets/clouds/cloud_map.png"):
	set(value):
		cloud_map = value
		_refresh_cloud()
@export_range(0.0, 1.0, 0.001) var coverage_blend: float = 0.5:
	set(value):
		coverage_blend = clampf(value, 0.0, 1.0)
		_refresh_cloud()
@export_range(0.0, 1.0, 0.001) var coverage_amount: float = 0.5:
	set(value):
		coverage_amount = clampf(value, 0.0, 1.0)
		_refresh_cloud()
@export_range(-1.0, 1.0, 0.001) var cloud_type_bias: float = 0.0:
	set(value):
		cloud_type_bias = clampf(value, -1.0, 1.0)
		_refresh_cloud()
@export_range(0.0, 10.0, 0.01) var density_multiplier: float = 1.0:
	set(value):
		density_multiplier = clampf(value, 0.0, 10.0)
		_refresh_cloud()
@export_group("Spherical layer")
# 固定北极切平面基点；实际球心为这个位置向下 planet_radius 米。
@export var planet_surface_origin := Vector3.ZERO:
	set(value):
		planet_surface_origin = value
		_refresh_cloud()
@export_range(100000.0, 20000000.0, 1000.0) var planet_radius: float = 6371000.0:
	set(value):
		planet_radius = clampf(value, 100000.0, 20000000.0)
		_refresh_cloud()
@export_range(100.0, 19900.0, 50.0) var cloud_bottom: float = 1500.0:
	set(value):
		cloud_bottom = clampf(value, 100.0, 19900.0)
		if cloud_top < cloud_bottom + 100.0:
			cloud_top = cloud_bottom + 100.0
		_refresh_cloud()
@export_range(200.0, 20000.0, 50.0) var cloud_top: float = 4000.0:
	set(value):
		cloud_top = clampf(value, cloud_bottom + 100.0, 20000.0)
		_refresh_cloud()
@export var cloud_map_center := Vector2.ZERO:
	set(value):
		cloud_map_center = value
		_refresh_cloud()
@export_range(20000.0, 2000000.0, 10000.0) var cloud_map_extent: float = 600000.0:
	set(value):
		cloud_map_extent = clampf(value, 20000.0, 2000000.0)
		_refresh_cloud()
# 消光按每米计；随厚度从 60 m 增至 2500 m 按比例降低默认值。
@export_range(0.0, 0.02, 0.0001) var extinction: float = 0.00192:
	set(value):
		extinction = value
		_refresh_cloud()
@export_range(16, 192, 1) var march_steps: int = 96:
	set(value):
		march_steps = value
		_refresh_cloud()
@export_range(10000.0, 1000000.0, 10000.0) var max_distance: float = 300000.0:
	set(value):
		max_distance = clampf(value, 10000.0, 1000000.0)
		_refresh_cloud()
@export_range(10000.0, 300000.0, 1000.0) var detail_distance: float = 80000.0:
	set(value):
		detail_distance = clampf(value, 10000.0, 300000.0)
		_refresh_cloud()
@export_range(0.0, 1.0, 0.01) var haze_strength: float = 0.75:
	set(value):
		haze_strength = clampf(value, 0.0, 1.0)
		_refresh_cloud()

@export_group("Post processing")
@export var post_processing_enabled: bool = true:
	set(value):
		post_processing_enabled = value
		_refresh_cloud()
@export_range(0.0, 3.0, 0.01) var atmosphere_density: float = 1.0:
	set(value):
		atmosphere_density = clampf(value, 0.0, 3.0)
		_refresh_cloud()
@export var light_shafts_enabled: bool = true:
	set(value):
		light_shafts_enabled = value
		_refresh_cloud()
@export_range(0.0, 3.0, 0.01) var light_shaft_strength: float = 0.8:
	set(value):
		light_shaft_strength = clampf(value, 0.0, 3.0)
		_refresh_cloud()
@export_range(500.0, 10000.0, 100.0) var light_shaft_start: float = 2000.0:
	set(value):
		light_shaft_start = clampf(value, 500.0, 10000.0)
		_refresh_cloud()
@export_range(16, 64, 1) var light_shaft_samples: int = 32:
	set(value):
		light_shaft_samples = clampi(value, 16, 64)
		_refresh_cloud()
@export_enum("Final", "Direct light", "Atmosphere blend", "Ambient light", "Opacity", "Light shafts") var post_debug_view: int = 0:
	set(value):
		post_debug_view = clampi(value, 0, 5)
		_refresh_cloud()

@export_group("3D noise")
@export_enum("Map only", "Perlin", "Perlin-Worley", "R Perlin / G Perlin-Worley") var density_mode: int = DensityMode.CHANNELS:
	set(value):
		density_mode = clampi(value, DensityMode.MAP_ONLY, DensityMode.CHANNELS)
		_refresh_cloud()
@export_range(10000.0, 100000.0, 5000.0) var noise_repeat_distance: float = 10000.0:
	set(value):
		noise_repeat_distance = maxf(value, 1.0)
		_refresh_cloud()
@export_range(1, 6, 1) var noise_octaves: int = 4:
	set(value):
		noise_octaves = clampi(value, 1, 6)
		_refresh_cloud()
@export_range(0.0, 1.0, 0.01) var noise_gain: float = 0.5:
	set(value):
		noise_gain = clampf(value, 0.0, 1.0)
		_refresh_cloud()
@export_range(1, 4, 1) var noise_lacunarity: int = 2:
	set(value):
		noise_lacunarity = clampi(value, 1, 4)
		_refresh_cloud()

@export_group("Detail erosion")
@export_range(0.0, 1.0, 0.01) var erosion_strength: float = 0.5:
	set(value):
		erosion_strength = clampf(value, 0.0, 1.0)
		_refresh_cloud()
@export_range(1.0, 16.0, 0.25) var erosion_frequency: float = 4.0:
	set(value):
		erosion_frequency = clampf(value, 1.0, 16.0)
		_refresh_cloud()

@export_group("Cloud animation")
@export var animation_enabled: bool = true:
	set(value):
		animation_enabled = value
		_refresh_cloud()
@export_range(-180.0, 180.0, 1.0) var wind_azimuth: float = 90.0:
	set(value):
		wind_azimuth = clampf(value, -180.0, 180.0)
		_refresh_cloud()
@export_range(0.0, 200.0, 1.0) var wind_speed: float = 30.0:
	set(value):
		wind_speed = clampf(value, 0.0, 200.0)
		_refresh_cloud()
# 原文高度偏移系数为 500 m；保持归一化高度，云层底部偏移为零。
@export_range(0.0, 1500.0, 10.0) var wind_height_skew: float = 500.0:
	set(value):
		wind_height_skew = clampf(value, 0.0, 1500.0)
		_refresh_cloud()

@export_group("Anvil clouds")
@export_range(0.0, 1.0, 0.01) var anvil_bias: float = 0.0:
	set(value):
		anvil_bias = clampf(value, 0.0, 1.0)
		_refresh_cloud()
@export_range(-180.0, 180.0, 1.0) var anvil_direction_offset: float = 45.0:
	set(value):
		anvil_direction_offset = clampf(value, -180.0, 180.0)
		_refresh_cloud()
@export_range(0.0, 3000.0, 10.0) var anvil_skew_distance: float = 1000.0:
	set(value):
		anvil_skew_distance = clampf(value, 0.0, 3000.0)
		_refresh_cloud()

@export_group("Lighting")
@export var sun: DirectionalLight3D:
	set(value):
		sun = value
		_refresh_cloud()
@export_color_no_alpha var ambient_color := Color(0.65, 0.75, 1.0):
	set(value):
		ambient_color = value
		_refresh_cloud()
@export_range(0.0, 1.0, 0.01) var ambient_intensity: float = 0.25:
	set(value):
		ambient_intensity = clampf(value, 0.0, 1.0)
		_refresh_cloud()
@export var self_shadow: bool = true:
	set(value):
		self_shadow = value
		_refresh_cloud()
@export_range(1, 16, 1) var light_steps: int = 6:
	set(value):
		light_steps = clampi(value, 1, 16)
		_refresh_cloud()

@export_subgroup("Nubis scattering")
@export var nubis_lighting: bool = true:
	set(value):
		nubis_lighting = value
		_refresh_cloud()
@export_range(-0.95, 0.95, 0.01) var phase_eccentricity: float = 0.6:
	set(value):
		phase_eccentricity = clampf(value, -0.95, 0.95)
		_refresh_cloud()
@export_range(0.0, 2.0, 0.01) var silver_intensity: float = 0.5:
	set(value):
		silver_intensity = clampf(value, 0.0, 2.0)
		_refresh_cloud()
@export_range(0.01, 0.98, 0.01) var silver_spread: float = 0.2:
	set(value):
		silver_spread = clampf(value, 0.01, 0.98)
		_refresh_cloud()
@export_range(0.0, 1.0, 0.01) var multi_scatter_strength: float = 1.0:
	set(value):
		multi_scatter_strength = clampf(value, 0.0, 1.0)
		_refresh_cloud()
@export_range(0.0, 1.0, 0.01) var in_scatter_strength: float = 1.0:
	set(value):
		in_scatter_strength = clampf(value, 0.0, 1.0)
		_refresh_cloud()

@export_group("性能与动画")
@export var clouds_enabled := true:
	set(value):
		clouds_enabled = value
		_refresh_cloud()
@export var adaptive_sampling := true:
	set(value):
		adaptive_sampling = value
		_refresh_cloud()
@export_range(1, 4) var empty_step_scale := 3:
	set(value):
		empty_step_scale = value
		_refresh_cloud()
@export var light_low_frequency := true:
	set(value):
		light_low_frequency = value
		_refresh_cloud()
@export_group("高度剖面")
@export var stratus_profile := Vector4(0.0, 0.1, 0.2, 0.3):
	set(value):
		stratus_profile = value
		_refresh_cloud()
@export var stratocumulus_profile := Vector4(0.0, 0.2, 0.48, 0.625):
	set(value):
		stratocumulus_profile = value
		_refresh_cloud()
@export var cumulus_profile := Vector4(0.0, 0.1625, 0.88, 0.98):
	set(value):
		cumulus_profile = value
		_refresh_cloud()
@export_node_path("WorldEnvironment") var environment_path := NodePath("../世界环境")
@export_group("地面云影")
@export var ground_cloud_shadows := true:
	set(value):
		ground_cloud_shadows = value
		_refresh_cloud()
@export_range(0.0, 1.0, 0.01) var ground_shadow_strength := 1.0:
	set(value):
		ground_shadow_strength = value
		_refresh_cloud()
@export_range(4, 32) var ground_shadow_steps := 12:
	set(value):
		ground_shadow_steps = value
		_refresh_cloud()

const MATERIAL_PARAMETERS := [
	"planet_surface_origin", "planet_radius", "cloud_bottom", "cloud_top", "cloud_map_center", "cloud_map_extent",
	"cloud_map", "coverage_blend", "coverage_amount", "cloud_type_bias", "density_multiplier", "extinction",
	"march_steps", "max_distance", "detail_distance", "haze_strength", "atmosphere_density", "light_shafts_enabled",
	"light_shaft_strength", "light_shaft_start", "light_shaft_samples", "post_debug_view", "density_mode",
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
	var values := {
		"sun_direction": light.global_basis.z.normalized() if light != null else Vector3.UP,
		"sun_color": light.light_color if light != null else Color.WHITE,
		"sun_intensity": light.light_energy if light != null and light.is_visible_in_tree() else 0.0,
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

