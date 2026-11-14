shader_type canvas_item;
// Столешница: тёмное дерево (орех), волокна, лак, латунная окантовка, свет лампы и виньетка.

uniform vec2 size = vec2(1600.0, 900.0);
uniform vec3 tint = vec3(1.0);
uniform vec2 lamp_pos = vec2(0.82, 0.18);
uniform float lamp = 0.0;
uniform float daylight = 1.0;
uniform sampler2D walnut : source_color, filter_linear_mipmap;
uniform bool has_material = false;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 px = UV * size;
	vec3 col;
	if (has_material) {
		// Цельный шпон: без повторов текстуры и нарисованных стыков досок.
		col = texture(walnut, UV).rgb * vec3(0.67, 0.72, 0.78);
	} else {
		// Процедурное дерево остаётся резервом, но не вычисляется поверх готового арта.
		float plank_h = 150.0;
		float plank = floor(px.y / plank_h);
		float py = mod(px.y, plank_h);
		vec2 p = vec2(px.x * 0.004 + plank * 7.3, py * 0.06 + plank * 3.1);
		float grain = fbm(vec2(p.x * 0.6, p.y * 0.35) + fbm(p * 1.3) * 1.6);
		float rings = sin((p.y + grain * 4.0) * 6.0) * 0.5 + 0.5;
		col = mix(vec3(0.16, 0.085, 0.045), vec3(0.29, 0.16, 0.085), grain);
		col = mix(col, vec3(0.40, 0.235, 0.12), rings * 0.28 * grain);
		col *= 0.9 + 0.2 * noise(vec2(px.x * 0.002, plank * 13.0));
		float seam = smoothstep(2.5, 0.0, py) + smoothstep(plank_h - 1.5, plank_h, py);
		col *= 1.0 - seam * 0.45;
	}
	// Лак: мягкий блик
	col += vec3(0.05, 0.035, 0.02) * pow(1.0 - abs(UV.y - 0.3), 6.0) * daylight;

	// Латунная окантовка по краю
	float edge = min(min(px.x, size.x - px.x), min(px.y, size.y - px.y));
	float brass = smoothstep(14.0, 12.5, edge) * smoothstep(5.0, 6.5, edge);
	vec3 brass_col = vec3(0.62, 0.46, 0.2) * (0.75 + 0.35 * noise(px * 0.05));
	col = mix(col, brass_col, brass);
	float hairline = (1.0 - smoothstep(0.0, 1.0, abs(edge - 20.0))) * 0.40;
	col = mix(col, vec3(0.65, 0.48, 0.24), hairline);
	float bevel = (1.0 - smoothstep(0.0, 1.1, abs(edge - 15.5))) * 0.17;
	col += vec3(1.0, 0.78, 0.4) * bevel;
	col *= mix(0.55, 1.0, smoothstep(0.0, 6.0, edge));

	// Освещение: дневной тон, лампа, виньетка
	col *= tint;
	float d = distance(UV * vec2(size.x / size.y, 1.0), lamp_pos * vec2(size.x / size.y, 1.0));
	col += vec3(1.0, 0.7, 0.35) * lamp * 0.55 * exp(-d * d * 3.5);
	float vig = smoothstep(1.15, 0.35, distance(UV, vec2(0.5, 0.48)));
	col *= mix(0.45, 1.0, vig);
	COLOR = vec4(col, 1.0);
}
