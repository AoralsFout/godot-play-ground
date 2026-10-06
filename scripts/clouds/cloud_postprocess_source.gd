extends RefCounted

# 只展开项目自身的 ShaderInclude，并把数值 uniform 转成 std430 参数。
# 密度/球壳/光照/步进保持单一源码，避免两套渲染路径逐渐分叉。
const SOURCES := {
	"res://shaders/clouds/cloud_raymarch.gdshaderinc": preload("res://shaders/clouds/cloud_raymarch.gdshaderinc"),
	"res://shaders/clouds/cloud_density.gdshaderinc": preload("res://shaders/clouds/cloud_density.gdshaderinc"),
	"res://shaders/clouds/cloud_shell.gdshaderinc": preload("res://shaders/clouds/cloud_shell.gdshaderinc"),
	"res://shaders/clouds/cloud_height_gradient.gdshaderinc": preload("res://shaders/clouds/cloud_height_gradient.gdshaderinc"),
	"res://shaders/clouds/cloud_noise_3d.gdshaderinc": preload("res://shaders/clouds/cloud_noise_3d.gdshaderinc"),
	"res://shaders/clouds/cloud_lighting.gdshaderinc": preload("res://shaders/clouds/cloud_lighting.gdshaderinc"),
	"res://shaders/clouds/cloud_sky_color.gdshaderinc": preload("res://shaders/clouds/cloud_sky_color.gdshaderinc"),
	"res://shaders/clouds/cloud_atmosphere.gdshaderinc": preload("res://shaders/clouds/cloud_atmosphere.gdshaderinc"),
	"res://shaders/clouds/cloud_math.gdshaderinc": preload("res://shaders/clouds/cloud_math.gdshaderinc"),
}

const PASS_BINDINGS := [[1, 2, 3, 4, 5, 6, 7], [1, 2, 7, 8], [7, 9, 10], [0, 1, 2, 3, 7, 9, 11]]

const HEADER := """#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const float PI = 3.141592653589793;
layout(rgba16f, set=0, binding=0) uniform image2D scene_color;
layout(set=0, binding=1) uniform sampler2D scene_depth;
layout(rgba16f, set=0, binding=2) uniform image2D cloud_buffer;
layout(r32f, set=0, binding=3) uniform image2D cloud_depth;
layout(set=0, binding=4) uniform sampler2D cloud_map;
layout(set=0, binding=5) uniform sampler3D perlin_texture;
layout(set=0, binding=6) uniform sampler3D worley_texture;
layout(std430, set=0, binding=7) readonly buffer Parameters { vec4 values[]; } parameters;
layout(rgba16f, set=0, binding=8) uniform image2D shaft_seed;
layout(set=0, binding=9) uniform sampler2D shaft_seed_texture;
layout(rgba16f, set=0, binding=10) uniform image2D shaft_blur;
layout(set=0, binding=11) uniform sampler2D shaft_blur_texture;
"""

const SCREEN_FUNCTIONS := """
vec3 post_view_ray(vec2 uv) {
	vec4 near_view = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, 1.0, 1.0);
	return normalize((INV_VIEW_MATRIX * vec4(normalize(near_view.xyz / near_view.w), 0.0)).xyz);
}
vec2 post_sun_uv() {
	vec4 clip_position = PROJECTION_MATRIX * inverse(INV_VIEW_MATRIX) * vec4(normalize(sun_direction), 0.0);
	return clip_position.w > 0.00001 ? clip_position.xy / clip_position.w * 0.5 + 0.5 : vec2(-100.0);
}
bool post_inside(vec2 uv) {
	return all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)));
}
"""

const DEPTH_FUNCTION := """
float post_scene_distance(vec2 uv) {
	float depth = textureLod(scene_depth, uv, 0.0).r;
	if (depth <= 0.0) { return max_distance; }
	vec4 view_position = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, depth, 1.0);
	if (abs(view_position.w) < 0.00000001) { return max_distance; }
	return min(length(view_position.xyz / view_position.w), max_distance);
}
"""

const RAY_PASS := """
void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(cloud_buffer);
	if (any(greaterThanEqual(pixel, size))) { return; }
	vec2 uv = (vec2(pixel) + 0.5) / vec2(size);
	vec3 direction = post_view_ray(uv);
	vec2 texel = 1.0 / vec2(size);
	float pixel_width = max(length(post_view_ray(uv + vec2(texel.x, 0.0)) - direction),
		length(post_view_ray(uv + vec2(0.0, texel.y)) - direction));
	vec4 cloud = cloud_raymarch(CAMERA_POSITION_WORLD, direction, post_scene_distance(uv), pixel_width);
	float atmosphere = cloud.w > 0.00001 ? cloud_atmospheric_blend(cloud.z, CAMERA_POSITION_WORLD, direction) : 0.0;
	// PDF 100：R=直接光强度 G=大气混合 B=环境光强度 A=不透明度。
	imageStore(cloud_buffer, pixel, vec4(cloud.x, atmosphere, cloud.y, cloud.w));
	imageStore(cloud_depth, pixel, vec4(cloud.z, 0.0, 0.0, 0.0));
}
"""

