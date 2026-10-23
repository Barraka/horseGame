shader_type spatial;
render_mode cull_disabled, world_vertex_coords;
// Wildflowers (world.gd): a green stem and leaves, a yellow middle, and
// petals in the instance's colour. The mesh marks petals with UV2.x = 1
// and the middle with UV2.y = 1.
// UV.y is 0 at the root and 1 at the top; the top sways in the wind.

#include "res://shaders/wind.gdshaderinc"

uniform vec3 stem_color : source_color = vec3(0.25, 0.48, 0.15);
uniform vec3 middle_color : source_color = vec3(0.95, 0.7, 0.1);
uniform float fade_start = 60.0;
uniform float fade_end = 80.0;

varying vec3 petal;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	VERTEX = root + (VERTEX - root) * fade_in(root, CAMERA_POSITION_WORLD, fade_start, fade_end);
	vec2 sway = wind_sway(root, TIME) * UV.y * 0.6;
	VERTEX.xz += sway;
	petal = mix(mix(stem_color, middle_color, UV2.y), COLOR.rgb, UV2.x);
}

void fragment() {
	ALBEDO = petal;
	ROUGHNESS = 0.7;
	vec3 up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	NORMAL = normalize(mix(NORMAL, up, 0.5));
	BACKLIGHT = petal * 0.4;
}
