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
	float side = step(0.5, UV.x);
	float panel_x = (UV.x - side * (1.0 - 116.0 / 1280.0)) * (1280.0 / 116.0);
	float light_phase = phase * 3.0;
	float source_x = 0.25 + 0.06 * side + 0.025 * sin(light_phase + side * 0.9);
	float from_sun = UV.y + 0.03;
	float slant = (0.52 + 0.07 * sin(light_phase)) * (720.0 / 116.0);
	vec3 beam_offset = vec3(panel_x - source_x - from_sun * slant) + vec3(0.0, 1.5, 3.0);
	vec3 halo = beam_offset / vec3(0.24, 0.22, 0.26);
	halo = exp(-halo * halo);
	vec3 core = beam_offset / vec3(0.075, 0.065, 0.07);
	core = exp(-core * core);
	float light = dot(halo, vec3(1.0, 0.85, 0.65)) * (0.28 + 0.05 * sin(light_phase * 2.0));
	light += dot(core, vec3(1.0, 0.8, 0.6)) * 0.12;
	light *= smoothstep(-0.01, 0.12, UV.y) * (1.0 - 0.4 * UV.y);
	float sun_distance = length(vec2(panel_x - source_x, from_sun * (720.0 / 116.0)));
	float glare = 0.4 * exp(-sun_distance * 3.2);
	COLOR = vec4(mix(sky.rgb, vec3(1.0, 0.98, 0.9), clamp(light + glare, 0.0, 0.78)), sky.a);
}
