shader_type canvas_item;
// Photo mode's looks, laid over the whole screen: 0 as it is, 1 golden
// hour, 2 black and white, 3 dreamy (soft, pastel and glowing), 4 old
// photo (sepia with faded edges).

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform int look = 0;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	vec2 from_middle = SCREEN_UV - 0.5;
	float vignette = 1.0 - dot(from_middle, from_middle) * 1.6;
	if (look == 1) {
		c = c * vec3(1.08, 0.99, 0.86) + vec3(0.03, 0.015, 0.0);
		c = mix(vec3(luma), c, 0.95) * mix(0.72, 1.0, vignette);
	} else if (look == 2) {
		c = vec3(smoothstep(0.02, 0.98, luma)) * mix(0.8, 1.0, vignette);
	} else if (look == 3) {
		vec3 soft = textureLod(screen, SCREEN_UV, 3.0).rgb;
		c = mix(c, soft, 0.3) + soft * 0.1;
		c = mix(c, vec3(1.0, 0.86, 0.95), 0.1) * 0.95;
		c = mix(c, vec3(1.0, 0.95, 0.98), (1.0 - vignette) * 0.35);
	} else if (look == 4) {
		c = vec3(luma * 1.07, luma * 0.92, luma * 0.72) + vec3(0.06, 0.04, 0.0);
		c = mix(vec3(0.85, 0.78, 0.62), c, clamp(vignette * 1.2, 0.0, 1.0));
	}
	COLOR = vec4(c, 1.0);
}
