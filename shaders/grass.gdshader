shader_type spatial;
render_mode cull_disabled, world_vertex_coords;
// Grass tufts (grass.gd). Each tuft takes the ground's colour at its root
// (the instance colour, tinted like the ground in ground.gdshaderinc) and
// gets lighter and yellower towards the blade
// tips. UV.y is 0 at the root and 1 at the tip; the tips sway in the wind.

#include "res://shaders/wind.gdshaderinc"
#include "res://shaders/ground.gdshaderinc"

uniform vec3 tip_color : source_color = vec3(1.25, 1.2, 0.8);
uniform float fade_start = 30.0;
uniform float fade_end = 44.0;

varying float height;
varying vec3 base;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	VERTEX = root + (VERTEX - root) * fade_in(root, CAMERA_POSITION_WORLD, fade_start, fade_end);
	height = UV.y;
	base = meadow_color(COLOR.rgb, root.xz);
	vec2 sway = wind_sway(root, TIME) * UV.y * UV.y;
	VERTEX.xz += sway;
}

void fragment() {
	vec3 color = base * mix(vec3(0.5), tip_color, height);
	ALBEDO = color;
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
	// Light the blades mostly as if they faced up, like the ground under
	// them, so they don't flicker dark and light as they turn.
	vec3 up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	NORMAL = normalize(mix(NORMAL, up, 0.7));
	BACKLIGHT = vec3(0.25, 0.3, 0.1);
}
