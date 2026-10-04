shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://草地分布.gdshaderinc"

group_uniforms Elevation;
// 高度使用世界空间的 Y 坐标，sea_level 须与水面节点的高度一致。
uniform float sea_level = 15.0;
// 偏移量相对于 sea_level；岸线下方的海床逐渐过渡为沙地。
uniform float sand_start : hint_range(-20.0, 0.0, 0.1) = -3.0;
uniform float sand_full : hint_range(-20.0, 0.0, 0.1) = -1.0;
uniform float grass_start : hint_range(0.0, 20.0, 0.1) = 2.0;
uniform float grass_full : hint_range(0.0, 20.0, 0.1) = 4.0;
uniform float boundary_variation : hint_range(0.0, 2.0, 0.05) = 0.35;

group_uniforms Slope;
uniform float rock_start_degrees : hint_range(0.0, 89.0, 1.0) = 38.0;
uniform float rock_full_degrees : hint_range(0.0, 90.0, 1.0) = 55.0;

group_uniforms Colors;
uniform vec4 gravel_color : source_color = vec4(0.43, 0.45, 0.47, 1.0);
uniform vec4 sand_color : source_color = vec4(0.78, 0.69, 0.47, 1.0);
uniform vec4 grass_color : source_color = vec4(0.27, 0.46, 0.15, 1.0);
uniform vec4 rock_color : source_color = vec4(0.40, 0.39, 0.37, 1.0);
uniform float wet_sand_darkening : hint_range(0.0, 0.5, 0.01) = 0.2;

group_uniforms Detail;
uniform float patch_scale : hint_range(0.01, 1.0, 0.01) = 0.08;
uniform float grain_scale : hint_range(0.1, 20.0, 0.1) = 4.0;
uniform float detail_strength : hint_range(0.0, 0.5, 0.01) = 0.22;
group_uniforms;

varying vec3 terrain_world_position;
varying vec3 terrain_world_normal;

float hash_position(vec3 cell) {
	vec3 p = fract(cell * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

// 世界空间中的三维噪声可避免地形侧面的 UV 拉伸。
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
	terrain_world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	// 倒影摄像机排除第 20 层的水面，并以第 19 层作为标记。
	// 仅在倒影渲染通道中裁剪海床，防止其遮挡镜像岸线。
	if ((CAMERA_VISIBLE_LAYERS & 786432u) == 262144u && terrain_world_position.y < sea_level + 0.02) {
		discard;
	}
	float patch = terrain_noise(terrain_world_position * patch_scale);
	float height = terrain_world_position.y - sea_level + (patch - 0.5) * 2.0 * boundary_variation;
	// 即使检查器中的数值重叠，也确保过渡宽度不为零。
	float sand_weight = smoothstep(sand_start, max(sand_full, sand_start + 0.01), height);
	float grass_weight = smoothstep(grass_start, max(grass_full, grass_start + 0.01), height);
	// 与草叶斑块的分布保持一致，在斑块之间留出裸露的沙土。
	grass_weight *= grass_patch_density(terrain_world_position.xz);
	grass_weight *= smoothstep(0.0, 0.6, terrain_world_position.y - sea_level);
	float wetness = 1.0 - smoothstep(0.0, max(grass_start, 0.01), terrain_world_position.y - sea_level);
	// 以世界空间法线判断坡度，陡坡覆盖海拔对应的沙地和草地颜色。
	float slope = acos(clamp(normalize(terrain_world_normal).y, 0.0, 1.0));
	float rock_weight = smoothstep(radians(rock_start_degrees),
		radians(max(rock_full_degrees, rock_start_degrees + 0.01)), slope);

	vec3 grain_position = terrain_world_position * grain_scale;
	// 在远处逐渐淡出小于像素的颗粒，小地图也采用同样处理。
	float grain_visibility = 1.0 - smoothstep(0.3, 1.5, length(fwidth(grain_position)));
	float grain = (terrain_noise(grain_position) - 0.5) * grain_visibility;
	float gravel_detail = 1.0 + grain * detail_strength * 2.0;
	float sand_detail = 1.0 + grain * detail_strength * 0.65;
	float grass_detail = 1.0 + (patch - 0.5) * detail_strength * 1.5 + grain * detail_strength;

	vec3 gravel = gravel_color.rgb * gravel_detail;
	vec3 sand = sand_color.rgb * sand_detail * (1.0 - wetness * wet_sand_darkening);
	vec3 grass = grass_color.rgb * grass_detail;
	vec3 rock = rock_color.rgb * (1.0 + (patch - 0.5) * detail_strength + grain * detail_strength * 2.0);
	ALBEDO = mix(mix(mix(gravel, sand, sand_weight), grass, grass_weight), rock, rock_weight);
	ROUGHNESS = mix(mix(mix(0.95, mix(0.92, 0.7, wetness), sand_weight), 0.96, grass_weight), 0.93, rock_weight);
	SPECULAR = 0.18;
}
