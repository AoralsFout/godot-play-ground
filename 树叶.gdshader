shader_type spatial;
render_mode cull_disabled, diffuse_burley;

group_uniforms Leaf;
uniform vec4 leaf_color : source_color = vec4(0.25, 0.46, 0.13, 1.0);
uniform vec4 light_leaf_color : source_color = vec4(0.34, 0.52, 0.18, 1.0);
uniform float color_variation : hint_range(0.0, 1.0) = 0.22;
uniform float translucency : hint_range(0.0, 1.0) = 0.3;
group_uniforms Breeze;
uniform vec2 wind_direction = vec2(0.94, 0.34);
uniform float wind_strength : hint_range(0.0, 1.0) = 0.18;
uniform float wind_speed : hint_range(0.0, 4.0) = 0.85;
uniform bool use_game_time = false;
uniform float leaf_time = 0.0;
group_uniforms Falling;
uniform bool falling_leaf = false;
uniform float fall_speed : hint_range(0.1, 4.0) = 1.4;
uniform float fall_drift : hint_range(0.0, 2.0) = 0.25;
group_uniforms;

varying float leaf_tint;
varying float life_visibility;
varying vec3 leaf_world_position;

mat3 rotation_x(float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

mat3 rotation_z(float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
}

void vertex() {
	float t = use_game_time ? leaf_time : TIME;
	vec3 anchor = MODEL_MATRIX[3].xyz;
	vec2 direction = wind_direction / max(length(wind_direction), 0.0001);
	float seed = INSTANCE_CUSTOM.x * 6.283185;
	leaf_tint = INSTANCE_CUSTOM.y;
	life_visibility = 1.0;
	mat3 model_basis = mat3(MODEL_MATRIX);
	if (falling_leaf) {
		// CUSTOM.z 是到地面的世界距离；每片叶子独立循环，末端缩小后回到枝梢。
		float distance_to_ground = max(INSTANCE_CUSTOM.z, 0.1);
		float duration = distance_to_ground / max(fall_speed, 0.1);
		float age = fract(t / duration + INSTANCE_CUSTOM.w);
		float elapsed = age * duration;
		life_visibility = smoothstep(0.0, 0.04, age) * (1.0 - smoothstep(0.90, 1.0, age));
		mat3 tumble = rotation_z(elapsed * 0.8 + seed) * rotation_x(sin(elapsed * 1.8 + seed) * 0.65);
		VERTEX = tumble * VERTEX * life_visibility;
		NORMAL = tumble * NORMAL;
		vec2 sideways = vec2(-direction.y, direction.x);
		vec2 drift = direction * elapsed * fall_drift;
		drift += sideways * sin(elapsed * 1.4 + seed) * 0.35 * age;
		VERTEX += inverse(model_basis) * vec3(drift.x, -distance_to_ground * age, drift.y);
	} else {
		float phase = dot(anchor.xz, direction) * 0.12 - t * wind_speed;
		float breeze = sin(phase + seed * 0.2) * 0.55 + sin(phase * 0.43 + 1.8) * 0.25;
		float flutter = sin(t * wind_speed * 2.7 + seed) * 0.12;
		// 叶柄固定，叶尖弯曲；转动叶片法线，使光照随微风变化。
		float bend = UV.y * UV.y;
		mat3 flutter_rotation = rotation_x((breeze + flutter) * wind_strength * bend);
		VERTEX = flutter_rotation * VERTEX;
		NORMAL = flutter_rotation * NORMAL;
		vec2 displacement = direction * (breeze + flutter) * wind_strength * bend * INSTANCE_CUSTOM.z;
		VERTEX += inverse(model_basis) * vec3(displacement.x, 0.0, displacement.y);
	}
	leaf_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// 解析叶形，不需要外部贴图；discard 保留深度和双面阴影。
	float half_width = pow(max(sin(UV.y * 3.141593), 0.0), 0.72);
	half_width *= 1.0 + sin(UV.y * 95.0) * 0.018;
	if (abs(UV.x * 2.0 - 1.0) > half_width || life_visibility < 0.01) {
		discard;
	}
	// 与海面反射摄像机使用相同的裁剪层约定。
	if ((CAMERA_VISIBLE_LAYERS & 786432u) == 262144u && leaf_world_position.y < 15.02) {
		discard;
	}
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float variation = (leaf_tint - 0.5) * color_variation;
	vec3 base = mix(leaf_color.rgb, light_leaf_color.rgb, clamp(0.5 + variation, 0.0, 1.0));
	base *= 1.0 + variation * 0.35;
	float midrib = 1.0 - smoothstep(0.008, 0.032, abs(UV.x - 0.5));
	float veins = pow(max(cos((UV.y - abs(UV.x - 0.5) * 0.5) * 70.0), 0.0), 14.0);
	ALBEDO = base * mix(0.94, 1.06, UV.y) * (1.0 + midrib * 0.09 - veins * 0.035);
	ROUGHNESS = 0.86;
	SPECULAR = 0.18;
	BACKLIGHT = ALBEDO * translucency;
}
