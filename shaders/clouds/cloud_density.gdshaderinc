// 组合云图覆盖度、类型、高度剖面和三维噪声，查询世界坐标云密度。
// 主视图、倒影、云内光照与地面云影复用此密度函数。

#include "res://shaders/clouds/cloud_shell.gdshaderinc"
#include "res://shaders/clouds/cloud_height_gradient.gdshaderinc"
#include "res://shaders/clouds/cloud_noise_3d.gdshaderinc"

// RGB 是覆盖度/类型数据，不添加 source_color，保留通道的数值。
// 云覆盖和类型数据纹理；红绿通道参与覆盖，蓝通道影响类型，应使用数值纹理而非颜色贴图。
uniform sampler2D cloud_map : hint_default_black, repeat_disable, filter_linear;
// 北半球局部云图，沿径向投到星球表面再取 XZ；区域之外不重复纹理。
// 云图中心的世界 X/Z 坐标（米）；改变大型云形覆盖区域。
uniform vec2 cloud_map_center = vec2(0.0);
// 云图覆盖的边长（米）；越大同一图案越宽，边缘之外不重复采样。
uniform float cloud_map_extent = 600000.0;
// 红绿覆盖通道的混合比例；0 使用红通道，1 使用绿通道，影响大型云形分布。
uniform float coverage_blend : hint_range(0.0, 1.0) = 0.5;
// 0 清空，0.5 使用原云图，1 将 R/G 覆盖度推到最大。
// 整体云量；0 清空，0.5 保留原图，1 最大化红绿覆盖，云图范围外仍保持无云。
uniform float coverage_amount : hint_range(0.0, 1.0) = 0.5;
// 云类型偏置；改变高度剖面的类型混合，不平移云图或噪声。
uniform float cloud_type_bias : hint_range(-1.0, 1.0) = 0.0;
// 云密度倍率；越大云越厚重，0 不产生密度。
uniform float density_multiplier : hint_range(0.0, 10.0) = 1.0;
// PDF 45 的固定大型 / 动态细节目标：时间位移仅用于高频和侵蚀。
// 动态噪声世界位移（米）；由控制器按风速与可暂停时间累积，仅作用于动态细节。
uniform vec3 noise_motion_offset = vec3(0.0);
// 世界空间水平风向单位向量；决定随高度的云形偏移方向。
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.0);
// 从云底到云顶的风向偏移幅度（米）；底部为 0，高处逐渐增大。
uniform float wind_height_skew : hint_range(0.0, 1500.0) = 500.0;
// 砧状云偏置强度；越大顶部扩张和偏移越明显。
uniform float anvil_bias : hint_range(0.0, 1.0) = 0.0;
// 顶部额外的风向变化，与整层风的时间位移分开。
// 砧状云顶部偏移的世界方向单位向量；配合顶部偏移距离使用。
uniform vec3 anvil_skew_direction = vec3(0.70710678, 0.0, -0.70710678);
// 砧状云顶部额外偏移距离（米）；影响高层形状，不等同于随时间位移。
uniform float anvil_skew_distance : hint_range(0.0, 3000.0) = 1000.0;
// 层云四端点高度剖面（0 至 1）；依次为增密开始、增密结束、消散开始和消散结束，应递增。
uniform vec4 stratus_profile = vec4(0.0, 0.1, 0.2, 0.3);
// 层积云四端点高度剖面（0 至 1）；决定密度在云底和云顶的过渡，端点应递增。
uniform vec4 stratocumulus_profile = vec4(0.0, 0.2, 0.48, 0.625);
// 积云四端点高度剖面（0 至 1）；决定较厚积云的竖直密度分布，端点应递增。
uniform vec4 cumulus_profile = vec4(0.0, 0.1625, 0.88, 0.98);
// 云消光系数（每米）；越大透光越少，需结合密度与云层厚度调节。
uniform float extinction : hint_range(0.0, 0.02) = 0.00192;

