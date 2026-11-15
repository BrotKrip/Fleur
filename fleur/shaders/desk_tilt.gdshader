shader_type canvas_item;
// Стол под лёгким наклоном: плоский снимок стола (plane_tex) кладётся на экран в перспективе.
// h0..h2 — строки гомографии «точка экрана → точка плоского стола» (в пикселях).

uniform sampler2D plane_tex : filter_linear, repeat_disable;
uniform vec3 h0;
uniform vec3 h1;
uniform vec3 h2;
uniform vec2 screen_size = vec2(1600.0, 900.0);
uniform vec2 plane_size = vec2(1600.0, 900.0);
uniform float depth_shade = 0.045;

void fragment() {
	vec3 s = vec3(UV * screen_size, 1.0);
	vec2 p = vec2(dot(h0, s), dot(h1, s)) / dot(h2, s);
	vec3 c = texture(plane_tex, p / plane_size).rgb;
	// дальний край стола в тени, ближний на свету
	c *= mix(1.0 - depth_shade, 1.0, UV.y);
	COLOR = vec4(c, 1.0);
}
