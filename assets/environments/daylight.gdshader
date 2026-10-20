shader_type canvas_item;

uniform float elapsed = 0.0;

void fragment() {
	float phase = elapsed * 6.283185 / 60.0;
	// Overscan keeps the drifting image edges outside the viewport.
	vec2 uv = UV * 0.96 + vec2(0.02);
	uv.x += 0.016 * sin(phase) * (0.6 + 0.4 * UV.y);
	uv.y += 0.002 * sin(phase * 2.0 + UV.x * 4.0);
	vec4 sky = texture(TEXTURE, uv);
	// Keep the sun and its shafts inside each 116px strip beside the tower.
	float panel_x = min(UV.x, 1.0 - UV.x) * (1280.0 / 116.0);
	float side = step(0.5, UV.x);
	float source_x = 0.25 + 0.06 * side + 0.025 * sin(phase + side * 0.9);
	float from_sun = UV.y + 0.03;
	vec2 beam_offset = vec2(panel_x - source_x) - from_sun * vec2(0.55, 0.16);
	vec2 halo = beam_offset / vec2(0.24, 0.18);
	halo = exp(-halo * halo);
	vec2 core = beam_offset / vec2(0.075, 0.055);
	core = exp(-core * core);
	float light = dot(halo, vec2(1.0, 0.65)) * (0.23 + 0.04 * sin(phase * 2.0));
	light += dot(core, vec2(1.0, 0.55)) * 0.12;
	light *= smoothstep(-0.01, 0.12, UV.y) * (1.0 - 0.4 * UV.y);
	float sun_distance = length(vec2(panel_x - source_x, from_sun * (720.0 / 116.0)));
	float glare = 0.4 * exp(-sun_distance * 3.2);
	COLOR = vec4(mix(sky.rgb, vec3(1.0, 0.98, 0.9), clamp(light + glare, 0.0, 0.78)), sky.a);
}
