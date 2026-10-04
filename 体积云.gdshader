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
// 由天空控制器传入太阳状态，不依赖光源排序或已被云衰减的 LIGHT0_ENERGY。
uniform vec3 sky_sun_direction = vec3(0.45, 0.46, 0.77);
uniform vec4 sun_color : source_color = vec4(1.0, 0.97, 0.90, 1.0);
uniform float sun_strength = 1.15;
uniform float sun_visibility = 1.0;
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform float twilight : hint_range(0.0, 1.0) = 0.0;
uniform float overcast : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sky_moon_direction = vec3(0.0, 0.6, -0.8);
uniform vec4 moon_color : source_color = vec4(0.76, 0.84, 1.0, 1.0);
uniform float moon_strength = 0.0;
uniform float moon_visibility = 0.0;
uniform float moon_angular_radius = 0.010472;

vec3 sun_direction() {
	return normalize(sky_sun_direction);
}

vec3 moon_radiance(vec3 direction) {
	if (moon_visibility <= 0.0001) {
		return vec3(0.0);
	}
	vec3 to_moon = normalize(sky_moon_direction);
	float alignment = dot(direction, to_moon);
	float radius = max(sin(moon_angular_radius), 0.001);
	vec3 reference_up = abs(to_moon.y) > 0.98 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(reference_up, to_moon));
	vec3 up = cross(to_moon, right);
	vec2 surface = vec2(dot(direction, right), dot(direction, up)) / radius;
	float radial = length(surface);
	float disk = (1.0 - smoothstep(0.94, 1.02, radial)) * step(0.0, alignment);
	// 程序化月海、陨石坑与柔和球面边缘，无需额外纹理。
	float maria = smoothstep(-0.3, 0.5, sin(surface.x * 5.3 + sin(surface.y * 4.1)) * cos(surface.y * 6.7));
	float crater = exp(-dot(surface - vec2(-0.30, 0.25), surface - vec2(-0.30, 0.25)) * 35.0);
	crater += exp(-dot(surface - vec2(0.38, -0.20), surface - vec2(0.38, -0.20)) * 60.0);
	float relief = (0.84 - maria * 0.20 - crater * 0.16) * mix(0.65, 1.0, sqrt(max(1.0 - radial * radial, 0.0)));
	float halo = pow(max(alignment, 0.0), 512.0) * 0.025 + pow(max(alignment, 0.0), 64.0) * 0.008;
	return moon_color.rgb * (disk * relief * 2.0 + halo * (1.0 - overcast))
		* moon_visibility * smoothstep(-0.005, 0.005, direction.y);
}

vec3 clear_sky(vec3 direction) {
	float elevation = pow(clamp(direction.y, 0.0, 1.0), 0.45);
	vec3 sky_color = mix(horizon_color.rgb, zenith_color.rgb, elevation);
	float sun_dot = clamp(dot(direction, sun_direction()), 0.0, 1.0);
	vec3 sunlight = sun_color.rgb;
	float haze = exp(-max(direction.y, 0.0) * 7.0);
	float sunward = pow(max(dot(normalize(vec3(direction.x, 0.001, direction.z)),
		normalize(vec3(sun_direction().x, 0.001, sun_direction().z))), 0.0), 2.0);
	// 地平线附近的橙红散射随太阳方向移动，背日方向保留蓝紫暮光。
	vec3 warm_glow = mix(vec3(1.0, 0.25, 0.08), vec3(1.0, 0.54, 0.22), daylight);
	sky_color += warm_glow * twilight * haze * sunward * (1.0 - overcast) * 0.45;
	sky_color += vec3(0.20, 0.07, 0.18) * twilight * haze * (1.0 - sunward) * (1.0 - overcast) * 0.35;
	sky_color += sunlight * pow(sun_dot, 24.0) * 0.16 * sun_visibility * (1.0 - overcast * 0.65);
	sky_color += sunlight * pow(sun_dot, 256.0) * 0.35 * sun_visibility;
	// 以完整分辨率计算边缘清晰的太阳圆盘。
	sky_color += sunlight * smoothstep(0.99994, 0.99998, sun_dot) * 5.0 * sun_visibility
		* smoothstep(-0.012, 0.003, direction.y);
	sky_color += moon_radiance(direction);
	// 固定在天球上的稀疏星点；夜间显现，云层合成时会遮挡它们。
	vec3 star_cell = floor(direction * 650.0);
	float star_hash = fract(sin(dot(star_cell, vec3(127.1, 311.7, 74.7))) * 43758.5453);
	float star_shape = 1.0 - smoothstep(0.08, 0.28, length(fract(direction * 650.0) - vec3(0.5)));
	float night = 1.0 - smoothstep(-0.23, -0.08, sun_direction().y);
	sky_color += vec3(0.65, 0.76, 1.0) * step(0.998, star_hash) * star_shape
		* night * smoothstep(0.0, 0.18, direction.y) * (1.0 - overcast) * 1.5;
	// 地平线下平滑融入夜色，避免太阳在地下照亮反射立方体。
	sky_color *= mix(0.35, 1.0, smoothstep(-0.30, 0.0, direction.y));
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
	vec3 to_moon = normalize(sky_moon_direction);
	float forward_scatter = pow(max(dot(direction, to_sun), 0.0), 12.0);
	float sun_energy = clamp(sun_strength, 0.0, 2.0);
	for (int step = 0; step < 72; step++) {
		if (step >= ray_steps || transmittance < 0.015) {
			break;
		}
		vec3 position = origin + direction * distance;
		float density = density_at(position);
		if (density > 0.00001) {
			float illumination = sunlight_transmittance(position, to_sun);
			float opacity = 1.0 - exp(-density * stride);
			// 太阳贴近地平线时照亮云的下缘；落下后保留短暂的晚霞余辉。
			float height = clamp((position.y - cloud_base) / cloud_thickness, 0.0, 1.0);
			float underglow = twilight * (1.0 - smoothstep(0.1, 0.7, height));
			float direct = clamp(illumination * (sun_energy * 0.75 + twilight * 0.65), 0.0, 1.0);
			vec3 lighting = mix(cloud_shadow_color.rgb, cloud_lit_color.rgb, direct);
			lighting += cloud_lit_color.rgb * underglow * illumination * (1.0 - overcast) * 0.35;
			lighting += cloud_lit_color.rgb * illumination * forward_scatter * 0.28 * sun_visibility;
			if (moon_strength > 0.001) {
				float lunar_illumination = sunlight_transmittance(position, to_moon);
				float lunar_scatter = pow(max(dot(direction, to_moon), 0.0), 16.0);
				lighting += moon_color.rgb * moon_strength * (0.025 + lunar_illumination * (0.22 + lunar_scatter * 0.10));
			}
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
