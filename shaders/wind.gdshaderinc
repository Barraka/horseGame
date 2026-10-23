// Wind for grass and flowers: a quick sway with slow gusts rolling across
// the meadow. Returns how far the top of a plant at `root` leans (x, z).
uniform float wind_strength = 0.12;
uniform vec2 wind_direction = vec2(0.8, 0.5);

vec2 wind_sway(vec3 root, float time) {
	float gust = sin(time * 0.7 + dot(root.xz, wind_direction) * 0.06) * 0.5 + 0.5;
	float sway = sin(time * 1.9 + root.x * 0.37 + root.z * 0.29)
		+ 0.4 * sin(time * 3.3 + root.x * 0.9 - root.z * 0.7);
	return wind_direction * (sway * 0.5 + gust * 1.2) * wind_strength;
}

// Plants shrink away near the edge of where they're drawn, so they don't
// pop in.
float fade_in(vec3 root, vec3 camera, float start, float end) {
	return 1.0 - smoothstep(start, end, distance(root, camera));
}
