// 此处的整数哈希与插值须与草地分布.gd 保持同步。
uniform int distribution_seed = 7319;
uniform float grass_patch_scale = 0.055;
uniform float grass_coverage = 0.58;

float grass_hash(ivec2 cell) {
	uint value = uint(cell.x) * 374761393u + uint(cell.y) * 668265263u + uint(distribution_seed) * 1274126177u;
	value = (value ^ (value >> 13u)) * 1274126177u;
	value = value ^ (value >> 16u);
	return float(value & 65535u) / 65535.0;
}

float grass_noise(vec2 point) {
	ivec2 cell = ivec2(floor(point));
	vec2 weight = fract(point);
	weight = weight * weight * (3.0 - 2.0 * weight);
	return mix(mix(grass_hash(cell), grass_hash(cell + ivec2(1, 0)), weight.x),
		mix(grass_hash(cell + ivec2(0, 1)), grass_hash(cell + ivec2(1, 1)), weight.x), weight.y);
}

float grass_patch_density(vec2 world_xz) {
	vec2 point = world_xz * grass_patch_scale;
	float value = grass_noise(point) * 0.75 + grass_noise(point * 2.17 + vec2(31.7, -19.2)) * 0.25;
	return smoothstep(1.0 - grass_coverage, 1.0 - grass_coverage + 0.16, value);
}
