// 渲染编辑器及后处理关闭时的基础体积云预览。
// 与计算合成共用密度、步进及光照函数，以场景深度截断云层，不生成计算光束。

shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;

#include "res://shaders/clouds/cloud_raymarch.gdshaderinc"
#include "res://shaders/clouds/cloud_atmosphere.gdshaderinc"

// 当前视口深度纹理；还原场景距离以阻止云穿过前景几何，由渲染器提供。
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// 编辑器和关闭后处理时的单通道预览，密度/步进函数与 Compositor 共用。
void fragment() {
	vec4 near_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, 1.0, 1.0);
	vec3 ray_direction = normalize((INV_VIEW_MATRIX * vec4(normalize(near_view.xyz / near_view.w), 0.0)).xyz);
	vec3 ray_origin = CAMERA_POSITION_WORLD;
	if ((CAMERA_VISIBLE_LAYERS & 786432u) == 262144u) {
		ray_origin.y = 2.0 * cloud_reflection_height - ray_origin.y;
	}
	float pixel_ray_width = max(length(dFdx(ray_direction)), length(dFdy(ray_direction)));
	float ray_limit = max_distance;
	float depth = texture(scene_depth, SCREEN_UV).r;
	if (depth > 0.0) {
		#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
		#else
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
		#endif
		vec4 surface_view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		if (abs(surface_view.w) > 0.00000001) {
			ray_limit = min(ray_limit, length(surface_view.xyz / surface_view.w));
		}
	}
	float lunar_light;
	vec4 cloud = cloud_raymarch(ray_origin, ray_direction, ray_limit, pixel_ray_width, lunar_light);
	vec3 radiance = cloud_post_lighting(cloud.x, lunar_light, cloud.y, cloud.z, ray_origin, ray_direction);
	float atmosphere_blend = cloud_atmospheric_blend(cloud.z, ray_origin, ray_direction);
	vec3 sky = cloud_sky_background(ray_direction, ray_origin, normalize(sun_direction), sky_style);
	ALBEDO = mix(radiance, sky, atmosphere_blend);
	ALPHA = cloud.w;
}
