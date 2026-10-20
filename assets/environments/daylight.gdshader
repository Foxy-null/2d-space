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
	vec2 beam_offset = vec2(diagonal + 0.04 - 0.02 * sin(phase), diagonal - 0.79 - 0.015 * sin(phase + 1.0));
	vec2 halo = beam_offset / vec2(0.095, 0.125);
	halo = exp(-halo * halo);
	vec2 core = beam_offset / vec2(0.024, 0.034);
	core = exp(-core * core);
	float light = dot(halo, vec2(1.0, 0.85)) * (0.28 + 0.045 * sin(phase * 2.0));
	light += dot(core, vec2(1.0, 0.8)) * 0.25;
	float glare = 0.3 * exp(-length((UV - vec2(0.14, 0.0)) * vec2(1.0, 1.5)) * 8.0);
	COLOR = vec4(mix(sky.rgb, vec3(1.0, 0.98, 0.92), clamp(light + glare, 0.0, 0.65)), sky.a);
}
