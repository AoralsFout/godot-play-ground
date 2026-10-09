// 提供云着色器共用的插值、重映射及数值辅助函数。
// 由噪声和光照代码包含，不依赖场景节点或独立材质。

float cloud_fit_unit(float value, float source_min, float source_max) {
	return clamp((value - source_min) / max(source_max - source_min, 0.00001), 0.0, 1.0);
}
