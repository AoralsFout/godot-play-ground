// 固定的北极切平面原点；球心 = surface_origin - (0, radius, 0)。
// 不随相机移动，以免云图、阴影与地平线游移。
uniform vec3 planet_surface_origin = vec3(0.0);
uniform float planet_radius = 6371000.0;
uniform float cloud_bottom = 1500.0;
uniform float cloud_top = 4000.0;

vec3 cloud_radial_vector(vec3 position) {
	return position - planet_surface_origin + vec3(0.0, planet_radius, 0.0);
}

vec3 cloud_local_up(vec3 position) {
	vec3 radial = cloud_radial_vector(position);
	float radius = length(radial);
	return radius > 0.001 ? radial / radius : vec3(0.0, 1.0, 0.0);
}

float cloud_altitude(vec3 position) {
	vec3 local = position - planet_surface_origin;
	// 展开差平方，避免在 float 中直接做 length(radial) - 六百万米。
	return (dot(local, local) + 2.0 * planet_radius * local.y)
		/ max(length(cloud_radial_vector(position)) + planet_radius, 1.0);
}

float cloud_height_fraction(vec3 position) {
	return (cloud_altitude(position) - cloud_bottom) / max(cloud_top - cloud_bottom, 1.0);
}

// direction 必须归一化。稳定求根，避免近表面交点由两个大数相减产生。
vec2 cloud_sphere_interval(vec3 origin, vec3 direction, float altitude) {
	vec3 local = origin - planet_surface_origin;
	float b = dot(local, direction) + planet_radius * direction.y;
	float c = dot(local, local) + 2.0 * planet_radius * local.y
		- altitude * (2.0 * planet_radius + altitude);
	float discriminant = b * b - c;
	if (discriminant < 0.0) {
		return vec2(1.0, -1.0);
	}
	float root = sqrt(max(discriminant, 0.0));
	float q = -b - (b >= 0.0 ? root : -root);
	if (abs(q) < 0.0001) {
		return vec2(-b, -b);
	}
	float other = c / q;
	return vec2(min(q, other), max(q, other));
}

// 最近的星球遮挡距离；从表面朝外看不把 t=0 当作遮挡。
float cloud_planet_distance(vec3 origin, vec3 direction) {
	if (cloud_altitude(origin) < -0.1) {
		return 0.0;
	}
	vec2 planet = cloud_sphere_interval(origin, direction, 0.0);
	if (planet.y <= planet.x || planet.y <= 0.01) {
		return 1e20;
	}
	return max(planet.x, 0.0);
}

bool cloud_sun_visible(vec3 position, vec3 direction_to_sun) {
	return cloud_planet_distance(position, direction_to_sun) > 1e19;
}

// 外球减内球，可返回两段；无效段使用 (1,-1)，有效段始终靠前。
// max_length 同时用于视距、场景深度或太阳光线的有限范围。
vec4 intersect_cloud_shell(vec3 origin, vec3 direction, float max_length) {
	vec2 outer = cloud_sphere_interval(origin, direction, cloud_top);
	float entry = max(outer.x, 0.0);
	float exit_distance = min(outer.y, min(max_length, cloud_planet_distance(origin, direction)));
	vec4 miss = vec4(1.0, -1.0, 1.0, -1.0);
	if (outer.y <= outer.x || exit_distance <= entry) {
		return miss;
	}
	vec2 inner = cloud_sphere_interval(origin, direction, cloud_bottom);
	if (inner.y <= inner.x || inner.y <= entry || inner.x >= exit_distance) {
		return vec4(entry, exit_distance, 1.0, -1.0);
	}
	float near_end = min(exit_distance, inner.x);
	float far_start = max(entry, inner.y);
	bool near_valid = near_end > entry;
	bool far_valid = exit_distance > far_start;
	if (near_valid && far_valid) {
		return vec4(entry, near_end, far_start, exit_distance);
	}
	if (near_valid) {
		return vec4(entry, near_end, 1.0, -1.0);
	}
	if (far_valid) {
		return vec4(far_start, exit_distance, 1.0, -1.0);
	}
	return miss;
}

float cloud_shell_length(vec4 intervals) {
	return max(intervals.y - intervals.x, 0.0) + max(intervals.w - intervals.z, 0.0);
}

// 将连续的云内路程映射回射线距离，太阳/地面阴影不采样空腔。
float cloud_shell_ray_distance(vec4 intervals, float distance_in_cloud) {
	float first_length = max(intervals.y - intervals.x, 0.0);
	return distance_in_cloud < first_length || intervals.w <= intervals.z ? intervals.x + distance_in_cloud
		: intervals.z + distance_in_cloud - first_length;
}

vec3 cloud_tangent_offset(vec3 offset, vec3 up) {
	return offset - up * dot(offset, up);
}

// 高处的真实地平线低于局部水平线，不用 world_direction.y 粗暴剔除。
float cloud_horizon_cosine(vec3 position) {
	float altitude = max(cloud_altitude(position), 0.0);
	return -sqrt(altitude * (2.0 * planet_radius + altitude)) / (planet_radius + altitude);
}

float cloud_solar_elevation(vec3 position, vec3 direction_to_sun) {
	return dot(cloud_local_up(position), direction_to_sun) - cloud_horizon_cosine(position);
}

vec3 cloud_solar_tint(float elevation) {
	return mix(vec3(1.0, 0.32, 0.12), vec3(1.0), smoothstep(0.02, 0.35, elevation));
}
