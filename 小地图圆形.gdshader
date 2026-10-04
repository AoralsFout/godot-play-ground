shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color : source_color = vec4(0.24, 0.25, 0.27, 1.0);
uniform float outline_width = 0.028;

void fragment() {
	float radius = length(UV - vec2(0.5));
	float feather = max(fwidth(radius), 0.001);
	float outer_alpha = 1.0 - smoothstep(0.5 - feather, 0.5 + feather, radius);
	float inner_alpha = 1.0 - smoothstep(
		0.5 - outline_width - feather,
		0.5 - outline_width + feather,
		radius
	);

	COLOR = mix(outline_color, texture(TEXTURE, UV), inner_alpha);
	COLOR.a *= outer_alpha;
}
