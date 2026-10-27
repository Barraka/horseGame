shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
// Mane and tail hair (scripts/hair.gd): each card is a ribbon of fine
// strands. UV.x runs across the ribbon, UV.y from root (0) to tip (1), and
// UV2.x is the strand's own random number.

uniform vec3 hair_color : source_color = vec3(0.08, 0.06, 0.05);
uniform float shine : hint_range(0.0, 1.0) = 0.7;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void fragment() {
	float seed = UV2.x * 37.0;
	float u = UV.x;
	float v = UV.y;
	// Locks of fine hairs across the ribbon, each its own length and shade.
	float lane = u * 9.0 + noise(v * 3.0 + seed) * 1.2;
	float id = floor(lane);
	float inside = abs(fract(lane) - 0.5) * 2.0;
	float own_length = 0.6 + 0.4 * hash(id + seed);
	float hair = (1.0 - smoothstep(0.75, 1.0, inside)) * (1.0 - smoothstep(own_length - 0.15, own_length, v));
	// Full and solid at the root, thinning out into wisps at the tips and
	// the edges of the ribbon.
	float edge = 1.0 - smoothstep(0.35, 0.5, abs(u - 0.5)) * v;
	float body = clamp(hair + (1.0 - v) * 0.6, 0.0, 1.0) * edge;
	ALPHA = body;
	ALPHA_SCISSOR_THRESHOLD = 0.4;

	float shade = 0.75 + 0.5 * hash(id * 1.7 + seed);
	vec3 color = hair_color * shade;
	// A little darker at the roots, sun-lightened at the ends.
	color *= mix(0.65, 1.15, smoothstep(0.0, 0.7, v));
	ALBEDO = color;
	ROUGHNESS = mix(0.7, 0.42, shine);
	SPECULAR = 0.25;
	// Hair shines in a band across its length, not as a round spot.
	ANISOTROPY = 0.5;
	ANISOTROPY_FLOW = vec2(1.0, 0.0);   // Along the tangent, which runs down the hair
	// Round each hair a little, so the ribbon doesn't light like paper.
	NORMAL_MAP = vec3(0.5, (fract(lane) - 0.5) * 0.35 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 1.0;
	BACKLIGHT = hair_color * 0.5;
	AO = mix(0.55, 1.0, smoothstep(0.0, 0.5, v));
	AO_LIGHT_AFFECT = 0.3;
}
