// 以世界海拔、坡度及三维噪声着色地形。
// 区分海床、沙滩、土壤、岩石和高地，并叠加细节法线及太阳云影。

shader_type spatial;
#include "res://shaders/clouds/cloud_ground_shadow.gdshaderinc"
render_mode diffuse_burley, specular_schlick_ggx;

group_uniforms Coast;
// 世界坐标采样保证分块接缝连续，sea_level 由场景同步实际水位。
// 世界海平面 Y 坐标（米）；由地图同步实际水位，决定海床和岸线的位置。
uniform float sea_level = 15.0;
// 沙滩向土壤过渡的起始相对海拔（米）；提高后沙滩向高处延伸。
uniform float beach_start : hint_range(0.0, 30.0) = 3.0;
// 沙滩向土壤过渡的结束相对海拔（米）；应大于起始值，间隔越大过渡越宽。
uniform float beach_end : hint_range(1.0, 60.0) = 18.0;
// 湿沙带高度尺度（米）；越大水线附近的深色湿润区域越宽。
uniform float wet_band : hint_range(0.1, 8.0) = 2.0;
// 岸线噪声高度扰动幅度（米）；增大后沙滩边界更不规则。
uniform float shore_variation : hint_range(0.0, 6.0) = 1.6;

group_uniforms Rock;
// 开始显示岩石的坡度角（度）；降低后较缓坡也显示岩石。
uniform float rock_start_degrees : hint_range(0.0, 85.0) = 27.0;
// 完全显示岩石的坡度角（度）；应大于起始角，控制土岩过渡宽度。
uniform float rock_full_degrees : hint_range(1.0, 89.0) = 52.0;
// 开始高地配色的相对海平面高度（米）；应小于高地结束高度，另叠加大型噪声扰动。
uniform float highland_start : hint_range(50.0, 1200.0) = 260.0;
// 完全使用高地配色的相对海平面高度（米）；决定山顶浅色区域的过渡终点。
uniform float highland_end : hint_range(60.0, 1500.0) = 680.0;
// 岩层纹理竖直间距（米）；越大岩层条带越稀疏。
uniform float strata_spacing : hint_range(1.0, 40.0) = 12.0;
// 岩层色彩变化强度；0 隐藏条带，增大会增强层理对比。
uniform float strata_strength : hint_range(0.0, 0.25) = 0.07;

group_uniforms Palette;
// 海平面以下地表颜色；影响海床和浅水折射中可见的地面。
uniform vec4 seabed_color : source_color = vec4(0.36, 0.38, 0.36, 1.0);
// 岸边沙滩颜色；与湿沙、土壤按相对水位混合。
uniform vec4 sand_color : source_color = vec4(0.68, 0.60, 0.44, 1.0);
// 低坡普通地表颜色；作为土壤区域的基础配色。
uniform vec4 soil_color : source_color = vec4(0.49, 0.43, 0.34, 1.0);
// 陡坡岩石颜色；按坡度权重与土壤、高地混合。
uniform vec4 rock_color : source_color = vec4(0.40, 0.42, 0.44, 1.0);
// 高海拔地表颜色；达到高地结束海拔后完整应用。
uniform vec4 highland_color : source_color = vec4(0.58, 0.57, 0.53, 1.0);

group_uniforms Detail;
// 大尺度地表噪声的空间频率（每米）；越大色块尺度越小。
uniform float macro_scale : hint_range(0.001, 0.05, 0.001) = 0.006;
// 中尺度地表噪声的空间频率（每米）；越大明暗细节越细。
uniform float detail_scale : hint_range(0.02, 1.0, 0.01) = 0.12;
// 细颗粒噪声的空间频率（每米）；越大颗粒更细，远景按像素足迹衰减。
uniform float grain_scale : hint_range(0.1, 10.0, 0.1) = 2.4;
// 地表噪声明暗变化强度；越大表面颜色对比越明显。
uniform float detail_strength : hint_range(0.0, 0.4) = 0.16;
// 细节法线扰动强度；增大会增强地面凹凸观感，不改变几何和碰撞。
uniform float bump_strength : hint_range(0.0, 0.5) = 0.12;
group_uniforms;

varying vec3 terrain_world_position;
varying vec3 terrain_world_normal;
varying float terrain_cloud_visibility;
varying float terrain_surface_specular;

