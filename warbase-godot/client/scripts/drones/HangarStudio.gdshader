shader_type sky;

float softbox(vec3 direction, vec3 center, vec2 size) {
	vec3 horizontal = normalize(cross(vec3(0.0, 1.0, 0.0), center));
	vec3 vertical = cross(center, horizontal);
	float facing = dot(direction, center);
	vec2 point = abs(vec2(dot(direction, horizontal), dot(direction, vertical))) / max(facing, 0.01);
	vec2 feather = 1.0 - smoothstep(size * 0.76, size, point);
	return feather.x * feather.y * step(0.0, facing);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	COLOR = vec3(0.10, 0.14, 0.18) * (0.72 + 0.28 * d.y);
	COLOR += softbox(d, normalize(vec3(-0.62, 0.69, -0.38)), vec2(0.67, 0.28)) * vec3(2.8, 2.55, 2.28);
	COLOR += softbox(d, normalize(vec3(0.74, 0.38, 0.48)), vec2(0.45, 0.13)) * vec3(0.91, 1.60, 2.38);
	COLOR += softbox(d, normalize(vec3(0.18, 0.80, -0.58)), vec2(0.32, 0.19)) * vec3(0.83, 0.91, 1.0);
}
