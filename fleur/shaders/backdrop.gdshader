shader_type canvas_item;
// Фон VN-сцены и меню: трёхцветный градиент, мягкие световые полосы, вода, виньетка.

uniform vec4 c_top : source_color = vec4(0.1, 0.15, 0.25, 1.0);
uniform vec4 c_mid : source_color = vec4(0.2, 0.3, 0.4, 1.0);
uniform vec4 c_bot : source_color = vec4(0.05, 0.08, 0.12, 1.0);
uniform float water = 0.0;
uniform float shafts = 0.6;

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = uv.y < 0.5 ? mix(c_top.rgb, c_mid.rgb, uv.y * 2.0) : mix(c_mid.rgb, c_bot.rgb, (uv.y - 0.5) * 2.0);
	float n = noise(vec2(uv.x * 3.0 - uv.y * 1.5, TIME * 0.05));
	float beams = smoothstep(0.55, 1.0, noise(vec2(uv.x * 6.0 + uv.y * 2.0, TIME * 0.04))) * (1.0 - uv.y);
	col += vec3(1.0, 0.92, 0.75) * beams * 0.12 * shafts;
	col *= 0.92 + 0.12 * n;
	if (water > 0.0) {
		float w = sin(uv.y * 140.0 - TIME * 1.4 + noise(uv * 12.0 + TIME * 0.2) * 6.0);
		col += vec3(0.6, 0.85, 0.9) * smoothstep(0.92, 1.0, w) * 0.08 * water * smoothstep(0.5, 1.0, uv.y);
	}
	float vig = smoothstep(1.05, 0.3, distance(uv, vec2(0.5, 0.45)));
	col *= mix(0.35, 1.0, vig);
	COLOR = vec4(col, 1.0);
}
