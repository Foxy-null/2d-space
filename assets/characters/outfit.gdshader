shader_type canvas_item;

uniform vec4 outfit_color : source_color = vec4(0.35, 0.92, 1.0, 1.0);

void fragment() {
	vec4 pixel = COLOR;
	// Indigo fabric has more blue than red/green; skin, eyes and grey gloves do not.
	// ponytail: this mask fits the indigo sprites; paint masks if other blue details are added.
	float fabric = smoothstep(0.06, 0.12, pixel.b - max(pixel.r, pixel.g));
	float shade = clamp(pixel.b * 2.2, 0.0, 1.0);
	pixel.rgb = mix(pixel.rgb, outfit_color.rgb * shade, fabric);
	COLOR = pixel;
}
