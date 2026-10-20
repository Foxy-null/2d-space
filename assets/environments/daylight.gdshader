shader_type canvas_item;

uniform float elapsed = 0.0;

void fragment() {
	float phase = elapsed * 6.283185 / 60.0;
	// Overscan keeps the drifting image edges outside the viewport.
	vec2 uv = UV * 0.96 + vec2(0.02);
	uv.x += 0.016 * sin(phase) * (0.6 + 0.4 * UV.y);
	uv.y += 0.002 * sin(phase * 2.0 + UV.x * 4.0);
	vec4 sky = texture(TEXTURE, uv);
	float diagonal = UV.x - UV.y * 0.24;
	float left_ray = exp(-pow(abs((diagonal + 0.04 - 0.02 * sin(phase)) / 0.07), 2.0));
	float right_ray = exp(-pow(abs((diagonal - 0.79 - 0.015 * sin(phase + 1.0)) / 0.1), 2.0));
	float light = (left_ray + right_ray * 0.65) * (0.065 + 0.025 * sin(phase * 2.0));
	COLOR = vec4(mix(sky.rgb, vec3(1.0, 0.98, 0.92), light), sky.a);
}
