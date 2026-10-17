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

// Brightness of the texture's body and points, measured from the texture.
const float BODY_LUMA = 0.57;
const float POINTS_LUMA = 0.21;

void fragment() {
	vec3 tex = texture(albedo_texture, UV).rgb;
	float luma = dot(tex, vec3(0.299, 0.587, 0.114));
	float t = smoothstep(0.25, 0.45, luma);
	float detail = clamp(luma / mix(POINTS_LUMA, BODY_LUMA, t), 0.55, 1.5);
	vec3 coat = mix(points_color, body_color, t) * detail;
	ALBEDO = mix(tex, coat, strength);
	ROUGHNESS = mix(0.75, 0.32, gloss);
	SPECULAR = 0.5;
	RIM = 0.25 * gloss;
	RIM_TINT = 0.5;
}
