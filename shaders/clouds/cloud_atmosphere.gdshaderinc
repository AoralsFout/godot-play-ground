// 积分球形大气的瑞利和米氏散射，供云融合及光束合成共用。
// 参数由体积云控制器同步，倒影视角先修正观察位置以避免星球错误遮挡。

// PDF 101 的 GetAtmosphere(depth, angle)：这里用米制、分层介质积分近似。
// 原文没有给出 Decima 的大气查找表/系数，这些系数是本项目的实现选择。
// 大气总体密度倍率；提高会增强远景消光和大气融合。
uniform float atmosphere_density : hint_range(0.0, 3.0) = 1.0;
// 日月光束开关；仅在计算后处理有效时产生光束，基础预览不绘制。
uniform bool light_shafts_enabled = true;
// 光束合成强度倍率；0 隐藏光束，不改变云密度。
uniform float light_shaft_strength : hint_range(0.0, 3.0) = 1.0;
// 光束散射开始距离（米）；近景逐渐启用，几何深度会截断被遮挡部分。
uniform float light_shaft_start : hint_range(500.0, 10000.0) = 500.0;
// 径向光束模糊采样次数；越大越平滑，同时增加计算成本。
uniform int light_shaft_samples : hint_range(16, 64) = 64;
// 高光半强度角（度），不是太阳圆盘大小。宽高光才能让多个云隙形成光束。
// 光源周围高光的半强度角（度）；越大越远的云隙也参与光束，不改变日月盘尺寸。
uniform float light_shaft_spread : hint_range(5.0, 60.0) = 35.0;
// 径向光束延伸比例；越大条带延伸越远，受光源屏幕位置影响。
uniform float light_shaft_length : hint_range(0.1, 0.98) = 0.94;
// 光束高光源沿径向的偏移比例；改变条带起始分布，与延伸长度共同影响形状。
uniform float light_shaft_offset : hint_range(0.0, 0.3) = 0.12;
// 气溶胶影响大气融合和光束，保留同一介质的颜色/消光关系。
// 米氏散射气溶胶密度倍率；影响光束和大气融合的散射及消光。
uniform float atmosphere_mie_density : hint_range(0.0, 3.0) = 1.0;
// 后处理输出通道；0 为最终画面，1 至 8 依次显示直射、大气、环境、不透明度、光束、种子高光、米氏贡献和月光。
uniform int post_debug_view = 0;
// 镜像摄像机位于海平面下；云使用镜像回海面上的观察位置，避免被星球裁掉。
// 倒影视角标记；开启后镜像修正云观察位置，避免海面下的虚拟相机被星球遮挡。
uniform bool cloud_reflection_view = false;
// 镜像海平面世界高度（米）；用于恢复云观察位置，应与真实水面一致。
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
			exp(-altitude / 2000.0) * 0.00002 * atmosphere_mie_density) * segment;
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

vec3 cloud_post_lighting(float direct_intensity, float lunar_intensity, float ambient_intensity_value, float representative_distance, vec3 origin, vec3 direction) {
	vec3 position = origin + direction * representative_distance;
	float elevation = cloud_solar_elevation(position, normalize(sun_direction));
	float daylight = smoothstep(-0.10, 0.20, elevation);
	vec3 solar_tint = sky_link_lighting ? cloud_solar_tint(elevation) : vec3(1.0);
	vec3 ambient_tint = sky_link_lighting ? mix(vec3(0.45, 0.5, 0.8), vec3(1.0), daylight) : vec3(1.0);
	return cloud_color.rgb * (sun_color.rgb * solar_tint * direct_intensity
		+ moon_color.rgb * lunar_intensity
		+ ambient_color.rgb * ambient_tint * ambient_intensity_value);
}

vec3 cloud_mie_shafts(vec2 masks, float distance_to_point, vec3 origin, vec3 direction) {
	if (!light_shafts_enabled || max(masks.x, masks.y) <= 0.0 || light_shaft_strength <= 0.0 || max(sun_intensity, moon_intensity) <= 0.0) {
		return vec3(0.0);
	}
	// 在远处才启用；近物体截断空气段，光束不覆盖邻近景物。
	float distant_gate = smoothstep(light_shaft_start, light_shaft_start * 2.0, distance_to_point);
	if (distant_gate <= 0.0 || atmosphere_density <= 0.0) {
		return vec3(0.0);
	}
	vec2 foreground_depth = cloud_atmosphere_depth(light_shaft_start, origin, direction);
	vec2 distant_depth = cloud_atmosphere_segment(light_shaft_start, distance_to_point, origin, direction);
	float view_transmittance = exp(-foreground_depth.x - foreground_depth.y);
	float total_depth = distant_depth.x + distant_depth.y;
	// Mie 入散射乘完整介质消光，避免长视线累积成不受衰减的白色覆盖。
	float scattering = distant_depth.y / max(total_depth, 0.000001) * (1.0 - exp(-total_depth));
	float alignment = clamp(dot(direction, normalize(sun_direction)), -1.0, 1.0);
	float phase = cloud_henyey_greenstein(alignment, 0.65) * (4.0 * PI);
	float elevation = cloud_solar_elevation(origin, normalize(sun_direction));
	float daylight = smoothstep(-0.04, 0.08, elevation);
	vec3 tint = sun_color.rgb * cloud_solar_tint(elevation);
	float lunar_phase = cloud_henyey_greenstein(clamp(dot(direction, normalize(moon_direction)), -1.0, 1.0), 0.65) * (4.0 * PI);
	vec3 sources = tint * sun_intensity * daylight * phase * masks.x
		+ moon_color.rgb * moon_intensity * lunar_phase * masks.y;
	return sources * scattering * view_transmittance * light_shaft_strength * distant_gate;
}
