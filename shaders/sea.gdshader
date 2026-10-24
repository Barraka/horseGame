shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// The sea off the beach. The water rises and falls in a slow swell, so the
// waves wash up the sand and back; lines of foam roll in towards the shore
// and break white at the water's edge. Turquoise in the shallows, deep blue
// further out. The coast here must match world.gd's coast_x().

uniform vec3 shallow_color : source_color = vec3(0.25, 0.72, 0.72);
uniform vec3 deep_color : source_color = vec3(0.04, 0.24, 0.48);
uniform vec3 foam_color : source_color = vec3(0.97, 0.98, 1.0);
uniform float sand_slope = 0.05;     // How steep the beach is (world.gd SAND_SLOPE)
uniform float floor_slope = 0.06;    // ...and the sea floor (SEA_FLOOR_SLOPE)
uniform float swell = 0.1;           // How far the water rises and falls, in metres

varying vec3 world_pos;
varying float rise;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float coast_x(float z) {
	return 194.0 + 6.0 * sin(z * 0.023) + 3.0 * sin(z * 0.071 + 1.3);
}

float ripples(vec2 p) {
	return noise(p * 0.6 + vec2(-TIME * 0.4, TIME * 0.15)) * 0.6
		+ noise(p * 1.7 + vec2(-TIME * 0.7, -TIME * 0.25)) * 0.4;
}

// The swell: a slow rise and fall with a second, slower beat, so no two
// waves wash up quite as far.
float swell_at(float t) {
	return swell * (sin(t * 0.9) * 0.7 + sin(t * 0.37 + 1.0) * 0.3);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	rise = swell_at(TIME);
	VERTEX.y += rise;
	world_pos.y += rise;
}

void fragment() {
	float out_to_sea = world_pos.x - coast_x(world_pos.z);   // Metres past the still-water edge
	// Where the water's edge is right now, as the swell moves it up and down the sand.
	float edge = -rise / sand_slope;
	float from_edge = out_to_sea - edge;
	float depth = max(out_to_sea, 0.0) * floor_slope + rise;
	vec3 color = mix(shallow_color, deep_color, smoothstep(0.1, 2.5, depth));
	// Rolling lines of foam heading for the shore, breaking near it.
	float n = noise(world_pos.xz * 0.35 + vec2(0.0, TIME * 0.1));
	float roll = fract(from_edge * 0.07 + TIME * 0.11 + n * 0.25);
	float line = smoothstep(0.86, 0.97, roll) * (1.0 - smoothstep(0.97, 1.0, roll));
	line *= smoothstep(45.0, 6.0, from_edge) * (0.4 + n * 0.6);
	// White water where the waves wash over the sand, thinning into lace.
	float wash = 1.0 - smoothstep(0.0, 3.5, from_edge);
	float lace = smoothstep(0.35, 0.7, noise(world_pos.xz * 2.2 + vec2(TIME * 0.3, 0.0)));
	float foam = clamp(line + wash * (0.55 + lace * 0.45), 0.0, 1.0);
	ALBEDO = mix(color, foam_color, foam);
	// See-through where it's shallow, so the wet sand shows.
	ALPHA = clamp(mix(0.45, 0.94, smoothstep(0.0, 1.5, depth)) + foam * 0.5, 0.0, 1.0);
	vec2 p = world_pos.xz;
	float e = 0.2;
	float h = ripples(p);
	vec3 nrm = normalize(vec3(h - ripples(p + vec2(e, 0.0)), 0.7, h - ripples(p + vec2(0.0, e))));
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm, 0.0)).xyz);
	ROUGHNESS = mix(0.06, 0.6, foam);
	SPECULAR = 0.45;
}