float hash_position(vec3 cell) {
	vec3 p = fract(cell * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

// 三维噪声避免峭壁的 UV 拉伸；细节按屏幕像素大小衰减。
float terrain_noise(vec3 position) {
	vec3 cell = floor(position);
	vec3 f = fract(position);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash_position(cell), hash_position(cell + vec3(1, 0, 0)), f.x),
			mix(hash_position(cell + vec3(0, 1, 0)), hash_position(cell + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash_position(cell + vec3(0, 0, 1)), hash_position(cell + vec3(1, 0, 1)), f.x),
			mix(hash_position(cell + vec3(0, 1, 1)), hash_position(cell + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	terrain_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	terrain_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	// 沿用现有海面倒影通道的裁剪约定，主视图、水下仍正常绘制海床。
	if ((CAMERA_VISIBLE_LAYERS & 786432u) == 262144u && terrain_world_position.y < sea_level + 0.02) {
		discard;
	}
	terrain_cloud_visibility = cloud_ground_visibility(terrain_world_position, CAMERA_VISIBLE_LAYERS);
	float height = terrain_world_position.y - sea_level;
	float macro = terrain_noise(terrain_world_position * macro_scale);
	float detail = terrain_noise(terrain_world_position * detail_scale);
	float coast_height = height + (detail - 0.5) * shore_variation;
	float beach = 1.0 - smoothstep(beach_start, max(beach_end, beach_start + 0.1), coast_height);
	float submerged = 1.0 - smoothstep(-14.0, -2.0, height);
	float wetness = 1.0 - smoothstep(-0.5, max(wet_band, 0.1), height);
	float up = clamp(normalize(terrain_world_normal).y, 0.0, 1.0);
	float rock_low = cos(radians(rock_start_degrees));
	float rock_high = cos(radians(max(rock_full_degrees, rock_start_degrees + 0.1)));
	float cliff = 1.0 - smoothstep(rock_high, rock_low, up);
	float highland = smoothstep(highland_start, max(highland_end, highland_start + 1.0), height + (macro - 0.5) * 100.0);
	float rock_weight = max(cliff, highland * 0.8);
	vec3 earth = mix(soil_color.rgb, sand_color.rgb, beach);
	earth = mix(earth, seabed_color.rgb, submerged);
	vec3 stone = mix(rock_color.rgb, highland_color.rgb, highland);
	float strata_phase = (terrain_world_position.y + (detail - 0.5) * 5.0) / max(strata_spacing, 1.0) * 6.283185;
	float strata_visibility = 1.0 - smoothstep(0.5, 2.0, fwidth(strata_phase));
	stone *= 1.0 + sin(strata_phase) * strata_strength * strata_visibility;
	vec3 surface_color = mix(earth, stone, rock_weight);
	vec3 grain_position = terrain_world_position * grain_scale;
	float grain_visibility = 1.0 - smoothstep(0.25, 1.2, length(fwidth(grain_position)));
	float grain = (terrain_noise(grain_position) - 0.5) * grain_visibility;
	float variation = (macro - 0.5) * 0.30 + (detail - 0.5) * detail_strength + grain * detail_strength;
	ALBEDO = surface_color * (1.0 + variation) * (1.0 - wetness * 0.22);
	ROUGHNESS = mix(mix(0.96, 0.87, rock_weight), 0.62, wetness);
	SPECULAR = mix(0.20, 0.32, wetness);
	terrain_surface_specular = SPECULAR;
	// 导数扰动细微凹凸，不依赖导入网格的切线或法线贴图。
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 n = normalize(NORMAL);
	vec3 tangent_x = cross(dpdy, n);
	vec3 tangent_y = cross(n, dpdx);
	float determinant = dot(dpdx, tangent_x);
	float relief = detail * bump_strength * grain_visibility;
	vec3 gradient = sign(determinant) * (dFdx(relief) * tangent_x + dFdy(relief) * tangent_y);
	NORMAL = normalize(n - gradient / max(abs(determinant), 0.00001));
}

void light() {
	float visibility = cloud_ground_light_visibility(LIGHT, INV_VIEW_MATRIX, LIGHT_IS_DIRECTIONAL, terrain_cloud_visibility);
	float ndl = max(dot(NORMAL, LIGHT), 0.0);
	float ndv = max(dot(NORMAL, VIEW), 0.001);
	vec3 half_vector = normalize(LIGHT + VIEW);
	float ndh = max(dot(NORMAL, half_vector), 0.0);
	float vdh = max(dot(VIEW, half_vector), 0.0);
	// Burley 漫反射保留粗糙地表的掠射角响应，云影只乘直射光。
	float fd90 = 0.5 + 2.0 * ROUGHNESS * vdh * vdh;
	float diffuse = (1.0 + (fd90 - 1.0) * pow(1.0 - ndl, 5.0))
		* (1.0 + (fd90 - 1.0) * pow(1.0 - ndv, 5.0));
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * visibility * ndl * diffuse / PI;
	float a = max(ROUGHNESS * ROUGHNESS, 0.003);
	float a2 = a * a;
	float denominator = ndh * ndh * (a2 - 1.0) + 1.0;
	float distribution = a2 / (PI * denominator * denominator);
	float k = (ROUGHNESS + 1.0) * (ROUGHNESS + 1.0) / 8.0;
	float geometry = ndv / (ndv * (1.0 - k) + k) * ndl / (ndl * (1.0 - k) + k);
	float f0 = 0.16 * terrain_surface_specular * terrain_surface_specular;
	float fresnel = f0 + (1.0 - f0) * pow(1.0 - vdh, 5.0);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * visibility * distribution * geometry * fresnel
		/ max(4.0 * ndv, 0.001) * SPECULAR_AMOUNT;
}
