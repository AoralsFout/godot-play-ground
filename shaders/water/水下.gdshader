shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float immersion = 0.0;
uniform float camera_depth = 0.0;
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
