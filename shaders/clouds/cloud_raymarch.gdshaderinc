#include "res://shaders/clouds/cloud_density.gdshaderinc"
#include "res://shaders/clouds/cloud_lighting.gdshaderinc"
#include "res://shaders/clouds/cloud_sky_color.gdshaderinc"

uniform int march_steps : hint_range(16, 192) = 96;
uniform float max_distance = 300000.0;
uniform float detail_distance = 80000.0;
uniform float haze_strength : hint_range(0.0, 1.0) = 0.75;
uniform int sky_style = 0;
uniform bool sky_link_lighting = true;
uniform vec4 cloud_color : source_color = vec4(0.95, 0.97, 1.0, 1.0);
// 世界空间中从采样点指向太阳的单位方向，不是光传播方向。
uniform vec3 sun_direction = vec3(-0.57922797, 0.57357644, 0.57922797);
uniform vec4 sun_color : source_color = vec4(1.0, 0.95, 0.88, 1.0);
uniform float sun_intensity : hint_range(0.0, 5.0) = 1.8;
uniform vec4 ambient_color : source_color = vec4(0.65, 0.75, 1.0, 1.0);
uniform float ambient_intensity : hint_range(0.0, 1.0) = 0.25;
uniform bool self_shadow = true;
uniform int light_steps : hint_range(1, 16) = 6;
uniform bool adaptive_sampling = true;
uniform bool light_low_frequency = true;
uniform int empty_step_scale : hint_range(1, 4) = 3;

// imp.md 的固定六向量核；增加 Light Steps 时循环使用，保持世界空间稳定。
vec3 cloud_light_kernel(int index) {
	int slot = index % 6;
	if (slot == 0) { return vec3(0.38051305, 0.92453449, -0.02111345); }
	if (slot == 1) { return vec3(-0.50625799, -0.03590792, -0.86163418); }
	if (slot == 2) { return vec3(-0.32509218, -0.94557439, 0.01428793); }
	if (slot == 3) { return vec3(0.09026238, -0.27376545, 0.95755165); }
	if (slot == 4) { return vec3(0.28128598, 0.42443639, -0.86065785); }
	return vec3(-0.16852403, 0.14748697, 0.97460106);
}

float sample_sun_optical_depth(vec3 sample_position, float view_step_length, float view_mip, float view_detail, float view_opacity, float optical_depth_cutoff) {
	vec3 direction_to_sun = normalize(sun_direction);
	// 太阳步幅跟随视线细步，预算决定近处范围，不再均分整条云壳光路。
	float light_step_length = max(view_step_length, 0.1);
	vec4 light_intervals = intersect_cloud_shell(sample_position, direction_to_sun, light_step_length * float(light_steps));
	if (cloud_shell_length(light_intervals) <= 0.0) {
		return 0.0;
	}
	float optical_depth = 0.0;
	// 对齐外部 alpha≈0.3 后的廉价查询，连续撤掉侵蚀，避免硬切换。
	float erosion_weight = light_low_frequency ? 1.0 - smoothstep(0.25, 0.35, view_opacity) : 1.0;
	for (int light_index = 0; light_index < 16; light_index++) {
		if (light_index >= light_steps) {
			break;
		}
		float cell_start = float(light_index) * light_step_length;
		if (cell_start >= max(light_intervals.y, light_intervals.w)) {
			break;
		}
		float cell_end = cell_start + light_step_length;
		vec3 cone_offset = vec3(0.0);
		float light_mip = view_mip;
		if (light_low_frequency) {
			vec3 kernel = cloud_light_kernel(light_index);
			// 核投到太阳法平面，保证锥体围绕光轴展开，无参考轴切换。
			kernel -= direction_to_sun * dot(kernel, direction_to_sun);
			float cone_radius = light_step_length * float(light_index) * (1.0 + float(light_index) / float(light_steps));
			cone_offset = kernel * cone_radius;
			// 真正采样 mip，覆盖锥体足迹；每两步额外提升约一个层级。
			light_mip = max(view_mip + float(light_index) * 0.5,
				cloud_noise_mip_for_footprint(max(light_step_length, cone_radius * 2.0)));
		}
		// 光路按实际射线距离行进，内球空腔不占消光长度，也不跳到范围外。
		for (int shell_index = 0; shell_index < 2; shell_index++) {
			vec2 interval = shell_index == 0 ? light_intervals.xy : light_intervals.zw;
			float entry = max(cell_start, interval.x);
			float exit_distance = min(cell_end, interval.y);
			if (exit_distance <= entry) {
				continue;
			}
			vec3 light_position = sample_position + direction_to_sun * ((entry + exit_distance) * 0.5) + cone_offset;
			float light_density = sample_cloud_density_lod(light_position, 3, view_detail, light_mip, erosion_weight) * density_multiplier;
			optical_depth += light_density * extinction * (exit_distance - entry);
		}
		if (optical_depth > optical_depth_cutoff) {
			break;
		}
	}
	return optical_depth;
}

