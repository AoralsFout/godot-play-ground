// 提供云的方向散射、银边、多重散射和入散射概率函数。
// 太阳与月光复用相同模型，最终合成时分别应用颜色和能量。

// Nubis PDF 75–93：方向散射、双指数衰减、入散射概率。
// 增强散射模型开关；开启使用方向散射、银边、多重散射和入散射近似。
uniform bool nubis_lighting = true;
// 散射相函数偏心率；正值增强朝光源的前向散射，负值增强背向散射。
uniform float phase_eccentricity : hint_range(-0.95, 0.95) = 0.6;
// 云边银色高光强度；越大逆光银边越亮。
uniform float silver_intensity : hint_range(0.0, 2.0) = 0.5;
// 银边散射展宽参数；控制高光角分布，应结合散射偏心率和强度调节。
uniform float silver_spread : hint_range(0.01, 0.98) = 0.2;
// 多重散射补光强度；越大厚云内部越亮，朝光源方向会按角度减弱。
uniform float multi_scatter_strength : hint_range(0.0, 1.0) = 1.0;
// 入散射概率贡献；影响云内部和边缘的明暗塑形。
uniform float in_scatter_strength : hint_range(0.0, 1.0) = 1.0;

float cloud_henyey_greenstein(float cos_angle, float eccentricity) {
	float g = eccentricity;
	float denominator = max(1.0 + g * g - 2.0 * g * cos_angle, 0.000001);
	return (1.0 - g * g) / (4.0 * PI * pow(denominator, 1.5));
}

float cloud_directional_scattering(float cos_angle) {
	float base_phase = cloud_henyey_greenstein(cos_angle, phase_eccentricity);
	float silver_phase = silver_intensity * cloud_henyey_greenstein(cos_angle, 0.99 - silver_spread);
	// 用各向同性 HG=1/(4*pi) 作为原预览太阳强度的单位，不截断 HDR 峰值。
	return max(base_phase, silver_phase) * (4.0 * PI);
}

// 朝太阳看（cos=1）减弱多重散射补光和暗边，远离太阳时完整应用。
// PDF 描述角度渐变但未给出区间；这里在 cos=0..1 平滑过渡。
float cloud_away_from_sun(float cos_angle) {
	return 1.0 - smoothstep(0.0, 1.0, cos_angle);
}

float cloud_light_attenuation(float optical_depth, float away_from_sun) {
	float direct = exp(-optical_depth);
	if (!nubis_lighting || multi_scatter_strength <= 0.0) {
		return direct;
	}
	float scattered = 0.7 * exp(-optical_depth * 0.25);
	return mix(direct, max(direct, scattered), multi_scatter_strength * away_from_sun);
}

float cloud_in_scatter_probability(float lodded_density, float height_fraction, float away_from_sun) {
	// 限制梯度输入，避免负底数的分数次幂；光照结果不限制到 [0,1]。
	float depth_exponent = mix(0.5, 2.0, cloud_fit_unit(height_fraction, 0.3, 0.85));
	float depth_probability = 0.05 + pow(lodded_density, depth_exponent);
	float vertical_gradient = mix(0.1, 1.0, cloud_fit_unit(height_fraction, 0.07, 0.14));
	float vertical_probability = pow(vertical_gradient, 0.8);
	return mix(1.0, depth_probability * vertical_probability, in_scatter_strength * away_from_sun);
}
