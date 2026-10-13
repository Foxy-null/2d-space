shader_type canvas_item;

uniform float elapsed = 0.0;
uniform int environment_theme = 0;

void fragment() {
	vec2 uv = UV;
	if (environment_theme == 3) {
		float lava = smoothstep(0.68, 0.82, uv.y);
		uv.x += lava * 0.003 * sin(uv.y * 30.0 + elapsed * 6.283185 / 12.0);
		uv.y += lava * 0.002 * sin(uv.x * 24.0 + elapsed * 6.283185 / 10.0);
		uv.x += (1.0 - smoothstep(0.2, 0.45, uv.y)) * 0.0015 * sin(elapsed * 6.283185 / 24.0);
	} else if (environment_theme == 4) {
		float mist = smoothstep(0.5, 0.85, uv.y);
		uv.x += mist * 0.004 * sin(uv.y * 16.0 + elapsed * 6.283185 / 20.0);
		uv.y += 0.002 * sin(uv.x * 12.0 + elapsed * 6.283185 / 30.0);
	} else {
		uv.x += (1.0 - smoothstep(0.25, 0.5, uv.y)) * 0.0012 * sin(elapsed * 6.283185 / 30.0);
	}
	COLOR = texture(TEXTURE, clamp(uv, vec2(0.001), vec2(0.999)));
}
