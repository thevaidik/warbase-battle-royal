shader_type spatial;
render_mode unshaded, shadows_disabled;

void fragment() {
	vec2 offset = UV * 2.0 - 1.0;
	ALBEDO = vec3(0.013, 0.022, 0.031);
	ALPHA = 0.61 * (1.0 - smoothstep(0.05, 1.0, length(offset)));
}
