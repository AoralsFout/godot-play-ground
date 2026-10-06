#include "res://shaders/clouds/cloud_density.gdshaderinc"

uniform bool ground_cloud_shadows = false;
uniform float ground_shadow_strength = 1.0;
uniform int ground_shadow_steps : hint_range(4, 32) = 12;
uniform vec3 cloud_ground_sun_direction = vec3(0.0, 1.0, 0.0);
uniform float cloud_ground_sun_intensity = 0.0;

float ground_sun_transmittance(vec3 world_position, vec3 direction_to_sun) {
	if (!ground_cloud_shadows || ground_shadow_strength <= 0.0 || density_multiplier <= 0.0
		|| extinction <= 0.0 || coverage_amount <= 0.0 || cloud_ground_sun_intensity <= 0.0) {
		return 1.0;
	}
	vec4 intervals = intersect_cloud_shell(world_position, direction_to_sun, 1e20);
	float path_length = cloud_shell_length(intervals);
	if (path_length <= 0.0) {
		return 1.0;
	}
	float step_length = path_length / float(ground_shadow_steps);
	float optical_depth = 0.0;
	for (int index = 0; index < 32; index++) {
		if (index >= ground_shadow_steps) {
			break;
		}
		float ray_distance = cloud_shell_ray_distance(intervals, (float(index) + 0.5) * step_length);
		vec3 position = world_position + direction_to_sun * ray_distance;
		// 与云内部光照共用低频密度，保留动画、砧状和一层侵蚀。
		float density = sample_cloud_density(position, 2) * density_multiplier;
		optical_depth += density * extinction * step_length;
		if (optical_depth >= 5.3) {
			break;
		}
	}
	float elevation = cloud_solar_elevation(world_position, direction_to_sun);
	float strength = ground_shadow_strength * smoothstep(0.01, 0.08, elevation);
	return mix(1.0, exp(-optical_depth), strength);
}

// 小地图不采样云影；主视图与海面倒影共享同一世界坐标密度。
float cloud_ground_visibility(vec3 position, uint camera_layers) {
    if ((camera_layers & 786432u) == 0u) { return 1.0; }
    return ground_sun_transmittance(position, normalize(cloud_ground_sun_direction));
}

// 云影只衰减太阳直射光；保留月光、点光和环境补光。
float cloud_ground_light_visibility(vec3 view_light, mat4 inverse_view, bool directional, float visibility) {
    vec3 world_light = normalize((inverse_view * vec4(view_light, 0.0)).xyz);
    return directional && dot(world_light, normalize(cloud_ground_sun_direction)) > 0.999 ? visibility : 1.0;
}
