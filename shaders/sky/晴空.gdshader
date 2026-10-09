// 根据天空控制器传入的日月状态绘制晴空和天体。
// 连续混合天顶、地平线及晨昏颜色，不依赖方向光的排序。

shader_type sky;
render_mode disable_fog;

// 晴空天顶颜色；改变高仰角处的天空渐变。
uniform vec4 zenith_color : source_color = vec4(0.18, 0.43, 0.78, 1.0);
// 晴空地平线颜色；改变低仰角天空及晨昏过渡。
uniform vec4 horizon_color : source_color = vec4(0.68, 0.82, 0.94, 1.0);
// 由天空控制器传入太阳状态，不依赖光源排序。
// 天空中指向太阳的世界单位向量；由天空控制器同步以定位太阳和辉光。
uniform vec3 sky_sun_direction = vec3(0.45, 0.46, 0.77);
// 太阳直射颜色；由天空同步，最终与云光强相乘。
uniform vec4 sun_color : source_color = vec4(1.0, 0.97, 0.90, 1.0);
// 天空太阳可见权重（0 至 1）；控制太阳圆盘与周边辉光。
uniform float sun_visibility = 1.0;
// 日间权重（0 至 1）；影响星空和白天空的混合。
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
// 晨昏权重（0 至 1）；影响日出日落的暖色分布。
uniform float twilight : hint_range(0.0, 1.0) = 0.0;
// 天空中指向月亮的世界单位向量；决定独立月盘的方位和高度。
uniform vec3 sky_moon_direction = vec3(0.0, 0.6, -0.8);
// 月光直射颜色；天空与云共用，影响夜间云受光色调。
uniform vec4 moon_color : source_color = vec4(0.76, 0.84, 1.0, 1.0);
// 天空月亮可见权重（0 至 1）；由开关、高度和昼夜状态共同决定。
uniform float moon_visibility = 0.0;
// 月盘角半径（弧度）；控制器把完整角直径换算后传入，影响天空中的月盘大小。
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
	return moon_color.rgb * (disk * relief * 2.0 + halo)
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
	sky_color += warm_glow * twilight * haze * sunward * 0.45;
	sky_color += vec3(0.20, 0.07, 0.18) * twilight * haze * (1.0 - sunward) * 0.35;
	sky_color += sunlight * pow(sun_dot, 24.0) * 0.16 * sun_visibility;
	sky_color += sunlight * pow(sun_dot, 256.0) * 0.35 * sun_visibility;
	// 以完整分辨率计算边缘清晰的太阳圆盘。
	sky_color += sunlight * smoothstep(0.99994, 0.99998, sun_dot) * 5.0 * sun_visibility
		* smoothstep(-0.012, 0.003, direction.y);
	sky_color += moon_radiance(direction);
	// 固定在天球上的稀疏星点，夜间显现。
	vec3 star_cell = floor(direction * 650.0);
	float star_hash = fract(sin(dot(star_cell, vec3(127.1, 311.7, 74.7))) * 43758.5453);
	float star_shape = 1.0 - smoothstep(0.08, 0.28, length(fract(direction * 650.0) - vec3(0.5)));
	float night = 1.0 - smoothstep(-0.23, -0.08, sun_direction().y);
	sky_color += vec3(0.65, 0.76, 1.0) * step(0.998, star_hash) * star_shape
		* night * smoothstep(0.0, 0.18, direction.y) * 1.5;
	// 地平线下平滑融入夜色，避免太阳在地下照亮反射立方体。
	sky_color *= mix(0.35, 1.0, smoothstep(-0.30, 0.0, direction.y));
	return sky_color;
}

void sky() {
	COLOR = clear_sky(EYEDIR);
}
