shader_type spatial;
// Rocks and standing stones (rocks.gd). Grey stone with darker cracks and
// lighter speckles, picked from the world position so no two stones match,
// and soft green moss growing on the tops. The vertex colour tints the
// stone; `moss` says how mossy. In the mountains the tops are snowy.

uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
uniform vec3 moss_color : source_color = vec3(0.32, 0.46, 0.16);
uniform float moss = 0.5;
uniform float snow_cover = 1.0;   // How much snow settles on the tops in the mountains
uniform vec3 tint : source_color = vec3(1.0);

varying vec3 world;
varying vec3 world_normal;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Sample the grain from the three sides, blended by which way the surface faces.
float triplanar(vec3 p, vec3 n, float scale) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= w.x + w.y + w.z;
	return texture(grain, p.yz * scale).r * w.x + texture(grain, p.xz * scale).r * w.y + texture(grain, p.xy * scale).r * w.z;
}

void fragment() {
	float big = triplanar(world, world_normal, 0.12);
	float fine = triplanar(world, world_normal, 0.9);
	vec3 stone = COLOR.rgb * tint * mix(0.7, 1.15, big) * mix(0.85, 1.1, fine);
	// Cracks: thin dark lines where the grain crosses the middle.
	float crack = 1.0 - smoothstep(0.0, 0.025, abs(triplanar(world + 3.1, world_normal, 0.35) - 0.5));
	stone *= 1.0 - crack * 0.2;
	// Moss on surfaces facing up, in patches.
	float up = smoothstep(0.35, 0.8, world_normal.y);
	float patches = smoothstep(0.45, 0.6, big + (fine - 0.5) * 0.4);
	float mossy = up * patches * moss;
	// Past the snow line (world.gd SNOW_LINE), snow on the tops instead.
	float snowline = smoothstep(-212.0, -246.0, world.z);
	float snowy = smoothstep(0.3, 0.65, world_normal.y + (fine - 0.5) * 0.5) * snowline * snow_cover;
	mossy *= 1.0 - snowline;
	ALBEDO = mix(mix(stone, moss_color * mix(0.8, 1.2, fine), mossy), vec3(0.92, 0.94, 0.98) * mix(0.9, 1.05, fine), snowy);
	ROUGHNESS = mix(mix(0.85, 1.0, mossy), 0.55, snowy);
	SPECULAR = 0.3;
	NORMAL_MAP = vec3(0.5 + (fine - 0.5) * 0.5, 0.5 + (big - 0.5) * 0.3, 1.0);
}
