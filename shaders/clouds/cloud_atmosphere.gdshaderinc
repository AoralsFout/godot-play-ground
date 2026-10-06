// PDF 101 的 GetAtmosphere(depth, angle)：这里用米制、分层介质积分近似。
// 原文没有给出 Decima 的大气查找表/系数，这些系数是本项目的实现选择。
uniform float atmosphere_density : hint_range(0.0, 3.0) = 1.0;
uniform bool light_shafts_enabled = true;
uniform float light_shaft_strength : hint_range(0.0, 3.0) = 0.8;
uniform float light_shaft_start : hint_range(500.0, 10000.0) = 2000.0;
uniform int light_shaft_samples : hint_range(16, 64) = 32;
uniform int post_debug_view = 0;
// 镜像摄像机位于海平面下；云使用镜像回海面上的观察位置，避免被星球裁掉。
uniform bool cloud_reflection_view = false;
uniform float cloud_reflection_height = 15.0;

// x/y 为累积 Rayleigh / Mie 光学深度。径向高度与视角共同决定密度。
vec2 cloud_atmosphere_segment(float start_distance, float end_distance, vec3 origin, vec3 direction) {
	float entry = clamp(start_distance, 0.0, max_distance);
	float exit_distance = clamp(end_distance, entry, max_distance);
	vec2 optical_depth = vec2(0.0);
	for (int index = 0; index < 12; index++) {
		// 非均匀步幅保留相机附近的薄大气层，长视线不会跨过整个 Mie 层。
		float t0 = float(index) / 12.0;
		float t1 = float(index + 1) / 12.0;
		t0 *= t0;
		t1 *= t1;
		float segment = (exit_distance - entry) * (t1 - t0);
		vec3 position = origin + direction * mix(entry, exit_distance, (t0 + t1) * 0.5);
		float altitude = max(cloud_altitude(position), 0.0);
		optical_depth += vec2(exp(-altitude / 8000.0) * 0.000017,
			exp(-altitude / 1200.0) * 0.000008) * segment;
	}
	return optical_depth * atmosphere_density;
}

vec2 cloud_atmosphere_depth(float distance_to_point, vec3 origin, vec3 direction) {
	return cloud_atmosphere_segment(0.0, distance_to_point, origin, direction);
}

float cloud_atmospheric_blend(float representative_distance, vec3 origin, vec3 direction) {
	if (haze_strength <= 0.0 || atmosphere_density <= 0.0 || representative_distance <= 0.0) {
		return 0.0;
	}
	vec2 optical_depth = cloud_atmosphere_depth(representative_distance, origin, direction);
	return haze_strength * (1.0 - exp(-optical_depth.x - optical_depth.y));
}

vec3 cloud_post_lighting(float direct_intensity, float ambient_intensity_value, float representative_distance, vec3 origin, vec3 direction) {
	vec3 position = origin + direction * representative_distance;
	float elevation = cloud_solar_elevation(position, normalize(sun_direction));
	float daylight = smoothstep(-0.10, 0.20, elevation);
	vec3 solar_tint = sky_link_lighting ? cloud_solar_tint(elevation) : vec3(1.0);
	vec3 ambient_tint = sky_link_lighting ? mix(vec3(0.45, 0.5, 0.8), vec3(1.0), daylight) : vec3(1.0);
	return cloud_color.rgb * (sun_color.rgb * solar_tint * direct_intensity
		+ ambient_color.rgb * ambient_tint * ambient_intensity_value);
}

vec3 cloud_mie_shafts(float mask, float distance_to_point, vec3 origin, vec3 direction) {
	if (!light_shafts_enabled || mask <= 0.0 || light_shaft_strength <= 0.0 || sun_intensity <= 0.0) {
		return vec3(0.0);
	}
	// 在远处才启用；近物体截断空气段，光束不覆盖邻近景物。
	float distant_gate = smoothstep(light_shaft_start, light_shaft_start * 2.0, distance_to_point);
	if (distant_gate <= 0.0 || atmosphere_density <= 0.0) {
		return vec3(0.0);
	}
	float mie_depth = cloud_atmosphere_segment(light_shaft_start, distance_to_point, origin, direction).y;
	float alignment = clamp(dot(direction, normalize(sun_direction)), -1.0, 1.0);
	float phase = cloud_henyey_greenstein(alignment, 0.8) * (4.0 * PI);
	float elevation = cloud_solar_elevation(origin, normalize(sun_direction));
	float daylight = smoothstep(-0.04, 0.08, elevation);
	vec3 tint = sun_color.rgb * cloud_solar_tint(elevation);
	return tint * sun_intensity * daylight * phase * (1.0 - exp(-mie_depth))
		* mask * light_shaft_strength * distant_gate;
}