float cloud_shape_density(float base_noise, float height_density, float coverage, float erosion_threshold) {
	// 先高度缩放和 coverage 重映射形成大型，再侵蚀最终密度。
	float covered_density = cloud_covered_density(base_noise * height_density, coverage);
	return cloud_fit_unit(covered_density, erosion_threshold, 1.0);
}

// quality: -1 入散射的低频形状（无高频侵蚀）；0 找云上界；1/2 光照；3 完整密度。
// detail_factor 在远景连续降低高频权重，quality 继续限制每次查询成本。
// base_mip 由世界采样足迹决定；erosion_weight 用于连续切换廉价光照查询。
float sample_cloud_density_lod(vec3 world_position, int quality, float detail_factor, float base_mip, float erosion_weight) {
	float height_fraction = cloud_height_fraction(world_position);
	vec3 up = cloud_local_up(world_position);
	if (height_fraction < 0.0 || height_fraction > 1.0 || up.y <= 0.0) {
		return 0.0;
	}
	vec2 surface_position = up.xz * planet_radius;
	vec2 map_uv = (surface_position - cloud_map_center) / max(cloud_map_extent, 1.0) + vec2(0.5);
	if (any(lessThan(map_uv, vec2(0.0))) || any(greaterThan(map_uv, vec2(1.0)))) {
		return 0.0;
	}
	vec3 map_data = textureLod(cloud_map, map_uv, 0.0).rgb;
	// 砧状云是积云的变体，B=0/0.5 的层云、层积云不受影响。
	float local_cloud_type = clamp(map_data.b + cloud_type_bias, 0.0, 1.0);
	float local_anvil_bias = density_mode == 0 ? 0.0 : anvil_bias * clamp(local_cloud_type * 2.0 - 1.0, 0.0, 1.0);
	// 调节覆盖梯度，再分别做密度 remap；不改变 UV、噪声位置或蓝通道。
	vec2 local_coverage = clamp(map_data.rg + vec2(coverage_amount * 2.0 - 1.0), vec2(0.0), vec2(1.0));
	if (local_anvil_bias > 0.0) {
		// PDF 46–50：线性 remap，0.7 以下指数 >1 收窄，0.8 以上继续展开。
		float anvil_exponent = 1.0 + (height_fraction - 0.7) / 0.1 * (mix(1.0, 0.5, local_anvil_bias) - 1.0);
		// 保留无覆盖区域；避免指数 <=0 时 pow(0, exponent) 的未定义结果。
		local_coverage.r = local_coverage.r > 0.0 ? clamp(pow(local_coverage.r, anvil_exponent), 0.0, 1.0) : 0.0;
		local_coverage.g = local_coverage.g > 0.0 ? clamp(pow(local_coverage.g, anvil_exponent), 0.0, 1.0) : 0.0;
	}
	// 云图边缘平滑收空，coverage=1 时也不拉伸边缘 texel 或重复铺满。
	vec2 edge_distance = min(map_uv, vec2(1.0) - map_uv);
	local_coverage *= smoothstep(0.0, 0.04, min(edge_distance.x, edge_distance.y));
	// R/G 是两种覆盖度分布；0 选 R，1 选 G，中间连续混合。
	float coverage = mix(local_coverage.r, local_coverage.g, coverage_blend);
	// 混合模式要分别判断通道，不能先混合覆盖度再统一裁剪。
	if ((density_mode == 3 && max(local_coverage.r, local_coverage.g) <= 0.0)
		|| (density_mode != 3 && coverage <= 0.0)) {
		return 0.0;
	}
	// B 按位置控制云类型；默认偏移为 0，完全遵循云图。
	vec4 profile = cloud_height_profile(local_cloud_type, stratus_profile, stratocumulus_profile, cumulus_profile);
	float height_density = cloud_height_density(height_fraction, profile);
	if (density_mode == 0) {
		return cloud_covered_density(height_density, coverage);
	}
	if (!noise_ready || height_density <= 0.0) {
		return 0.0;
	}
	// 所有基础形状都在 [0,1]：高度乘以最大噪声仍越不过 coverage 阈值时，
	// 三维噪声与侵蚀不可能产生密度。分别判断 R/G，保留混合模式的边界。
	bool red_possible = density_mode == 3 && coverage_blend < 1.0 && local_coverage.r > 0.0
		&& height_density > 1.0 - local_coverage.r;
	bool green_possible = density_mode == 3 && coverage_blend > 0.0 && local_coverage.g > 0.0
		&& height_density > 1.0 - local_coverage.g;
	if (density_mode == 3 ? !(red_possible || green_possible) : height_density <= 1.0 - coverage) {
		return 0.0;
	}
	// 世界 XYZ 等比例采样：上下移动也改变噪声，不是二维纹理挤出。
	vec3 shape_position = world_position - planet_surface_origin;
	shape_position += height_fraction * cloud_tangent_offset(wind_direction, up) * wind_height_skew;
	// PDF 49–50 只描述风向变化；在上部 70–80% 高度平滑引入额外方向。
	float anvil_top_weight = smoothstep(0.7, 0.8, height_fraction);
	shape_position += anvil_top_weight * local_anvil_bias * cloud_tangent_offset(anvil_skew_direction, up) * anvil_skew_distance;
	// 固定大型仍保留高度倾斜与砧状偏移，只有细节坐标累加时间位移。
	float repeat_distance = max(noise_repeat_distance, 0.00001);
	vec3 shape_uv = shape_position / repeat_distance;
	vec3 detail_uv = (shape_position + cloud_tangent_offset(noise_motion_offset, up)) / repeat_distance;
	bool upper_bound = quality == 0;
	int detail_octaves = quality >= 3 ? noise_octaves : min(noise_octaves, max(quality, 1));
	float perlin = cloud_perlin_sample(shape_uv, detail_uv, detail_octaves, upper_bound, detail_factor, base_mip);
	float red_density = 0.0;
	float green_density = 0.0;
	if (density_mode == 1 || red_possible) {
		red_density = cloud_covered_density(perlin * height_density, density_mode == 1 ? coverage : local_coverage.r);
	}
	if (density_mode == 2 || green_possible) {
		float green_coverage = density_mode == 2 ? coverage : local_coverage.g;
		// HDA 链的最大扩张：d17/d33/d2/d4 全为零。连这个上界也无法通过
		// coverage 的样本，可安全跳过四次 Worley 读取，太阳查询也复用此判断。
		float pw_max = cloud_fit_unit(cloud_fit_unit(perlin, -0.1, 1.0), -0.1, 1.0);
		pw_max = cloud_fit_unit(pw_max, -0.1, 1.1);
		if (pw_max * height_density > 1.0 - green_coverage) {
			int detail_bands = quality >= 3 ? 4 : (upper_bound ? 2 : max(quality, 1));
			float perlin_worley = cloud_perlin_worley_detail(shape_uv, detail_uv, perlin, detail_bands, upper_bound, detail_factor, base_mip);
			green_density = cloud_covered_density(perlin_worley * height_density, green_coverage);
		}
	}
	// 侵蚀只减密度；覆盖后已为空的样本不用读取额外三个 Worley 频段。
	if (max(red_density, green_density) <= 0.0) {
		return 0.0;
	}
	float erosion_threshold = quality < 0 || erosion_weight <= 0.0 ? 0.0
		: cloud_erosion_threshold(detail_uv, quality, detail_factor, base_mip, height_fraction) * erosion_weight;
	red_density = cloud_fit_unit(red_density, erosion_threshold, 1.0);
	green_density = cloud_fit_unit(green_density, erosion_threshold, 1.0);
	if (density_mode == 1) { return red_density; }
	if (density_mode == 2) { return green_density; }
	return mix(red_density, green_density, coverage_blend);
}

float sample_cloud_density_filtered(vec3 world_position, int quality, float detail_factor) {
	// 兼容粗采样、地面和旧调用；-16 使现有频段都读取 mip 0。
	return sample_cloud_density_lod(world_position, quality, detail_factor, -16.0, 1.0);
}

float sample_cloud_density(vec3 world_position, int quality) {
	return sample_cloud_density_filtered(world_position, quality, 1.0);
}
