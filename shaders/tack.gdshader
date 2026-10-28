shader_type spatial;
render_mode cull_disabled;
// The horse's tack (scripts/tack.gd): leather with a fine grain and a
// polish, a quilted saddle pad, fleecy bandage wraps, and plain cloth.
// Pieces built by tack.gd carry their UVs in metres (across, along), so
// grain, quilting and stitches keep the same size on every piece.

uniform vec3 color : source_color = vec3(0.26, 0.13, 0.06);
uniform int kind = 0;           // 0 leather, 1 quilted pad, 2 bandage wrap, 3 cloth, 4 metal
uniform float shine : hint_range(0.0, 1.0) = 0.5;
// Leather with a line of stitches along its edges: the width of the piece
// across (UV.x from 0), or 0 for none.
uniform float stitch_width = 0.0;
uniform vec3 stitch_color : source_color = vec3(0.85, 0.8, 0.7);

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

// Pebbled leather grain.
float grain(vec2 uv) {
	return noise(uv * 260.0) * 0.6 + noise(uv * 700.0) * 0.4;
}

// Quilting: puffed diamonds between sewn-down lines, 7 cm across.
float quilt(vec2 uv) {
	float a = (uv.x + uv.y) / 0.07;
	float b = (uv.x - uv.y) / 0.07;
	float seam = min(abs(fract(a) - 0.5), abs(fract(b) - 0.5)) * 2.0;   // 0 at a seam
	return sqrt(clamp(seam * 1.6, 0.0, 1.0));
}

// Bandage wrapped round and round the leg: each turn overlaps the last.
float bandage(vec2 uv) {
	float turn = fract(uv.y * 7.0 + uv.x * 1.0);
	return smoothstep(0.0, 0.12, turn) * (0.9 + 0.1 * turn);
}

// A normal map from a height function, by looking a little either side.
vec3 bump(float h, float hx, float hy, float depth) {
	return normalize(vec3((h - hx) * depth, (h - hy) * depth, 1.0)) * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = UV;
	vec2 e = vec2(0.002, 0.0);
	if (kind == 0) {
		float g = grain(uv);
		ALBEDO = color * (0.86 + 0.28 * g);
		ROUGHNESS = mix(0.62, 0.32, shine) + g * 0.12;
		SPECULAR = 0.45;
		CLEARCOAT = 0.35 * shine;
		CLEARCOAT_ROUGHNESS = 0.35;
		NORMAL_MAP = bump(g, grain(uv + e.xy * 0.25), grain(uv + e.yx * 0.25), 0.6);
		if (stitch_width > 0.0) {
			// A row of stitches 6 mm in from each edge.
			float from_edge = min(uv.x, stitch_width - uv.x);
			float dash = step(0.45, fract(uv.y / 0.008));
			float line = (1.0 - smoothstep(0.0008, 0.0016, abs(from_edge - 0.005))) * dash;
			ALBEDO = mix(ALBEDO, stitch_color, line * 0.45);
			// Edges creased and darker, as on a real strap.
			ALBEDO *= mix(0.7, 1.0, smoothstep(0.0, 0.004, from_edge));
		}
	} else if (kind == 1) {
		float q = quilt(uv);
		float fuzz = noise(uv * 900.0);
		ALBEDO = color * (0.72 + 0.28 * q) * (0.96 + 0.08 * fuzz);
		// Stitches along the seams.
		float seam_line = 1.0 - smoothstep(0.0, 0.08, q * q);
		float dash = step(0.5, fract((uv.x + uv.y * 0.3) / 0.006));
		ALBEDO = mix(ALBEDO, color * 0.55, seam_line * dash * 0.6);
		ROUGHNESS = 0.92;
		SPECULAR = 0.3;
		NORMAL_MAP = bump(q, quilt(uv + e.xy), quilt(uv + e.yx), 0.9);
		// Soft fabric catches light at its edges.
		RIM = 0.45;
		RIM_TINT = 0.7;
		BACKLIGHT = color * 0.15;
	} else if (kind == 2) {
		float b = bandage(uv);
		float fuzz = noise(uv * vec2(300.0, 900.0));
		ALBEDO = color * (0.7 + 0.3 * b) * (0.94 + 0.12 * fuzz);
		ROUGHNESS = 1.0;
		SPECULAR = 0.2;
		NORMAL_MAP = bump(b, bandage(uv + e.xy * 2.0), bandage(uv + e.yx * 2.0), 1.2);
		RIM = 0.5;
		RIM_TINT = 0.8;
	} else if (kind == 3) {
		float weave = noise(uv * 1400.0);
		ALBEDO = color * (0.92 + 0.12 * weave);
		ROUGHNESS = 0.8;
		SPECULAR = 0.35;
		RIM = 0.3;
		RIM_TINT = 0.6;
	} else {
		ALBEDO = color;
		METALLIC = 0.9;
		ROUGHNESS = mix(0.4, 0.18, shine) + noise(uv * 400.0) * 0.06;
		SPECULAR = 0.6;
	}
}
