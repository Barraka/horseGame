shader_type spatial;
// Tree bark (trees.gd): the vertex colour is the bark colour, with ridges
// running up the trunk (UV.x goes round it, UV.y up it). Birch bark
// (white) gets dark marks instead.

uniform sampler2D grain : filter_linear_mipmap, repeat_enable;

void fragment() {
	vec3 bark = COLOR.rgb;
	float ridges = texture(grain, vec2(UV.x * 1.5, UV.y * 0.15)).r;
	float marks = texture(grain, vec2(UV.x * 0.8, UV.y * 0.6) + 0.5).r;
	float birch = smoothstep(0.6, 0.75, bark.r);   // Only pale bark is birch
	vec3 color = bark * mix(0.65, 1.15, ridges);
	color = mix(color, mix(bark, vec3(0.12, 0.11, 0.1), smoothstep(0.62, 0.68, marks)), birch);
	ALBEDO = color;
	ROUGHNESS = 0.95;
	NORMAL_MAP = vec3(0.5 + (ridges - 0.5) * 0.6, 0.5, 1.0);
}