const SEED_PASS := """
void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(shaft_seed);
	if (any(greaterThanEqual(pixel, size))) { return; }
	float highlight = 0.0;
	vec2 sun_uv = post_sun_uv();
	float screen_fade = 1.0 - smoothstep(0.5, 0.85, max(abs(sun_uv.x - 0.5), abs(sun_uv.y - 0.5)));
	if (light_shafts_enabled && light_shaft_strength > 0.0 && screen_fade > 0.0) {
		vec2 uv = (vec2(pixel) + 0.5) / vec2(size);
		// 输出向外偏移的高光：反向查找略靠近太阳的输入位置。
		vec2 input_uv = sun_uv + (uv - sun_uv) / (1.0 + light_shaft_offset);
		if (post_inside(input_uv) && textureLod(scene_depth, input_uv, 0.0).r <= 0.0) {
			ivec2 cloud_size = imageSize(cloud_buffer);
			ivec2 cloud_pixel = clamp(ivec2(input_uv * vec2(cloud_size)), ivec2(0), cloud_size - 1);
			float opacity = imageLoad(cloud_buffer, cloud_pixel).a;
			float alignment = max(dot(post_view_ray(input_uv), normalize(sun_direction)), 0.0);
			float visible = cloud_sun_visible(CAMERA_POSITION_WORLD, normalize(sun_direction)) ? 1.0 : 0.0;
			float exponent = log(0.5) / log(cos(light_shaft_spread * PI / 180.0));
			// 加强厚云与云隙对比，半透明云边仍连续透光。
			highlight = pow(alignment, exponent) * pow(max(1.0 - opacity, 0.0), 1.5) * visible * screen_fade;
		}
	}
	imageStore(shaft_seed, pixel, vec4(highlight, 0.0, 0.0, 1.0));
}
"""

const BLUR_PASS := """
void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(shaft_blur);
	if (any(greaterThanEqual(pixel, size))) { return; }
	vec2 uv = (vec2(pixel) + 0.5) / vec2(size);
	vec2 sun_uv = post_sun_uv();
	float intensity = 0.0;
	float weights = 0.0;
	if (light_shafts_enabled && light_shaft_strength > 0.0 && sun_uv.x > -99.0) {
		for (int index = 0; index < 64; index++) {
			if (index >= light_shaft_samples) { break; }
			float t = float(index) / max(float(light_shaft_samples - 1), 1.0);
			vec2 sample_uv = mix(uv, sun_uv, t * light_shaft_length);
			float weight = exp(-t * 1.2);
			if (post_inside(sample_uv)) {
				intensity += textureLod(shaft_seed_texture, sample_uv, 0.0).r * weight;
			}
			weights += weight;
		}
	}
	imageStore(shaft_blur, pixel, vec4(intensity / max(weights, 0.00001), 0.0, 0.0, 1.0));
}
"""

const COMPOSITE_PASS := """
void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(scene_color);
	if (any(greaterThanEqual(pixel, size))) { return; }
	vec2 uv = (vec2(pixel) + 0.5) / vec2(size);
	vec3 direction = post_view_ray(uv);
	vec4 cloud = imageLoad(cloud_buffer, pixel);
	float representative_distance = imageLoad(cloud_depth, pixel).r;
	vec3 radiance = cloud_post_lighting(cloud.r, cloud.b, representative_distance, CAMERA_POSITION_WORLD, direction);
	vec3 sky = cloud_sky_background(direction, CAMERA_POSITION_WORLD, normalize(sun_direction), sky_style);
	vec4 scene = imageLoad(scene_color, pixel);
	vec3 result = mix(scene.rgb, mix(radiance, sky, cloud.g), cloud.a);
	float mask = textureLod(shaft_blur_texture, uv, 0.0).r;
	// 终点取几何/云的较近深度，Mie 在远距离才启用。
	// 云前空气已经按深度截断，不能再乘云透射率，否则厚云前的光束会被抹掉。
	float distance_limit = post_scene_distance(uv);
	// 半透明云连续缩短有效空气段；微量云不能突然截断整条光束。
	if (cloud.a > 0.00001) {
		distance_limit = mix(distance_limit, min(distance_limit, representative_distance), cloud.a);
	}
	vec3 shafts = cloud_mie_shafts(mask, distance_limit, CAMERA_POSITION_WORLD, direction);
	result += shafts;
	if (post_debug_view == 1) { result = vec3(cloud.r / (1.0 + cloud.r)); }
	if (post_debug_view == 2) { result = vec3(cloud.g); }
	if (post_debug_view == 3) { result = vec3(cloud.b / (1.0 + cloud.b)); }
	if (post_debug_view == 4) { result = vec3(cloud.a); }
	if (post_debug_view == 5) { result = vec3(mask); }
	if (post_debug_view == 6) { result = vec3(textureLod(shaft_seed_texture, uv, 0.0).r); }
	if (post_debug_view == 7) { result = shafts / (vec3(1.0) + shafts); }
	imageStore(scene_color, pixel, vec4(result, scene.a));
}
"""

