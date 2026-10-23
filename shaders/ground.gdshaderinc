// Shared by the ground and the grass on it, so grass blades take the same
// colour as the ground they grow from: big soft patches of lusher and
// drier grass, and a grain a few metres across.
uniform sampler2D patches : filter_linear_mipmap, repeat_enable;
uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
uniform vec3 lush : source_color = vec3(0.16, 0.42, 0.1);
uniform vec3 dry : source_color = vec3(0.6, 0.66, 0.26);

vec3 meadow_color(vec3 base, vec2 xz) {
	float patch = texture(patches, xz * 0.004).r;
	vec3 tint = mix(lush, dry, smoothstep(0.35, 0.75, patch));
	return mix(base, tint, 0.45) * mix(0.82, 1.12, texture(grain, xz * 0.05).r);
}
