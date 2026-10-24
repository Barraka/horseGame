shader_type spatial;
render_mode cull_disabled;
// Recolours the horse's painted coat (light body, dark points) into any coat
// colour, keeping the texture's shading and hair detail. Used at run time
// only: the horse's own texture files stay untouched.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 body_color : source_color = vec3(0.45, 0.22, 0.1);
uniform vec3 points_color : source_color = vec3(0.06, 0.05, 0.05);
uniform float strength : hint_range(0.0, 1.0) = 1.0;   // 0 shows the original coat
uniform float gloss : hint_range(0.0, 1.0) = 0.6;
uniform float dirt : hint_range(0.0, 1.0) = 0.0;       // Mud and dust from riding
uniform float ground_y = 0.0;                           // World height of the hooves
// Coat pattern over the body colour: 0 none, 1 pinto patches, 2 leopard
// spots (pattern_color on white), 3 dapples.
uniform int pattern = 0;
uniform vec3 pattern_color : source_color = vec3(0.95, 0.94, 0.92);
uniform float pattern_seed = 0.0;
// The grooming salon (tack.gd FACE_MARKINGS, LEG_MARKINGS, GLITTERS). The
// markings map is painted in the texture's layout by tools/groom_track.py:
// red = how squarely the spot faces forward on the face, green = how far
// down the face, blue = height up the leg (0.5 at the knee), alpha = front
// leg (0.25) or hind leg (0.75).
uniform sampler2D markings_map : filter_linear, repeat_disable;
uniform int face_marking = 0;   // 0 none, 1 star, 2 stripe, 3 blaze, 4 white face
uniform int leg_marking = 0;    // 0 none, 1 front socks, 2 hind socks, 3 four socks, 4 four stockings
uniform float glitter : hint_range(0.0, 1.0) = 0.0;
uniform vec3 glitter_color : source_color = vec3(1.0, 0.85, 0.4);
uniform bool glitter_rainbow = false;

const vec3 MUD = vec3(0.3, 0.22, 0.14);
const vec3 DUST = vec3(0.62, 0.53, 0.42);

varying float height;   // Above the hooves, in metres

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

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 7.3) * 0.3 + noise(p * 4.7 + 1.7) * 0.15;
}

// Distance to the nearest of a scattering of points, and that point's
// own random number.
vec2 cells(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float best = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			float r = hash(i + g + pattern_seed);
			vec2 o = vec2(r, hash(i + g + 19.1 + pattern_seed));
			float d = length(g + o - f);
			if (d < best) {
				best = d;
				id = r;
			}
		}
	}
	return vec2(best, id);
}

// How white a spot is for the chosen face and leg markings, with soft,
// slightly ragged edges like real ones.
float marking(vec2 uv) {
	vec4 m = texture(markings_map, uv);
	float rag = (noise(uv * 160.0) - 0.5) * 0.05;
	float white = 0.0;
	if (face_marking > 0 && m.r > 0.0) {
		float facing = m.r + rag;
		float down = m.g + rag;
		if (face_marking == 1) {
			// A star on the forehead, between the eyes.
			float d = length(vec2((1.0 - facing) * 9.0, (down - 0.22) * 6.5));
			white = 1.0 - smoothstep(0.75, 0.95, d);
		} else {
			// Down the face to the nose: narrow, wide, or the whole front.
			float edge = face_marking == 2 ? 0.965 : (face_marking == 3 ? 0.86 : 0.45);
			float top = face_marking == 4 ? 0.0 : 0.12;
			white = smoothstep(edge - 0.02, edge + 0.02, facing) * smoothstep(top, top + 0.06, down) * (1.0 - smoothstep(0.96, 1.0, down));
		}
	}
	bool front = m.a < 0.5;
	bool hind = m.a > 0.5 && m.a < 0.9;
	bool on_leg = (leg_marking == 1 && front) || (leg_marking == 2 && hind) || (leg_marking >= 3 && (front || hind));
	if (on_leg) {
		float up_to = leg_marking == 4 ? 0.44 : 0.24;
		white = max(white, 1.0 - smoothstep(up_to - 0.015, up_to + 0.015, m.b + rag * 0.6));
	}
	return white;
}

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

// Brightness of the texture's body and points, measured from the texture.
const float BODY_LUMA = 0.57;
const float POINTS_LUMA = 0.21;

void vertex() {
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - ground_y;
}

void fragment() {
	vec3 tex = texture(albedo_texture, UV).rgb;
	float luma = dot(tex, vec3(0.299, 0.587, 0.114));
	float t = smoothstep(0.25, 0.45, luma);
	float detail = clamp(luma / mix(POINTS_LUMA, BODY_LUMA, t), 0.55, 1.5);
	vec3 body = body_color;
	if (pattern == 1) {
		float n = fbm(UV * 3.5 + pattern_seed);
		body = mix(body, pattern_color, smoothstep(0.5, 0.53, n));
	} else if (pattern == 2) {
		vec2 c = cells(UV * 34.0);
		float spot = 1.0 - smoothstep(0.18 + c.y * 0.17, 0.24 + c.y * 0.17, c.x);
		body = mix(vec3(0.93, 0.91, 0.87), pattern_color, spot);
	} else if (pattern == 3) {
		vec2 c = cells(UV * 26.0);
		body *= mix(1.25, 0.7, smoothstep(0.35, 0.75, c.x));
	}
	vec3 coat = mix(points_color, body, t) * detail;
	float white = marking(UV);
	coat = mix(coat, vec3(0.94, 0.93, 0.9) * clamp(luma / mix(POINTS_LUMA, BODY_LUMA, t), 0.8, 1.15), white);
	vec3 color = mix(tex, coat, max(strength, white));
	// Splashes of mud up the legs and a dusty film on the body, in patches
	// that stay put on the coat (they follow its texture, not the world).
	float patches = noise(UV * 30.0) * 0.6 + noise(UV * 90.0) * 0.4;
	float legs = 1.0 - smoothstep(0.2, 0.75, height);
	float mud = clamp(dirt * 1.8 * legs - 0.2 + (patches - 0.5) * 1.6, 0.0, 1.0) * step(0.01, dirt);
	float dust = clamp(dirt * (patches * 1.6 - 0.45), 0.0, 0.5);
	color = mix(color, DUST * (0.7 + 0.3 * luma), dust);
	color = mix(color, MUD * (0.8 + 0.4 * patches), mud);
	ALBEDO = color;
	ROUGHNESS = mix(mix(0.75, 0.32, gloss), 0.95, max(mud, dust));
	SPECULAR = 0.5;
	RIM = 0.25 * gloss * (1.0 - dirt);
	RIM_TINT = 0.5;
	// Glitter: tiny sparkles that twinkle as the horse moves and the light
	// catches them.
	if (glitter > 0.0) {
		vec2 c = cells(UV * 220.0);
		float twinkle = pow(max(sin(TIME * 2.5 + c.y * 60.0 + dot(VIEW, NORMAL) * 14.0), 0.0), 6.0);
		float spark = (1.0 - smoothstep(0.03, 0.11, c.x)) * twinkle * (1.0 - mud);
		vec3 tint = glitter_rainbow ? hue(c.y + TIME * 0.05) : glitter_color;
		ALBEDO = mix(ALBEDO, tint, spark * 0.6);
		EMISSION = tint * spark * glitter * 1.6;
	}
}
