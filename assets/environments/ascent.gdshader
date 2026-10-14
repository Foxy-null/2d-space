shader_type canvas_item;

uniform float elapsed = 0.0;

void fragment() {
	vec2 uv = UV;
	uv.x += 0.0012 * sin(elapsed * 6.283185 / 30.0);
	COLOR = texture(TEXTURE, clamp(uv, vec2(0.001), vec2(0.999)));
	COLOR.a *= smoothstep(0.0, 0.22, UV.y);
}
