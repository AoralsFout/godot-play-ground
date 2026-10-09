// 计算海面波浪、吸收、折射、泡沫及倒影。
// 使用距离分级降低远处几何波浪，结合平面和屏幕空间倒影，并接收天空光照及云影。

shader_type spatial;
// 在绘制透明水面之前复制屏幕；写入深度以正确排序重叠的波浪。
render_mode blend_mix, depth_draw_always, cull_disabled, ambient_light_disabled;
#include "res://shaders/water/海浪.gdshaderinc"
#include "res://shaders/clouds/cloud_ground_shadow.gdshaderinc"
// 浅水散射颜色；浅区域更明显，仍受天空及场景光照影响。
uniform vec4 shallow_color : source_color = vec4(0.18, 0.58, 0.56, 1.0);
// 深水散射颜色；随水深增加逐渐替代浅水配色。
uniform vec4 deep_color : source_color = vec4(0.008, 0.065, 0.10, 1.0);
// 红绿蓝各通道每米吸收系数；越大对应颜色随水深衰减越快。
uniform vec3 absorption = vec3(0.18, 0.045, 0.022);
// 浅水吸收权重；控制浅水折射画面和水体颜色的混合。
uniform float shallow_absorption : hint_range(0.0, 1.0) = 0.28;
// 波浪高度倍率（米制波形）；影响几何起伏和表面法线，水下查询共用该值。
uniform float wave_height : hint_range(0.0, 1.5) = 0.55;
// 波浪时间倍率；越大波浪运动越快，0 冻结波相。
uniform float wave_speed : hint_range(0.0, 5.0) = 1.0;
// 可暂停时间开关；开启使用脚本时间，关闭使用渲染器时间。
uniform bool use_game_time = false;
// 可暂停的游戏时间（秒）；由脚本同步，驱动波浪和水下动画。
uniform float game_time = 0.0;
// 浅水向深水过渡的水深尺度（米）；越大浅水颜色保留得越深。
uniform float depth_fade_distance : hint_range(0.1, 20.0) = 8.0;
// 岸边透明淡出的水深尺度（米）；越大透明过渡区域越宽。
uniform float shore_fade_distance : hint_range(0.05, 4.0) = 1.1;
// 水面基础透明度；增大后水下场景贡献更明显，最终结果还受深度和视角影响。
uniform float transparency : hint_range(0.0, 1.0) = 0.5;
// 屏幕折射偏移强度（纹理坐标）；越大水下画面扭曲越明显。
uniform float refraction_strength : hint_range(0.0, 0.1) = 0.035;
// 波峰高光强度；影响水面亮部对比，不改变波高。
uniform float highlight_strength : hint_range(0.0, 1.0) = 0.65;
// 水面粗糙度；越大高光更宽、倒影更模糊。
uniform float water_roughness : hint_range(0.02, 1.0) = 0.12;
// 岸边和波峰泡沫强度；0 关闭泡沫颜色贡献。
uniform float foam_strength : hint_range(0.0, 1.0) = 0.38;
// 屏幕空间倒影步进次数；越大更容易找到屏幕内交点，但增加片元开销，0 跳过。
uniform int reflection_steps : hint_range(0, 24) = 12;
// 倒影混合强度；越大平面及屏幕倒影贡献越明显。
uniform float reflection_strength : hint_range(0.0, 2.0) = 1.25;
// 平面倒影纹理可用标记；由水面控制器管理，开启后使用镜像视口结果。
uniform bool use_planar_reflection = false;
// 镜像摄像机的视口纹理；由水面控制器设置，与投影矩阵配套使用。
uniform sampler2D planar_reflection : repeat_disable, filter_linear;
// 镜像摄像机世界到裁剪空间矩阵；用于定位倒影纹理采样，随相机更新。
uniform mat4 reflection_view_projection;
// 平面倒影基准的世界 Y 高度（米）；与水面世界位置保持一致。
uniform float reflection_plane_height = 15.0;
// 平面倒影纹理偏移强度（纹理坐标）；越大倒影随法线扭曲越明显。
uniform float reflection_distortion : hint_range(0.0, 0.1) = 0.018;
// 倒影缺失时的天顶回退颜色；跟随天空控制器昼夜变化。
uniform vec4 sky_zenith : source_color = vec4(0.18, 0.43, 0.78, 1.0);
// 倒影缺失时的地平线回退颜色；影响远处海面反射色。
uniform vec4 sky_horizon : source_color = vec4(0.68, 0.82, 0.94, 1.0);
// 仅给水体散射补光；折射和倒影已经包含场景光照，不再重复照明。
// 水体散射使用的环境补光颜色和强度；折射与倒影保留已有光照，不重复照明。
uniform vec3 water_ambient_light = vec3(0.12, 0.15, 0.18);
// 波浪距离分级开关；开启后按距摄像机的水平距离减弱几何波浪。
uniform bool use_distance_lod = false;
// 无限海面开关；开启后网格跟随当前摄像机并扩展至视距之外，关闭后使用固定尺寸。
uniform bool infinite_ocean = false;
// 距离分级中心的世界 X/Z 坐标（米）；由当前摄像机位置同步。
uniform vec2 lod_center = vec2(0.0);
// 海面 X/Z 覆盖半尺寸（米）；用于固定边界或无限海面覆盖计算。
uniform vec2 water_half_size = vec2(2000.0, 1500.0);
// 保留完整几何波浪的水平距离（米）；应小于波浪消失距离。
uniform float wave_full_distance = 64.0;
// 几何波浪衰减到零的水平距离（米）；越大远景保留更多起伏。
uniform float wave_end_distance = 112.0;
// 渲染器复制的当前屏幕颜色纹理；用于折射或水下画面扰动，不手动指定资源。
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
// 渲染器提供的场景深度纹理；用于水深、岸线淡出和屏幕空间倒影查询。
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
varying vec2 water_world_xz;
varying float surface_specular;
varying float water_cloud_visibility;
vec3 view_position(vec2 uv, float depth, mat4 inverse_projection) {
 vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
 #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
  ndc.z = depth * 2.0 - 1.0;
 #endif
 vec4 p = inverse_projection * vec4(ndc, 1.0);
 return p.xyz / p.w;
}
void vertex() {
 if (use_distance_lod) {
  if (infinite_ocean) {
   VERTEX.xz = lod_center + (UV2.x > 0.5 ? (UV * 2.0 - 1.0) * water_half_size : VERTEX.xz);
  } else {
   VERTEX.xz = UV2.x > 0.5 ? (UV * 2.0 - 1.0) * water_half_size
    : clamp(VERTEX.xz + lod_center, -water_half_size, water_half_size);
  }
 }
 water_world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
 vec2 offset = water_world_xz - CAMERA_POSITION_WORLD.xz;
 float distance_to_camera = length(offset);
 NORMAL = vec3(0.0, 1.0, 0.0);
 if (!use_distance_lod || distance_to_camera < wave_end_distance) {
  vec3 wave = ocean_wave(water_world_xz, (use_game_time ? game_time : TIME) * wave_speed, wave_height);
  float fade = 1.0;
  vec2 fade_slope = vec2(0.0);
  if (use_distance_lod) {
   float width = max(wave_end_distance - wave_full_distance, 0.001);
   float t = clamp((distance_to_camera - wave_full_distance) / width, 0.0, 1.0);
   fade = 1.0 - t * t * (3.0 - 2.0 * t);
   fade_slope = -6.0 * t * (1.0 - t) / width * offset / max(distance_to_camera, 0.001);
  }
  VERTEX.y += wave.x * fade;
  vec2 slope = wave.yz * fade + wave.x * fade_slope;
  NORMAL = normalize(vec3(-slope.x, 1.0, -slope.y));
 }
}
void fragment() {
	water_cloud_visibility = cloud_ground_visibility((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, CAMERA_VISIBLE_LAYERS);
 float time = (use_game_time ? game_time : TIME) * wave_speed;
 float ripple_fade = 1.0 - smoothstep(30.0, 240.0, length(water_world_xz - CAMERA_POSITION_WORLD.xz));
 vec3 ripple = smooth_noise(water_world_xz * 2.6 + vec2(0.35, 0.14) * time);
 vec3 detail = smooth_noise(water_world_xz * 5.1 + vec2(-0.28, 0.34) * time);
 vec2 slope = (ripple.yz * 0.10 + detail.yz * 0.055) * ripple_fade;
 NORMAL = normalize(NORMAL + mat3(VIEW_MATRIX) * vec3(-slope.x, 0.0, -slope.y) * (FRONT_FACING ? 1.0 : -1.0));
 vec3 scene_position = view_position(SCREEN_UV, texture(depth_texture, SCREEN_UV).r, INV_PROJECTION_MATRIX);
 float water_height = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
 float scene_height = (INV_VIEW_MATRIX * vec4(scene_position, 1.0)).y;
 float depth = max(FRONT_FACING ? water_height - scene_height : scene_height - water_height, 0.0);
 float shore = smoothstep(0.0, shore_fade_distance, depth);
 float visibility = clamp(2.0 - transparency * 2.0, 0.0, 1.0);
 shore *= visibility;
 float path_length = min(length(scene_position - VERTEX), 512.0);
 vec3 flat_normal = mat3(VIEW_MATRIX) * vec3(0.0, FRONT_FACING ? 1.0 : -1.0, 0.0);
 vec2 offset = (NORMAL - flat_normal).xy * refraction_strength * shore * min(path_length * 0.25, 1.0);
 vec2 refracted_uv = clamp(SCREEN_UV + offset, vec2(0.002), vec2(0.998));
 vec3 refracted_position = view_position(refracted_uv, texture(depth_texture, refracted_uv).r, INV_PROJECTION_MATRIX);
 float refracted_height = (INV_VIEW_MATRIX * vec4(refracted_position, 1.0)).y;
 // 剔除前景，防止水外物体渗入折射图像。
 if (-refracted_position.z < -VERTEX.z || (FRONT_FACING && refracted_height > water_height)) {
  refracted_uv = SCREEN_UV;
  refracted_position = scene_position;
 }
 // 深水路径必须足够长，使海床末端和无海床区域都趋于完全吸收。
 // 80 米的上限仍透出约 17% 蓝色背景，从高空会显出地形矩形边界。
 path_length = min(length(refracted_position - VERTEX), 512.0);
 // 从水下观察时，折射场景位于空气中；摄像机浸水效果负责处理水中路径。
 // 若对空气中的路径应用吸收，会错误地使天空变黑。
 float density = mix(shallow_absorption, 1.0, smoothstep(0.0, depth_fade_distance, depth));
 vec3 transmittance = FRONT_FACING ? exp(-absorption * path_length * visibility * density) : vec3(1.0);
 vec3 bed = textureLod(screen_texture, refracted_uv, 0.0).rgb;
 vec3 scatter = mix(shallow_color.rgb, deep_color.rgb, smoothstep(0.0, depth_fade_distance, depth));
 vec3 transmitted = bed * transmittance;
 vec3 scattering = scatter * (1.0 - transmittance);
 float cosine = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
 float fresnel = 0.0204 + 0.9796 * pow(1.0 - cosine, 5.0);
 fresnel = clamp(fresnel * reflection_strength, 0.0, 1.0);
 if (!FRONT_FACING) {
  // 斯涅尔窗口之外发生全内反射。
  fresnel = mix(fresnel, 1.0, 1.0 - smoothstep(0.64, 0.69, cosine));
 }
 vec3 reflected_direction = mat3(INV_VIEW_MATRIX) * reflect(-VIEW, NORMAL);
 // 水下未命中屏幕反射时，以受环境光照明的水体散射回退。
 // 水体颜色不是已照明的场景辐射，直接写入 EMISSION 会形成恒亮的绿色层。
 vec3 reflected = FRONT_FACING ? mix(sky_horizon.rgb, sky_zenith.rgb, sqrt(clamp(reflected_direction.y, 0.0, 1.0))) : mix(shallow_color.rgb, deep_color.rgb, 0.35) * water_ambient_light;
 // 追踪已捕获场景中的不透明物体，屏幕范围外仍以天空作为回退。
 vec3 reflection_ray = reflect(-VIEW, NORMAL);
 if (fresnel > 0.04 && reflection_steps > 0) {
  float previous_gap = -1.0;
  for (int i = 0; i < 24; i++) {
   if (i >= reflection_steps) { break; }
   float travel = 0.5 * pow(1.48, float(i));
   vec3 probe = VERTEX + NORMAL * 0.12 + reflection_ray * travel;
   if (probe.z > -0.1) { break; }
   vec4 clip = PROJECTION_MATRIX * vec4(probe, 1.0);
   vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
   if (any(lessThan(uv, vec2(0.002))) || any(greaterThan(uv, vec2(0.998)))) { break; }
   float sampled = texture(depth_texture, uv).r;
   vec3 hit = view_position(uv, sampled, INV_PROJECTION_MATRIX);
   float gap = hit.z - probe.z;
   float hit_height = (INV_VIEW_MATRIX * vec4(hit, 1.0)).y;
   bool reflected_side = FRONT_FACING ? hit_height > water_height + 0.05 : hit_height < water_height - 0.05;
   if (previous_gap < 0.0 && gap >= 0.0 && gap < max(0.5, travel * 0.14) && reflected_side) {
    float edge = smoothstep(0.0, 0.08, min(min(uv.x, uv.y), min(1.0 - uv.x, 1.0 - uv.y)));
    reflected = mix(reflected, textureLod(screen_texture, uv, water_roughness * 3.0).rgb, edge);
    break;
   }
   previous_gap = gap;
  }
 }
 if (FRONT_FACING && use_planar_reflection) {
  vec4 reflected_clip = reflection_view_projection * vec4(water_world_xz.x, reflection_plane_height, water_world_xz.y, 1.0);
  vec2 uv = reflected_clip.xy / reflected_clip.w * 0.5 + 0.5;
  // Camera3D 的 CPU 投影中 +Y 向上，而 ViewportTexture 的 UV 中 +Y 向下。
  uv.y = 1.0 - uv.y;
  uv += (NORMAL - flat_normal).xy * reflection_distortion * shore;
  float edge = smoothstep(0.005, 0.06, min(min(uv.x, uv.y), min(1.0 - uv.x, 1.0 - uv.y)));
  if (reflected_clip.w > 0.0 && edge > 0.0) {
   // 视口纹理没有多级渐远纹理链，使用小范围的五点采样滤波柔化闪光。
   vec2 blur = vec2(water_roughness * 0.007);
   vec3 mirror = texture(planar_reflection, uv).rgb * 0.4;
   mirror += (texture(planar_reflection, uv + vec2(blur.x, 0.0)).rgb + texture(planar_reflection, uv - vec2(blur.x, 0.0)).rgb
    + texture(planar_reflection, uv + vec2(0.0, blur.y)).rgb + texture(planar_reflection, uv - vec2(0.0, blur.y)).rgb) * 0.15;
   // HDR 倒影视口提供主色调映射之前的线性光照。
   reflected = mix(reflected, mirror, edge);
  }
 }
 float foam_noise = smooth_noise(water_world_xz * 1.8 + vec2(0.2, -0.15) * time).x;
 float foam = (1.0 - smoothstep(0.15, 1.0, depth)) * smoothstep(0.42, 0.72, foam_noise) * foam_strength;
 // 镜面和海床颜色作为已有光照合成；只有水体散射与泡沫接收直射光。
 // 单独同步环境补光，避免巨大水面再次采样局部烘焙 GI 产生边界。
 ALBEDO = mix(scattering * (1.0 - fresnel), vec3(0.80, 0.88, 0.86), foam);
 EMISSION = mix(mix(transmitted, reflected, fresnel), vec3(0.0), foam) + ALBEDO * water_ambient_light;
 ROUGHNESS = mix(water_roughness, 0.65, foam);
 SPECULAR = highlight_strength * shore;
 surface_specular = highlight_strength * shore;
 // 使用透明混合衔接已带雾的岸边海床，避免岸线被重复叠加雾色。
 ALPHA = shore;
}
void light() {
 float visibility = cloud_ground_light_visibility(LIGHT, INV_VIEW_MATRIX, LIGHT_IS_DIRECTIONAL, water_cloud_visibility);
 DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * visibility * max(dot(NORMAL, LIGHT), 0.0) / PI;
 vec3 half_vector = normalize(LIGHT + VIEW);
 float ndl = max(dot(NORMAL, LIGHT), 0.0);
 float ndv = max(dot(NORMAL, VIEW), 0.001);
 float ndh = max(dot(NORMAL, half_vector), 0.0);
 float vdh = max(dot(VIEW, half_vector), 0.0);
 float a = max(ROUGHNESS * ROUGHNESS, 0.003);
 float a2 = a * a;
 float denominator = ndh * ndh * (a2 - 1.0) + 1.0;
 float distribution = a2 / (PI * denominator * denominator);
 float k = (ROUGHNESS + 1.0) * (ROUGHNESS + 1.0) / 8.0;
 float geometry = ndv / (ndv * (1.0 - k) + k) * ndl / (ndl * (1.0 - k) + k);
 float fresnel = 0.0204 + 0.9796 * pow(1.0 - vdh, 5.0);
 SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * visibility * distribution * geometry * fresnel / max(4.0 * ndv, 0.001) * SPECULAR_AMOUNT * surface_specular;
}
