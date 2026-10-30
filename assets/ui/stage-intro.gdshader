shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size;
uniform vec2 center;
uniform float radius;

void fragment() {
	float distance_from_player = distance(UV * viewport_size, center);
	COLOR = vec4(0.0, 0.0, 0.0, radius <= 0.0 ? 1.0 : smoothstep(radius - 1.0, radius + 1.0, distance_from_player));
}
