shader_type canvas_item;

uniform sampler2D original_atlas : source_color, filter_linear;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 pixel = UV * vec2(487.0, 311.0);
	vec4 original = texture(original_atlas, (vec2(1022.0, 128.0) + pixel) / vec2(1536.0, 1024.0));
	vec4 edited = texture(TEXTURE, UV);
	// Blend continuously into the reflection-free bottom, keeping the frame opaque.
	float bottom = smoothstep(230.0, 252.0, pixel.y);
	float pane = smoothstep(48.0, 65.0, pixel.x)
		* (1.0 - smoothstep(424.0, 439.0, pixel.x))
		* (1.0 - smoothstep(287.0, 296.0, pixel.y));
	float alpha = mix(original.a, min(original.a, 0.30), bottom * pane);
	COLOR = vec4(mix(original.rgb, edited.rgb, bottom), alpha) * tint;
}