// 空域/密度/太阳查询复用原步进路径；不在这里读取场景纹理或完成颜色合成。
vec4 cloud_raymarch(vec3 ray_origin, vec3 ray_direction, float ray_limit, float pixel_ray_width) {
	float cos_angle = clamp(dot(ray_direction, normalize(sun_direction)), -1.0, 1.0);
	float away_from_sun = cloud_away_from_sun(cos_angle);
	float directional_scattering = nubis_lighting ? cloud_directional_scattering(cos_angle) : 1.0;
	float optical_depth_cutoff = nubis_lighting && multi_scatter_strength > 0.0 && away_from_sun > 0.0 ? 21.2 : 5.3;
	vec4 intervals = intersect_cloud_shell(ray_origin, ray_direction, ray_limit);
	float cloud_length = cloud_shell_length(intervals);

	float transmittance = 1.0;
	float accumulated_direct = 0.0;
	float accumulated_ambient = 0.0;
	float weighted_distance = 0.0;
	float half_opacity_distance = -1.0;
	if (cloud_length > 0.0 && density_multiplier > 0.0 && extinction > 0.0 && coverage_amount > 0.0) {
		// 原文 54（朝上）到 96（地平线）；march_steps 仍是可调的最大预算。
		float step_count = float(march_steps);
		if (adaptive_sampling) {
			float vertical_view = abs(dot(ray_direction, cloud_local_up(ray_origin)));
			step_count = ceil(mix(float(march_steps), max(16.0, float(march_steps) * 0.5625), vertical_view));
		}
		// 两段云壳共享预算，不把内球空腔计入步长。
		float step_length = max(cloud_length / step_count, 0.1);
		float distance_along_ray = intervals.x;
		float interval_end = intervals.y;
		bool second_interval = false;
		bool fine_sampling = !adaptive_sampling;
		int empty_samples = 0;
		// 额外预算容纳每次由粗采样切入精采样的回退，不缩短可见距离。
		for (int sample_index = 0; sample_index < 384; sample_index++) {
			if (distance_along_ray >= interval_end) {
				if (!second_interval && intervals.w > intervals.z) {
					second_interval = true;
					distance_along_ray = intervals.z;
					interval_end = intervals.w;
					fine_sampling = !adaptive_sampling;
					empty_samples = 0;
				} else {
					break;
				}
			}
			if (!fine_sampling) {
				float coarse_length = min(step_length * float(empty_step_scale), interval_end - distance_along_ray);
				float coarse_distance = distance_along_ray + 0.5 * coarse_length;
				vec3 coarse_position = ray_origin + ray_direction * coarse_distance;
				// 上界查询使用细步的过滤尺度，不用未过滤噪声判空后跳过平滑云边。
				float coarse_mip = cloud_noise_mip_for_footprint(max(step_length, coarse_distance * pixel_ray_width));
				if (sample_cloud_density_lod(coarse_position, 0, 1.0, coarse_mip, 0.0) <= 0.0) {
					distance_along_ray += coarse_length;
					continue;
				}
				// 从该粗步的起点重新细走，粗密度不会写入最终颜色。
				fine_sampling = true;
				empty_samples = 0;
			}
			float segment_length = min(step_length, interval_end - distance_along_ray);
			float sample_distance = distance_along_ray + 0.5 * segment_length;
			vec3 sample_position = ray_origin + ray_direction * sample_distance;
			distance_along_ray += segment_length;
			// 在形状、覆盖度和高度计算之后调节强度，所有密度模式共用。
			float detail_factor = 1.0 - smoothstep(detail_distance * 0.25, detail_distance, sample_distance);
			// 以实际三维 mip 过滤每个频段，不再用删 octave 代替步长过滤。
			float view_mip = cloud_noise_mip_for_footprint(max(segment_length, sample_distance * pixel_ray_width));
			float density = sample_cloud_density_lod(sample_position, 3, detail_factor, view_mip, 1.0) * density_multiplier;
			density *= 1.0 - smoothstep(max_distance * 0.9, max_distance, sample_distance);
			if (density <= 0.0) {
				empty_samples++;
				if (adaptive_sampling && empty_samples >= 10) {
					fine_sampling = false;
				}
				continue;
			}
			empty_samples = 0;
			float segment_transmittance = exp(-density * extinction * segment_length);
			float sun_optical_depth = 0.0;
			bool sun_visible = cloud_sun_visible(sample_position, normalize(sun_direction));
			if (self_shadow && sun_intensity > 0.0 && sun_visible) {
				sun_optical_depth = sample_sun_optical_depth(sample_position, step_length, view_mip, detail_factor, 1.0 - transmittance, optical_depth_cutoff);
			}
			float attenuation = cloud_light_attenuation(sun_optical_depth, away_from_sun);
			float in_scatter_probability = 1.0;
			if (nubis_lighting && in_scatter_strength > 0.0 && away_from_sun > 0.0 && sun_intensity > 0.0 && sun_visible) {
				// 入散射使用真正的低 mip 基础形状，避免删 octave 改变密度模型。
				float lodded_density = clamp(sample_cloud_density_lod(sample_position, 3, detail_factor, view_mip + 2.0, 0.0) * density_multiplier, 0.0, 1.0);
				float height_fraction = cloud_height_fraction(sample_position);
				in_scatter_probability = cloud_in_scatter_probability(lodded_density, height_fraction, away_from_sun);
			}
			// 保留独立环境补光；太阳贡献组合原文三项，颜色和亮度不截断 HDR。
			float solar_elevation = cloud_solar_elevation(sample_position, normalize(sun_direction));
			float daylight = smoothstep(-0.10, 0.20, solar_elevation);
			float ambient_scale = sky_link_lighting ? mix(0.08, 1.0, daylight) : 1.0;
			float solar_scale = sun_visible ? 1.0 : 0.0;
			if (sky_link_lighting) {
				solar_scale *= smoothstep(-0.04, 0.08, solar_elevation);
			}
			float contribution = transmittance * (1.0 - segment_transmittance);
			accumulated_direct += contribution * sun_intensity * solar_scale * directional_scattering * attenuation * in_scatter_probability;
			accumulated_ambient += contribution * ambient_intensity * ambient_scale;
			weighted_distance += contribution * sample_distance;
			float previous_transmittance = transmittance;
			transmittance *= segment_transmittance;
			if (half_opacity_distance < 0.0 && transmittance <= 0.5) {
				// 解析该恒密度段内 alpha=0.5 的位置，避免代表深度按整步跳动。
				float crossing = log(previous_transmittance / 0.5) / max(density * extinction, 0.00000001);
				half_opacity_distance = sample_distance - segment_length * 0.5 + clamp(crossing, 0.0, segment_length);
			}
			if (transmittance < 0.005) {
				break;
			}
		}
	}
	float opacity = 1.0 - transmittance;
	float representative_distance = half_opacity_distance >= 0.0 ? half_opacity_distance : weighted_distance / max(opacity, 0.00001);
	// RG 是非预乘直接光/环境光，B 是米制代表深度，A 是不透明度。
	return vec4(accumulated_direct / max(opacity, 0.00001), accumulated_ambient / max(opacity, 0.00001), representative_distance, opacity);
}
