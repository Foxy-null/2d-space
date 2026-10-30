shader_type canvas_item;
render_mode unshaded;

uniform float phase : hint_range(0.0, 6.2831853) = 0.0;
uniform float aspect = 3.0;
uniform vec4 vortices[4];

vec2 wave(vec2 uv) {
	return uv + vec2(
		0.006 * sin(uv.y * 17.0 + phase) * cos(uv.x * 13.0 - phase),
		0.010 * sin(uv.x * 18.0 - phase) + 0.005 * sin(uv.x * 37.0 + 2.0 * phase)
	);
}

void fragment() {
	vec2 uv = wave(UV);
	vec4 base = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	vec3 shade = base.rgb;
	for (int i = 0; i < 4; i++) {
		vec4 vortex = vortices[i];
		vec2 p = (uv - vortex.xy) * vec2(aspect, 1.0);
		float influence = 1.0 - smoothstep(vortex.z * 0.35, vortex.z, length(p));
		float turn = phase * vortex.w + 0.22 * sin(phase) * influence;
		float c = cos(turn);
		float s = sin(turn);
		vec2 spun = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
		vec2 at = vortex.xy + spun / vec2(aspect, 1.0);
		vec4 rolling = texture(TEXTURE, clamp(wave(at), vec2(0.0), vec2(1.0)));
		shade = mix(shade, rolling.rgb, influence * 0.98 * rolling.a * base.a);
	}
	COLOR = vec4(shade, base.a);
}
