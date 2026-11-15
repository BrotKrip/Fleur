shader_type canvas_item;
render_mode unshaded;

uniform vec4 ambient_color : source_color = vec4(1.0);
uniform float ambient_strength : hint_range(0.0, 1.0) = 0.0;
uniform float brightness : hint_range(0.0, 1.25) = 1.0;
uniform vec4 light_color : source_color = vec4(1.0);
uniform float light_strength : hint_range(0.0, 1.0) = 0.0;
uniform float light_side : hint_range(-1.0, 1.0) = 1.0;
uniform float figure_width = 420.0;

varying vec4 draw_color;
varying float across_figure;

void vertex() {
	draw_color = COLOR;
	across_figure = VERTEX.x / figure_width;
}

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	// Белые волосы и освещённые участки кожи сохраняют больше исходного цвета.
	float luminance = dot(texel.rgb, vec3(0.2126, 0.7152, 0.0722));
	float tint = ambient_strength * mix(1.0, 0.55, smoothstep(0.35, 0.95, luminance));
	vec3 shaded = texel.rgb * mix(vec3(1.0), ambient_color.rgb, tint) * brightness;

	// Полупрозрачные пиксели получают меньше блика. Покрытие силуэта остаётся исходным.
	float coverage = smoothstep(0.08, 0.96, texel.a);
	shaded *= 1.0 - (1.0 - coverage) * ambient_strength * 0.24;
	float right = smoothstep(0.14, 0.86, across_figure);
	float side = light_side * 0.5 + 0.5;
	float facing = mix(1.0 - right, right, side);
	float proximity = mix(1.0 - SCREEN_UV.x, SCREEN_UV.x, side);
	float light = light_strength * mix(0.10, 1.0, facing) * mix(0.65, 1.0, proximity) * coverage;
	shaded += texel.rgb * light_color.rgb * light * (1.0 - 0.55 * shaded);

	// В draw_color остаются акцент говорящего, появление и смешивание эмоций.
	COLOR = vec4(clamp(shaded, vec3(0.0), vec3(1.0)) * draw_color.rgb, texel.a * draw_color.a);
}
