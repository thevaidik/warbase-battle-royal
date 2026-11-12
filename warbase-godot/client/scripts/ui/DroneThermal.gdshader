shader_type canvas_item;
render_mode unshaded;

uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec3 scene = texture(scene_color, SCREEN_UV).rgb;
	float luminance = dot(scene, vec3(0.2126, 0.7152, 0.0722));
	float signature = smoothstep(0.24, 0.50, min(scene.r, scene.b) - scene.g);
	float cold = pow(luminance, 0.75);
	vec3 thermal = mix(vec3(0.033, 0.048, 0.056), vec3(0.52, 0.58, 0.60), cold);
	thermal = mix(thermal, vec3(0.98, 0.985, 0.96), signature);
	float edge = 1.0 - 0.18 * smoothstep(0.24, 0.72, length(SCREEN_UV - vec2(0.5)));
	COLOR = vec4(thermal * edge, 1.0);
}
