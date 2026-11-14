shader_type canvas_item;
render_mode blend_add;
// Тёплый свет настольной лампы поверх стола (вечером и ночью).

uniform vec2 size = vec2(1600.0, 900.0);
uniform vec2 lamp_pos = vec2(0.80, 0.16);
uniform float lamp = 0.0;

void fragment() {
	vec2 aspect = vec2(size.x / size.y, 1.0);
	float d = distance(UV * aspect, lamp_pos * aspect);
	// Свет выявляет материал; умеренная прибавка не вымывает чернила и цвет бумаги.
	float glow = exp(-d * d * 2.8) * 0.17 + exp(-d * d * 14.0) * 0.045;
	COLOR = vec4(vec3(1.0, 0.68, 0.34) * glow * lamp, 1.0);
}
