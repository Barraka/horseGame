shader_type spatial;
// The ground. The mesh's vertex colours paint grass, trail and lake bed
// (world.gd ground_color); this adds what makes it look less flat: big
// soft patches of lusher and drier grass, a fine grain of light and dark
// blades, little bumps that catch the sun, pebbles on the trail and
// glints in the snow.

#include "res://shaders/ground.gdshaderinc"

uniform sampler2D bumps : hint_normal, filter_linear_mipmap, repeat_enable;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = COLOR.rgb;
	// How much this is grass (green) rather than trail or lake bed.
	float grassy = clamp((base.g - base.r) * 4.0, 0.0, 1.0);

	// Patches and grain, like the grass growing here; on the trail just
	// the grain. Then a finer grain close up.
	vec3 color = mix(base * mix(0.82, 1.12, texture(grain, world.xz * 0.05).r), meadow_color(base, world.xz), grassy);
	color *= mix(0.8, 1.15, texture(grain, world.xz * 0.45 + vec2(0.37, 0.71)).r);

	// Trail: sandier in the middle, small dark pebbles.
	float pebble = smoothstep(0.72, 0.78, texture(grain, world.xz * 0.9).r);
	color = mix(color, color * 0.7, pebble * (1.0 - grassy) * 0.7);

	// Snow (white, a little blue): smooth, with tiny glints that twinkle
	// as you ride past.
	float snowy = smoothstep(0.62, 0.8, min(base.r, min(base.g, base.b))) * step(base.r, base.b + 0.02);
	float glint = smoothstep(0.86, 0.9, texture(grain, world.xz * 2.7 + VIEW.xy * 0.06).r);
	color += vec3(0.5, 0.55, 0.65) * glint * snowy;

	ALBEDO = color;
	ROUGHNESS = mix(mix(0.85, 0.95, grassy), 0.5, snowy);
	SPECULAR = mix(0.25, 0.5, snowy);
	NORMAL_MAP = texture(bumps, world.xz * mix(0.25, 0.12, grassy)).rgb;
	NORMAL_MAP_DEPTH = mix(0.8, 0.5, grassy);
}
