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
	vec3 coat = mix(points_color, body_color, t) * detail;
	vec3 color = mix(tex, coat, strength);
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
}
