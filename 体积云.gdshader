shader_type sky;
render_mode use_half_res_pass, disable_fog;

// 以半分辨率对世界空间中的云层进行光线步进，再叠加到天空上。
uniform sampler3D cloud_noise : repeat_enable, filter_linear;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.56;
uniform float cloud_density : hint_range(0.0, 3.0) = 1.1;
uniform float cloud_base : hint_range(20.0, 2000.0) = 180.0;
uniform float cloud_thickness : hint_range(20.0, 1000.0) = 160.0;
uniform float cloud_scale : hint_range(100.0, 3000.0) = 700.0;
uniform vec2 wind_velocity = vec2(6.0, 2.0);
uniform float cloud_time = 0.0;
uniform int ray_steps : hint_range(24, 72) = 48;
uniform float max_distance = 9000.0;
uniform vec4 zenith_color : source_color = vec4(0.18, 0.43, 0.78, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.68, 0.82, 0.94, 1.0);
uniform vec4 cloud_lit_color : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform vec4 cloud_shadow_color : source_color = vec4(0.34, 0.42, 0.55, 1.0);

vec3 sun_direction() {
	return LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : normalize(vec3(0.45, 0.46, 0.77));
}

vec3 clear_sky(vec3 direction) {
	float elevation = pow(clamp(direction.y, 0.0, 1.0), 0.45);
	vec3 sky_color = mix(horizon_color.rgb, zenith_color.rgb, elevation);
	float sun_dot = clamp(dot(direction, sun_direction()), 0.0, 1.0);
	vec3 sunlight = LIGHT0_ENABLED ? LIGHT0_COLOR : vec3(1.0, 0.96, 0.88);
	sky_color += sunlight * pow(sun_dot, 32.0) * 0.12;
	// 以完整分辨率计算边缘清晰的太阳圆盘。
	sky_color += sunlight * smoothstep(0.99994, 0.99998, sun_dot) * 2.0;
	return sky_color;
}

float density_at(vec3 position) {
	float height = (position.y - cloud_base) / cloud_thickness;
	if (height <= 0.0 || height >= 1.0) {
		return 0.0;
	}
	vec3 uv = (position - vec3(wind_velocity.x, 0.0, wind_velocity.y) * cloud_time) / cloud_scale;
	float broad = textureLod(cloud_noise, uv, 0.0).r;
	float billows = textureLod(cloud_noise, uv * 2.73 + vec3(0.31, 0.17, 0.53), 0.0).r;
	float detail = textureLod(cloud_noise, uv * 8.1 + vec3(0.72, 0.43, 0.19), 0.0).r;
	float shape = broad * 0.72 + billows * 0.28;
	// 平坦柔和的云底与侵蚀状的上部边缘共同塑造积云的体积感。
	float height_envelope = smoothstep(0.0, 0.12, height) * (1.0 - smoothstep(0.40, 1.0, height));
	float threshold = 1.0 - cloud_coverage;
	float body = max(shape - threshold - (1.0 - height_envelope) * 0.28, 0.0);
	float erosion = (1.0 - detail) * 0.09;
	return max(body - erosion, 0.0) * height_envelope * cloud_density * 0.085;
}

float sunlight_transmittance(vec3 position, vec3 to_sun) {
	float optical_depth = 0.0;
	float stride = cloud_thickness * 0.16;
	// 逐渐增大的采样间隔同时覆盖附近翻涌的云团和上方云层。
	for (int light_step = 0; light_step < 5; light_step++) {
		position += to_sun * stride;
		optical_depth += density_at(position) * stride;
		stride *= 1.45;
	}
	// 第二项近似表示进入阴影内部的多次散射。
	return exp(-optical_depth) * 0.82 + exp(-optical_depth * 0.25) * 0.18;
}

vec4 march_clouds(vec3 origin, vec3 direction, vec2 pixel_uv) {
	if (cloud_coverage <= 0.0 || cloud_density <= 0.0 || abs(direction.y) < 0.0001) {
		return vec4(0.0);
	}
	float lower = (cloud_base - origin.y) / direction.y;
	float upper = (cloud_base + cloud_thickness - origin.y) / direction.y;
	float start = max(min(lower, upper), 0.0);
	float end = min(max(lower, upper), max_distance);
	if (end <= start) {
		return vec4(0.0);
	}
	float stride = (end - start) / float(ray_steps);
	// 稳定的逐像素抖动可减少条带，同时避免随时间闪烁。
	float jitter = fract(sin(dot(pixel_uv, vec2(127.1, 311.7))) * 43758.5453);
	float distance = start + stride * mix(0.3, 0.7, jitter);
	float transmittance = 1.0;
	vec3 scattered = vec3(0.0);
	vec3 to_sun = sun_direction();
	float forward_scatter = pow(max(dot(direction, to_sun), 0.0), 12.0);
	vec3 sunlight = LIGHT0_ENABLED ? LIGHT0_COLOR : vec3(1.0);
	float sun_energy = LIGHT0_ENABLED ? clamp(LIGHT0_ENERGY, 0.0, 2.0) : 1.0;
	for (int step = 0; step < 72; step++) {
		if (step >= ray_steps || transmittance < 0.015) {
			break;
		}
		vec3 position = origin + direction * distance;
		float density = density_at(position);
		if (density > 0.00001) {
			float illumination = sunlight_transmittance(position, to_sun);
			float opacity = 1.0 - exp(-density * stride);
			vec3 lighting = mix(cloud_shadow_color.rgb, cloud_lit_color.rgb * sunlight,
				clamp(illumination * (0.65 + sun_energy * 0.5), 0.0, 1.0));
			lighting += cloud_lit_color.rgb * illumination * forward_scatter * 0.28;
			// 在地平线附近将远处云层的颜色逐渐融入大气。
			lighting = mix(lighting, horizon_color.rgb, 1.0 - exp(-distance * 0.00018));
			scattered += transmittance * opacity * lighting;
			transmittance *= 1.0 - opacity;
		}
		distance += stride;
	}
	return vec4(scattered, 1.0 - transmittance);
}

void sky() {
	if (AT_CUBEMAP_PASS) {
		// 反射立方体的六个面不对移动云层进行光线步进。
		COLOR = clear_sky(EYEDIR);
	} else if (AT_HALF_RES_PASS) {
		vec4 cloud = march_clouds(POSITION, EYEDIR, SCREEN_UV);
		COLOR = cloud.rgb;
		ALPHA = cloud.a;
	} else {
		// 云层的 RGB 在积分过程中已预乘不透明度。
		COLOR = clear_sky(EYEDIR) * (1.0 - HALF_RES_COLOR.a) + HALF_RES_COLOR.rgb;
	}
}
