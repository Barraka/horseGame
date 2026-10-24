shader_type spatial;
// The Frozen Lake's ice (mountains.gd): clear blue in the middle, whiter
// towards the frosty edge, with long thin cracks and drifts of snow blown
// across it. Shiny, so the sky shows in it.

uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
uniform float radius = 26.0;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 local = world.xz - NODE_POSITION_WORLD.xz;
	float from_middle = length(local) / radius;
	float big = texture(grain, world.xz * 0.02).r;
	float fine = texture(grain, world.xz * 0.15).r;
	vec3 deep = vec3(0.26, 0.48, 0.68);
	vec3 frost = vec3(0.82, 0.9, 0.96);
	vec3 color = mix(deep, frost, smoothstep(0.55, 1.05, from_middle + (big - 0.5) * 0.5));
	// Cracks: thin pale lines where the grain crosses its middle.
	float crack = 1.0 - smoothstep(0.0, 0.012, abs(texture(grain, world.xz * 0.04 + 3.7).r - 0.5));
	crack *= smoothstep(0.4, 0.6, fine);
	color = mix(color, vec3(0.92, 0.96, 1.0), crack * 0.7);
	// Wind-blown snow in soft streaks.
	float drift = smoothstep(0.62, 0.8, texture(grain, vec2(world.x * 0.03, world.z * 0.09)).r + from_middle * 0.2);
	color = mix(color, vec3(0.93, 0.95, 0.99), drift * 0.85);
	ALBEDO = color;
	ROUGHNESS = mix(0.06, 0.6, max(drift, smoothstep(0.7, 1.0, from_middle)));
	METALLIC = 0.1;
	SPECULAR = 0.7;
	RIM = 0.2;
}
