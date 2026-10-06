shader_type spatial;
#include "res://shaders/clouds/cloud_ground_shadow.gdshaderinc"
render_mode diffuse_burley, specular_schlick_ggx;

group_uniforms Coast;
// 世界坐标采样保证分块接缝连续，sea_level 由场景同步实际水位。
uniform float sea_level = 15.0;
uniform float beach_start : hint_range(0.0, 30.0) = 3.0;
uniform float beach_end : hint_range(1.0, 60.0) = 18.0;
uniform float wet_band : hint_range(0.1, 8.0) = 2.0;
uniform float shore_variation : hint_range(0.0, 6.0) = 1.6;

group_uniforms Rock;
uniform float rock_start_degrees : hint_range(0.0, 85.0) = 27.0;
uniform float rock_full_degrees : hint_range(1.0, 89.0) = 52.0;
uniform float highland_start : hint_range(50.0, 1200.0) = 260.0;
uniform float highland_end : hint_range(60.0, 1500.0) = 680.0;
uniform float strata_spacing : hint_range(1.0, 40.0) = 12.0;
uniform float strata_strength : hint_range(0.0, 0.25) = 0.07;

group_uniforms Palette;
uniform vec4 seabed_color : source_color = vec4(0.36, 0.38, 0.36, 1.0);
uniform vec4 sand_color : source_color = vec4(0.68, 0.60, 0.44, 1.0);
uniform vec4 soil_color : source_color = vec4(0.49, 0.43, 0.34, 1.0);
uniform vec4 rock_color : source_color = vec4(0.40, 0.42, 0.44, 1.0);
uniform vec4 highland_color : source_color = vec4(0.58, 0.57, 0.53, 1.0);

group_uniforms Detail;
uniform float macro_scale : hint_range(0.001, 0.05, 0.001) = 0.006;
uniform float detail_scale : hint_range(0.02, 1.0, 0.01) = 0.12;
uniform float grain_scale : hint_range(0.1, 10.0, 0.1) = 2.4;
uniform float detail_strength : hint_range(0.0, 0.4) = 0.16;
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
