shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// Calm lake water: see-through near the shore, deeper blue further out,
// with small moving ripples catching the light.

uniform vec3 shallow_color : source_color = vec3(0.2, 0.55, 0.6);
uniform vec3 deep_color : source_color = vec3(0.05, 0.22, 0.45);
uniform vec2 centre = vec2(95.0, 70.0);   // Lake centre and radius, in world metres
uniform float radius = 30.0;

varying vec3 world_pos;

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

float ripples(vec2 p) {
	return noise(p * 0.9 + vec2(TIME * 0.35, TIME * 0.2)) * 0.6
		+ noise(p * 2.3 - vec2(TIME * 0.5, -TIME * 0.3)) * 0.4;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float depth = 1.0 - smoothstep(radius * 0.3, radius, distance(world_pos.xz, centre));
	ALBEDO = mix(shallow_color, deep_color, depth);
	ALPHA = mix(0.55, 0.92, depth);
	// Tilt the surface normal by the ripple slope.
	vec2 p = world_pos.xz;
	float e = 0.15;
	float h = ripples(p);
	vec3 n = normalize(vec3(h - ripples(p + vec2(e, 0.0)), 0.6, h - ripples(p + vec2(0.0, e))));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = 0.05;
	SPECULAR = 0.4;
	METALLIC = 0.0;
}
