shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec4 root_color : source_color = vec4(0.12, 0.25, 0.045, 1.0);
uniform vec4 tip_color : source_color = vec4(0.44, 0.62, 0.19, 1.0);
uniform float sea_level = 15.0;
uniform float wind_time = 0.0;
uniform vec2 wind_direction = vec2(0.94, 0.34);
uniform float wind_strength : hint_range(0.0, 0.5) = 0.12;
uniform float wind_speed : hint_range(0.0, 4.0) = 1.15;
uniform vec3 viewer_position;
uniform float view_distance = 72.0;

varying float blade_height;
varying float color_variation;
varying vec3 grass_world_position;
varying float root_height;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	root_height = root.y;
	blade_height = UV.y;
	color_variation = INSTANCE_CUSTOM.y;
	float distance_to_viewer = length(root.xz - viewer_position.xz);
	float visibility = 1.0 - smoothstep(view_distance - 18.0, view_distance, distance_to_viewer);
	VERTEX *= visibility;
	// 草根保持固定，经过的阵风和各草叶的独立摆动使叶尖弯曲。
	vec2 direction = normalize(wind_direction + vec2(0.0001));
	float phase = dot(root.xz, direction) * 0.22 - wind_time * wind_speed;
	float gust = sin(phase) * 0.55 + sin(phase * 0.47 + 1.9) * 0.3;
	float flutter = sin(wind_time * wind_speed * 2.3 + INSTANCE_CUSTOM.x * 6.28318 + phase) * 0.15;
	vec2 displacement = direction * (0.35 + gust + flutter) * wind_strength * UV.y * UV.y * visibility;
	// 将世界空间的风转换回已旋转、缩放实例的局部坐标。
	VERTEX += (inverse(mat3(MODEL_MATRIX)) * vec3(displacement.x, 0.0, displacement.y));
	grass_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (root_height <= sea_level || grass_world_position.y <= sea_level) {
		discard;
	}
	if ((CAMERA_VISIBLE_LAYERS & 786432u) == 262144u && grass_world_position.y < sea_level + 0.02) {
		discard;
	}
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = mix(root_color.rgb, tip_color.rgb, smoothstep(0.0, 1.0, blade_height)) * mix(0.82, 1.15, color_variation);
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
	BACKLIGHT = ALBEDO * 0.3;
}
