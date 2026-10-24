shader_type spatial;
render_mode cull_disabled;
// A cloth flag (explore.gd) rippling in the wind. The flag is a
// subdivided plane in x/y, attached to its pole at x = 0 (UV.x = 0).

uniform vec3 color : source_color = vec3(0.95, 0.4, 0.6);
uniform vec3 stripe : source_color = vec3(1.0, 0.95, 0.85);

void vertex() {
	float free = UV.x;   // 0 at the pole, 1 at the loose end
	VERTEX.z += sin(TIME * 4.0 - UV.x * 7.0) * 0.18 * free;
	VERTEX.y += sin(TIME * 3.0 - UV.x * 5.0) * 0.05 * free;
}

void fragment() {
	ALBEDO = mix(color, stripe, step(0.42, abs(UV.y - 0.5)) );
	ROUGHNESS = 0.8;
	BACKLIGHT = color * 0.4;
}
