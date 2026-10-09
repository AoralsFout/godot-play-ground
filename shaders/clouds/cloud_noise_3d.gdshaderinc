// 采样周期三维噪声并组合分形基础形状和细节侵蚀。
// 真实逐级缩小纹理按世界采样足迹过滤，保持不同步进预算下的云形稳定。

#include "res://shaders/clouds/cloud_math.gdshaderinc"

// 数值纹理，不进行 sRGB 转换。基础噪声由 FastNoiseLite 在三维生成。
// 周期三维柏林数值纹理；提供基础云形，逐级缩小过滤用于降低远景闪烁。
uniform sampler3D perlin_texture : repeat_enable, filter_linear_mipmap;
// 周期三维沃利数值纹理；提供基础形状组合和高频侵蚀。
uniform sampler3D worley_texture : repeat_enable, filter_linear_mipmap;
// 三维噪声纹理可用标记；控制器完成上传后开启，未就绪时使用回退密度。
uniform bool noise_ready = false;
// 0 保留仅云图的旧场景；1/2 统一使用一种三维噪声；3 按 R/G 分别计算。
// 密度噪声模式；0 仅云图，1 柏林，2 柏林与沃利组合，3 按红绿通道分别使用两类噪声。
uniform int density_mode : hint_enum("Map only", "Perlin", "Perlin-Worley", "R Perlin / G Perlin-Worley") = 0;
// 三维基础噪声周期（米）；越大云团尺度越大，改变后云内光照和地面云影一起变化。
uniform float noise_repeat_distance : hint_range(200.0, 10000.0) = 2000.0;
// 基础分形噪声层数；越大增加高频形状和采样成本。
uniform int noise_octaves : hint_range(1, 6) = 4;
// 每层分形噪声的振幅倍率；越大高频细节越明显，使用归一化控制总体对比度。
uniform float noise_gain : hint_range(0.0, 1.0) = 0.5;
// 相邻分形噪声层的频率倍率；1 重复同频率，越大细节尺度分离越明显。
uniform int noise_lacunarity : hint_range(1, 4) = 2;
// 控制器在参数变化时预计算；独立使用此 include 时，负值走原始计算。
// 基础分形噪声归一化系数；由控制器预计算，负值在着色器内按层数重新计算。
uniform float noise_normalization = -1.0;
// 细节侵蚀强度；越大云边和云内孔洞越多，只减少密度。
uniform float erosion_strength : hint_range(0.0, 1.0) = 0.5;
// 侵蚀噪声相对基础噪声的频率倍率；越大侵蚀细节越小。
uniform float erosion_frequency : hint_range(1.0, 16.0) = 4.0;

// 当前实时组合噪声的前两层负责大型，高频层负责演变。
const int CLOUD_SHAPE_OCTAVES = 2;

float cloud_perlin_normalization() {
	float amplitude = 1.0;
	float weight = 0.0;
	float squared_weight = 0.0;
	for (int octave = 0; octave < 6; octave++) {
		if (octave >= noise_octaves) { break; }
		weight += amplitude;
		squared_weight += amplitude * amplitude;
		amplitude *= noise_gain;
	}
	return noise_lacunarity == 1 ? weight : sqrt(squared_weight);
}

// 返回未截断的基础 mip；负值保留足迹信息，高频频段再加 log2(frequency)。
float cloud_noise_mip_for_footprint(float footprint) {
	float resolution = float(max(textureSize(perlin_texture, 0).x, 1));
	return log2(max(footprint * resolution / max(noise_repeat_distance, 1.0), 0.000001));
}

float cloud_noise_band_mip(float base_mip, float frequency) {
	float max_mip = log2(float(max(textureSize(perlin_texture, 0).x, 1)));
	return clamp(base_mip + log2(max(frequency, 1.0)), 0.0, max_mip);
}

// 少采样的 octave 仍使用完整 fBm 的归一化，避免 LOD 切换改变对比度。
// upper_bound 用未采样 octave 的最大可能值补齐，只用于找云，不参与积分。
float cloud_perlin_sample(vec3 shape_uv, vec3 detail_uv, int detail_octaves, bool upper_bound, float detail_factor, float base_mip) {
	float frequency = 1.0;
	float amplitude = 1.0;
	float total = 0.0;
	float visible_bands = mix(1.0, float(noise_octaves), detail_factor);
	for (int octave = 0; octave < 6; octave++) {
		if (octave >= noise_octaves) {
			break;
		}
		// normalize=false 使用固定 [-1,1] -> [0,1] 编码。
		float centered = upper_bound ? 0.5 : 0.0;
		float band_weight = 1.0 - smoothstep(visible_bands - 1.0, visible_bands, float(octave));
		if (octave == 0) {
			band_weight = 1.0;
		}
		if (octave < detail_octaves && (upper_bound || band_weight > 0.0)) {
			float mip = cloud_noise_band_mip(base_mip, frequency);
			// lacunarity=1 时所有层都是同一大型频率，不能把重复层当动态细节。
			vec3 octave_uv = (octave < CLOUD_SHAPE_OCTAVES || noise_lacunarity == 1) ? shape_uv : detail_uv;
			centered = textureLod(perlin_texture, octave_uv * frequency, mip).r - 0.5;
			if (!upper_bound) {
				centered *= band_weight;
			}
		}
		total += centered * amplitude;
		amplitude *= noise_gain;
		frequency *= float(noise_lacunarity);
	}
	float normalization = noise_normalization > 0.0 ? noise_normalization : cloud_perlin_normalization();
	return clamp(0.5 + total / max(normalization, 0.00001), 0.0, 1.0);
}

