// 对浸水摄像机的画面叠加水下颜色和扰动。
// 水面控制器同步浸水比例、摄像机深度及可暂停的游戏时间。

shader_type canvas_item;
render_mode unshaded;
// 渲染器复制的当前屏幕颜色纹理；用于折射或水下画面扰动，不手动指定资源。
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
// 摄像机浸水比例（0 至 1）；越大水下叠色和扰动越明显。
uniform float immersion = 0.0;
// 摄像机低于动态波面的深度（米）；影响水下颜色及扰动强度。
uniform float camera_depth = 0.0;
// 可暂停的游戏时间（秒）；由脚本同步，驱动波浪和水下动画。
uniform float game_time = 0.0;
void fragment() {
 vec2 uv = SCREEN_UV;
 vec2 distortion = vec2(sin(uv.y * 28.0 + game_time * 1.1), cos(uv.x * 24.0 - game_time * 0.9));
 uv = clamp(uv + distortion * 0.0018 * immersion, vec2(0.001), vec2(0.999));
 vec3 scene = texture(screen_texture, uv).rgb;
 // 红光最先衰减；摄像机环境负责提供距离雾。
 vec3 transmission = exp(-vec3(0.16, 0.045, 0.018) * min(camera_depth + 0.7, 20.0));
 vec3 color = scene * transmission;
 float vignette = smoothstep(0.28, 0.75, length(SCREEN_UV - 0.5));
 color *= 1.0 - vignette * 0.15;
 COLOR = vec4(mix(texture(screen_texture, SCREEN_UV).rgb, color, immersion), 1.0);
}
