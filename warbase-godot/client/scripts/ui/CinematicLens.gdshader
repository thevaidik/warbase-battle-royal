shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// Cinematic optical calibration
const vec3 LUMA_WEIGHT = vec3(0.2126, 0.7152, 0.0722);

// Split-toning: subtle cool slate-teal shadows, natural warm highlights
const vec3 SHADOW_GRADE = vec3(0.96, 0.98, 1.02);
const vec3 HIGHLIGHT_GRADE = vec3(1.02, 1.00, 0.97);

// High-performance hash for 35mm micro film grain
float film_hash(vec2 p, float t) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33 + t);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - vec2(0.5);
	float dist_sq = dot(centered, centered);
	
	// Subtle lens radial chromatic dispersion at the extreme edges (outer 25%)
	float ca_factor = smoothstep(0.18, 0.55, dist_sq) * 0.0012;
	vec2 ca_offset = normalize(centered + vec2(0.0001)) * ca_factor;
	
	float r = texture(screen_texture, uv - ca_offset).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv + ca_offset).b;
	vec3 col = vec3(r, g, b);
	
	// Hollywood cinema split-toning (harmonizes disparate scene colors into a unified palette)
	float luma = dot(col, LUMA_WEIGHT);
	vec3 grade = mix(SHADOW_GRADE, HIGHLIGHT_GRADE, smoothstep(0.15, 0.85, luma));
	col *= grade;
	
	// Optical cinema lens vignette (subtle natural light falloff toward corners)
	float vignette = 1.0 - smoothstep(0.18, 0.75, dist_sq) * 0.30;
	col *= vignette;
	
	// Organic 35mm micro film grain (quantized at 12 fps for authentic cinematic texture)
	float frame = floor(TIME * 12.0) * 0.08;
	float grain = (film_hash(SCREEN_UV * vec2(960.0, 540.0), frame) - 0.5) * 0.020;
	col += vec3(grain);
	
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