float cloud_perlin_fbm(vec3 noise_uv) {
	return cloud_perlin_sample(noise_uv, noise_uv, noise_octaves, false, 1.0, -16.0);
}

float cloud_worley_distance_lod(vec3 noise_uv, float mip) {
	// FastNoiseLite 的 Euclidean/Distance 输出为 F1-1。
	// 固定灰度编码后的 texel = F1/2；恢复距离并除以 sqrt(3)。
	return clamp(textureLod(worley_texture, noise_uv, mip).r * 1.15470054, 0.0, 1.0);
}

float cloud_worley_distance(vec3 noise_uv) {
	return cloud_worley_distance_lod(noise_uv, 0.0);
}

float cloud_perlin_worley_detail(vec3 shape_uv, vec3 detail_uv, float perlin, int detail_bands, bool upper_bound, float detail_factor, float base_mip) {
	float d2 = cloud_worley_distance_lod(shape_uv * 2.0, cloud_noise_band_mip(base_mip, 2.0));
	float d4 = detail_bands >= 2 && (upper_bound || detail_factor > 0.0)
		? cloud_worley_distance_lod(shape_uv * 4.0, cloud_noise_band_mip(base_mip, 4.0)) : 0.5;
	d4 = upper_bound ? min(d4, 0.5) : mix(0.5, d4, detail_factor);
	// 高频在当前 HDA 中还会扩张云形。上界必须取最大扩张，不能直接删掉。
	float d17 = upper_bound ? 0.0 : 0.5;
	float d33 = d17;
	if (!upper_bound && detail_bands >= 4 && detail_factor > 0.0) {
		d17 = mix(0.5, cloud_worley_distance_lod(detail_uv * 17.0, cloud_noise_band_mip(base_mip, 17.0)), detail_factor);
		d33 = mix(0.5, cloud_worley_distance_lod(detail_uv * 33.0, cloud_noise_band_mip(base_mip, 33.0)), detail_factor);
	}
	// 复用官方 HDA 的 fit4 -> fit5 -> fit1 -> fit3 -> valid_range 链。
	float value = cloud_fit_unit(perlin, -0.1 * (1.0 - d17), 1.0);
	value = cloud_fit_unit(value, -0.1 * (1.0 - d33), 1.0);
	value = cloud_fit_unit(value, 0.5 * d2, 1.0);
	value = cloud_fit_unit(value, 0.2 * d4, 1.0);
	return cloud_fit_unit(value, -0.1, 1.1);
}

float cloud_perlin_worley(vec3 noise_uv, float perlin) {
	return cloud_perlin_worley_detail(noise_uv, noise_uv, perlin, 4, false, 1.0, -16.0);
}

float cloud_erosion_threshold(vec3 noise_uv, int quality, float detail_factor, float base_mip, float height_fraction) {
	// 侵蚀只减少密度；找云上界可完全跳过，避免粗采样漏掉潜在云区。
	if (erosion_strength <= 0.0 || quality == 0) {
		return 0.0;
	}
	if (detail_factor <= 0.0) {
		return erosion_strength * 0.5;
	}
	// 复用周期三维 Worley，独立提高频率并偏移，避免和基础形状重合。
	vec3 detail_uv = noise_uv * erosion_frequency + vec3(0.19, 0.37, 0.73);
	float d1 = cloud_worley_distance_lod(detail_uv, cloud_noise_band_mip(base_mip, erosion_frequency));
	float high_frequency_noise;
	if (quality >= 3) {
		float d2 = cloud_worley_distance_lod(detail_uv * 2.0, cloud_noise_band_mip(base_mip, erosion_frequency * 2.0));
		float d4 = cloud_worley_distance_lod(detail_uv * 4.0, cloud_noise_band_mip(base_mip, erosion_frequency * 4.0));
		high_frequency_noise = d1 * 0.625 + d2 * 0.25 + d4 * 0.125;
	} else {
		// 低频太阳采样只保留一层，其余细节用中值近似，限制阴影开销。
		high_frequency_noise = d1 * 0.625 + 0.5 * 0.375;
	}
	// imp.md：底部使用原噪声，在相对高度 0..0.1 过渡到反相噪声。
	// 平均值 0.5 在反相前后不变，沿用远景淡出和真实 mip 过滤。
	float height_noise = mix(high_frequency_noise, 1.0 - high_frequency_noise, clamp(height_fraction * 10.0, 0.0, 1.0));
	return clamp(mix(0.5, height_noise, detail_factor) * erosion_strength, 0.0, 1.0);
}

float cloud_covered_density(float noise_with_height, float coverage) {
	// PDF 40–44 页的覆盖度侵蚀：C 越大，阈值 1-C 越低，云越膨胀。
	// 只在 C=0 时清空，取消硬门限与额外的 C 倍率，保留 remap 的核心密度。
	if (coverage <= 0.0) {
		return 0.0;
	}
	return cloud_fit_unit(noise_with_height, 1.0 - coverage, 1.0);
}
