shader_type spatial;
render_mode cull_disabled;
// Leaves on trees and bushes (trees.gd): cards with a leafy cut-out
// texture, tinted by the tree's leaf colour (vertex colour, darker deep
// inside the crown) and the instance colour. The normals point out from
// the middle of each leaf cluster, so a crown is lit like one soft ball
// instead of hundreds of flat cards. The leaves flutter in the wind and
// let a little sunlight through. In the mountains the tops are snowy.

uniform sampler2D leaves : source_color, filter_linear_mipmap, repeat_disable;
uniform float flutter = 0.06;

varying vec3 soft_normal;
varying float snow;   // Snow on top, in the mountains (past world.gd's SNOW_LINE)

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	// Higher leaves move more; UV2.x is the height in the tree, 0 to 1.
	float phase = TIME * 2.3 + root.x * 0.3 + root.z * 0.2 + VERTEX.y * 0.8;
	VERTEX.x += sin(phase) * flutter * UV2.x;
	VERTEX.z += cos(phase * 0.8) * flutter * UV2.x;
	VERTEX.y += sin(phase * 1.7 + VERTEX.x) * flutter * 0.4 * UV2.x;
	soft_normal = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	snow = smoothstep(-212.0, -246.0, root.z) * smoothstep(-0.1, 0.5, up.y + (UV2.x - 0.5) * 0.4);
}

void fragment() {
	vec4 leaf = texture(leaves, UV);
	ALBEDO = mix(leaf.rgb * COLOR.rgb, vec3(0.9, 0.93, 0.98) * mix(0.78, 1.0, leaf.g), snow * 0.85);
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	NORMAL = normalize(soft_normal);
	ROUGHNESS = 0.75;
	SPECULAR = 0.3;
	BACKLIGHT = COLOR.rgb * 0.45;
}
