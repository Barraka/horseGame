shader_type sky;
// The sky over the countryside (sky_cycle.gd sets the uniforms as the day
// goes by): a blue gradient by day, warm glow round the sun at sunrise and
// sunset, twinkling stars and the moon at night, drifting clouds that
// thicken and darken when it rains, and a rainbow after the rain.

uniform vec3 top_color : source_color = vec3(0.22, 0.47, 0.88);
uniform vec3 horizon_color : source_color = vec3(0.86, 0.87, 0.9);
uniform vec3 ground_color : source_color = vec3(0.3, 0.4, 0.25);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform vec3 sun_dir = vec3(0.0, 0.7, -0.7);    // Towards the sun
uniform vec3 moon_dir = vec3(0.0, -0.7, 0.7);
uniform float night = 0.0;          // 0 by day, 1 at night
uniform float glow = 0.0;           // Sunrise or sunset glow, 0 to 1
uniform float cover = 0.3;          // How cloudy, 0 to 1
uniform float storm = 0.0;          // Rain darkens the clouds
uniform float rainbow = 0.0;
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = EYEDIR;
	float up = d.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(up, 0.0, 1.0), 0.45));
	if (up < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-up * 5.0, 0.0, 1.0));
	}
	// Warm glow round the sun, strongest at sunrise and sunset.
	float towards_sun = max(dot(d, normalize(sun_dir)), 0.0);
	col += sun_color * (pow(towards_sun, 6.0) * (0.25 + glow * 0.9) + pow(towards_sun, 64.0) * 0.6) * (1.0 - night);
	col += sun_color * smoothstep(0.9993, 0.9997, towards_sun) * 6.0 * (1.0 - storm);

	if (up > 0.0) {
		// Stars: a few bright cells on a fine grid round the sky.
		vec3 p = d * 260.0;
		vec3 cell = floor(p);
		float h = hash(cell);
		float star = step(0.994, h) * smoothstep(0.42, 0.0, length(fract(p) - 0.5));
		star *= 0.6 + 0.4 * sin(TIME * (2.0 + h * 5.0) + h * 40.0);   // Twinkle
		col += vec3(0.9, 0.95, 1.0) * star * night * (1.0 - cover) * smoothstep(0.0, 0.15, up) * 2.5;
		// The moon, with a soft halo.
		float towards_moon = max(dot(d, normalize(moon_dir)), 0.0);
		col += vec3(0.95, 0.95, 0.85) * smoothstep(0.9990, 0.9994, towards_moon) * 2.5 * night;
		col += vec3(0.5, 0.6, 0.8) * pow(towards_moon, 40.0) * 0.25 * night;

		// Clouds on a flat ceiling, drifting with the wind.
		vec2 uv = d.xz / (up + 0.12) * 0.25 + vec2(TIME * 0.004, TIME * 0.0015);
		float n = texture(cloud_noise, uv).r * 0.65 + texture(cloud_noise, uv * 2.7 + 0.3).r * 0.35;
		float amount = smoothstep(0.62 - cover * 0.45, 0.8 - cover * 0.3, n) * smoothstep(0.0, 0.12, up);
		vec3 lit = mix(vec3(1.0), sun_color * 1.1 + vec3(0.25, 0.1, 0.15), glow * 0.7);
		lit = mix(lit, vec3(0.16, 0.18, 0.24), night);
		lit = mix(lit, vec3(0.42, 0.44, 0.48) * (1.0 - night * 0.7), storm);
		col = mix(col, lit * (0.85 + n * 0.25), amount * (0.85 + storm * 0.15));
		col = mix(col, vec3(0.45, 0.47, 0.5) * (1.0 - night * 0.75), storm * 0.55);

		// A rainbow, 42 degrees round the point opposite the sun.
		float angle = degrees(acos(clamp(dot(d, -normalize(sun_dir)), -1.0, 1.0)));
		float band = (angle - 40.0) / 3.0;   // 0 violet .. 1 red
		if (band > 0.0 && band < 1.0) {
			vec3 bow = clamp(abs(fract(vec3(0.0, 0.33, 0.67) + (1.0 - band) * 0.8) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
			col = mix(col, col + bow * 0.5, rainbow * sin(band * PI) * smoothstep(0.0, 0.2, up));
		}
	}
	COLOR = col;
}