static func build() -> Dictionary:
	var source := _expand("res://shaders/clouds/cloud_raymarch.gdshaderinc") + "\n" + _expand("res://shaders/clouds/cloud_atmosphere.gdshaderinc")
	var uniform_regex := RegEx.create_from_string("(?m)^uniform\\s+(\\w+)\\s+(\\w+)([^;]*);")
	var fields: Array[Dictionary] = []
	var defines := ""
	for match_data in uniform_regex.search_all(source):
		var type := match_data.get_string(1)
		var name := match_data.get_string(2)
		if not type.begins_with("sampler"):
			var declaration := match_data.get_string(3)
			var default_expression := declaration.get_slice("=", 1).strip_edges()
			fields.append({"name": name, "type": type, "default": _default_value(default_expression), "linear": declaration.contains("source_color")})
			var element := "parameters.values[%d]" % (fields.size() - 1)
			var expression := element
			match type:
				"float": expression += ".x"
				"int": expression = "int(%s.x)" % element
				"bool": expression = "(%s.x > 0.5)" % element
				"vec2": expression += ".xy"
				"vec3": expression += ".xyz"
			defines += "#define %s (%s)\n" % [name, expression]
		source = source.replace(match_data.get_string(), "")
	for matrix_index in range(3):
		var matrix_name: String = ["PROJECTION_MATRIX", "INV_PROJECTION_MATRIX", "INV_VIEW_MATRIX"][matrix_index]
		var start := fields.size() + matrix_index * 4
		defines += "#define %s mat4(parameters.values[%d], parameters.values[%d], parameters.values[%d], parameters.values[%d])\n" % [matrix_name, start, start + 1, start + 2, start + 3]
	defines += "#define CAMERA_POSITION_WORLD vec3(INV_VIEW_MATRIX[3].x, cloud_reflection_view ? 2.0 * cloud_reflection_height - INV_VIEW_MATRIX[3].y : INV_VIEW_MATRIX[3].y, INV_VIEW_MATRIX[3].z)\n"
	var composite_source := ""
	for path in ["res://shaders/clouds/cloud_shell.gdshaderinc", "res://shaders/clouds/cloud_math.gdshaderinc", "res://shaders/clouds/cloud_lighting.gdshaderinc", "res://shaders/clouds/cloud_sky_color.gdshaderinc", "res://shaders/clouds/cloud_atmosphere.gdshaderinc"]:
		composite_source += _expand(path) + "\n"
	# 各管线只声明实际绑定的纹理，避免依赖编译器消除未使用 descriptor。
	var bodies: Array[String] = [source + SCREEN_FUNCTIONS + DEPTH_FUNCTION + RAY_PASS,
		uniform_regex.sub(_expand("res://shaders/clouds/cloud_shell.gdshaderinc"), "", true) + SCREEN_FUNCTIONS + SEED_PASS,
		SCREEN_FUNCTIONS + BLUR_PASS,
		uniform_regex.sub(composite_source, "", true) + SCREEN_FUNCTIONS + DEPTH_FUNCTION + COMPOSITE_PASS]
	var shaders: Array[String] = []
	var binding_regex := RegEx.create_from_string("binding\\s*=\\s*(\\d+)")
	for pass_index in range(4):
		var header := ""
		for line in HEADER.split("\n"):
			var binding_match := binding_regex.search(line)
			if binding_match == null or PASS_BINDINGS[pass_index].has(int(binding_match.get_string(1))):
				header += line + "\n"
		shaders.append(header + defines + bodies[pass_index])
	return {"fields": fields, "shaders": shaders}

static func _expand(path: String) -> String:
	var source: String = SOURCES[path].code
	var include_regex := RegEx.create_from_string("#include\\s+\"([^\"]+)\"")
	for match_data in include_regex.search_all(source):
		source = source.replace(match_data.get_string(), _expand(match_data.get_string(1)))
	return source

static func _default_value(expression: String) -> Variant:
	if expression == "true": return true
	if expression == "false": return false
	if expression.begins_with("vec"):
		var arguments := expression.get_slice("(", 1).get_slice(")", 0).split(",")
		var result := Vector4.ZERO
		for index in range(4):
			result[index] = float(arguments[mini(index, arguments.size() - 1)].strip_edges())
		return result
	return float(expression)
