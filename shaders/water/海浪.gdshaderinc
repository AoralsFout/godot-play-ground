// 解析计算涌浪高度及其导数；浸水查询使用相同的计算逻辑。
vec3 swell(vec2 p, vec2 direction, float k, float amplitude, float phase, float time) {
 float angle = dot(p, direction) * k - sqrt(9.81 * k) * time + phase;
 return vec3(sin(angle) + 0.18 * sin(2.0 * angle), (cos(angle) + 0.36 * cos(2.0 * angle)) * k * direction) * amplitude;
}
vec3 ocean_wave(vec2 p, float time, float height) {
 return (swell(p, vec2(0.94, 0.342), 0.42, 0.55, 0.0, time)
  + swell(p, vec2(0.643, -0.766), 0.71, 0.25, 1.7, time)
  + swell(p, vec2(-0.259, 0.966), 1.13, 0.13, 3.1, time)
  + swell(p, vec2(0.819, 0.574), 1.91, 0.07, 0.8, time)) * height;
}
float hash_position(vec2 cell) {
 vec3 p = fract(vec3(cell.xyx) * 0.1031);
 p += dot(p, p.yzx + 33.33);
 return fract((p.x + p.y) * p.z);
}
vec3 smooth_noise(vec2 p) {
 vec2 cell = floor(p);
 vec2 f = fract(p);
 vec2 blend = f * f * (3.0 - 2.0 * f);
 vec2 slope = 6.0 * f * (1.0 - f);
 float a = hash_position(cell);
 float b = hash_position(cell + vec2(1.0, 0.0));
 float c = hash_position(cell + vec2(0.0, 1.0));
 float d = hash_position(cell + vec2(1.0, 1.0));
 return vec3(mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y),
  slope.x * mix(b - a, d - c, blend.y), slope.y * mix(c - a, d - b, blend.x));
}
