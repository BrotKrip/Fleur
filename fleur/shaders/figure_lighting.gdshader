shader_type canvas_item;
render_mode unshaded;

uniform vec4 ambient_color : source_color = vec4(1.0);
uniform float ambient_strength : hint_range(0.0, 1.0) = 0.0;
uniform float brightness : hint_range(0.0, 1.25) = 1.0;
uniform vec4 light_color : source_color = vec4(1.0);
uniform float light_strength : hint_range(0.0, 1.0) = 0.0;
uniform float light_side : hint_range(-1.0, 1.0) = 1.0;
uniform float figure_width = 420.0;
uniform vec4 backdrop_left : source_color = vec4(0.45, 0.45, 0.45, 1.0);
uniform vec4 backdrop_right : source_color = vec4(0.45, 0.45, 0.45, 1.0);

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

varying vec4 draw_color;
varying float across_figure;

void vertex() {
	draw_color = COLOR;
	across_figure = VERTEX.x / figure_width;
}

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	// Широкий рефлекс подхватывает сторону декорации, у которой стоит персонаж.
	vec3 room = mix(backdrop_left.rgb, backdrop_right.rgb, smoothstep(0.2, 0.8, SCREEN_UV.x));
	float room_value = dot(room, LUMA);
	vec3 room_hue = clamp(room / max(room_value, 0.06), vec3(0.55), vec3(1.45));
	float exposure = clamp(1.0 + (room_value - 0.45) * 0.32, 0.88, 1.025);
	float luminance = dot(texel.rgb, LUMA);
	float tint = ambient_strength * mix(1.0, 0.72, smoothstep(0.35, 0.95, luminance));
	vec3 shaded = texel.rgb * mix(vec3(1.0), ambient_color.rgb, tint) * brightness;
	shaded *= exposure * mix(vec3(1.0), room_hue, 0.13 + 0.10 * ambient_strength);

	// Рассеянный свет не меняет альфу тонких волос. Направленный не выбеливает контур.
	float coverage = smoothstep(0.08, 0.96, texel.a);
	float figure_x = TEXTURE_PIXEL_SIZE.x < 1.0 ? UV.x : across_figure;
	float right = smoothstep(0.12, 0.88, figure_x);
	float side = light_side * 0.5 + 0.5;
	float facing = mix(1.0 - right, right, side);
	float proximity = mix(1.0 - SCREEN_UV.x, SCREEN_UV.x, side);
	float light = light_strength * mix(0.06, 1.0, facing) * mix(0.58, 1.0, proximity) * coverage;
	// Источник проявляется и на цветной ткани; белая кожа и блики сохраняют детали.
	vec3 reflectance = mix(texel.rgb, vec3(luminance), 0.40);
	vec3 headroom = max(vec3(0.0), vec3(1.0) - shaded);
	shaded += light_color.rgb * light * sqrt(reflectance) * headroom;

	// В draw_color остаются акцент говорящего, появление и смешивание эмоций.
	COLOR = vec4(clamp(shaded, vec3(0.0), vec3(1.0)) * draw_color.rgb, texel.a * draw_color.a);
}
