// 按云类型插值四个高度端点：开始增密、完全增密、开始消散、完全消散。
// 三个权重在 [0, 1] 内总和为 1，类型 0.5 两侧的端点值连续。
vec4 cloud_height_profile(float cloud_type, vec4 stratus, vec4 stratocumulus, vec4 cumulus) {
	float type_value = clamp(cloud_type, 0.0, 1.0);
	float stratus_weight = 1.0 - clamp(type_value * 2.0, 0.0, 1.0);
	float stratocumulus_weight = 1.0 - abs(type_value - 0.5) * 2.0;
	float cumulus_weight = clamp(type_value * 2.0 - 1.0, 0.0, 1.0);
	return stratus * stratus_weight + stratocumulus * stratocumulus_weight + cumulus * cumulus_weight;
}

// PDF 第 28 页：两段线性 remap 相乘。每段先限制到 [0, 1]。
float cloud_height_density(float height_fraction, vec4 profile) {
	float rise = clamp((height_fraction - profile.x) / max(profile.y - profile.x, 0.00001), 0.0, 1.0);
	float fall = 1.0 - clamp((height_fraction - profile.z) / max(profile.w - profile.z, 0.00001), 0.0, 1.0);
	return rise * fall;
}
