float cloud_fit_unit(float value, float source_min, float source_max) {
	return clamp((value - source_min) / max(source_max - source_min, 0.00001), 0.0, 1.0);
}
