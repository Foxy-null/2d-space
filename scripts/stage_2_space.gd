extends Starfield


func _draw() -> void:
	super._draw()
	var scale := get_viewport_rect().size / Vector2(1280, 720)
	var ring_color := Color("d6ba9a")
	draw_set_transform(Vector2(44, 300) * scale, -0.35, scale * Vector2(1, 0.36))
	draw_arc(Vector2.ZERO, 70, PI, TAU, 48, ring_color.darkened(0.3), 7, true)
	draw_set_transform(Vector2.ZERO, 0, scale)
	_draw_planet(Vector2(44, 300), 44, Color("805880"), Color("edc49a"))
	draw_set_transform(Vector2(44, 300) * scale, -0.35, scale * Vector2(1, 0.36))
	draw_arc(Vector2.ZERO, 70, 0, PI, 48, ring_color, 7, true)
	draw_set_transform(Vector2.ZERO, 0, scale)
	_draw_planet(Vector2(1242, 490), 52, Color("305590"), Color("a4dfef"))
	_draw_planet(Vector2(1218, 210), 17, Color("68508c"), Color("cbb3e0"))
	for star in [Vector3(74, 145, 9), Vector3(29, 480, 7), Vector3(83, 640, 11), Vector3(1238, 120, 8), Vector3(1194, 340, 10), Vector3(1246, 650, 7)]:
		draw_set_transform(Vector2(star.x, star.y) * scale, 0, scale)
		for glow in [3.0, 2.0, 1.2]:
			draw_circle(Vector2.ZERO, star.z * glow, Color(0.65, 0.8, 1, 0.05), true, -1, true)
		var flare := PackedVector2Array([
			Vector2(0, -star.z), Vector2(2, -2), Vector2(star.z * 0.7, 0), Vector2(2, 2),
			Vector2(0, star.z), Vector2(-2, 2), Vector2(-star.z * 0.7, 0), Vector2(-2, -2),
		])
		draw_colored_polygon(flare, Color("f5ecd4"))
		draw_circle(Vector2.ZERO, 2, Color.WHITE, true, -1, true)
	draw_set_transform(Vector2.ZERO)


func _draw_planet(center: Vector2, radius: float, shadow: Color, light: Color) -> void:
	draw_circle(center, radius + 10, Color(light, 0.06), true, -1, true)
	draw_circle(center, radius + 4, Color(light, 0.12), true, -1, true)
	for layer in range(32, 0, -1):
		var fraction := layer / 32.0
		var highlight := center - Vector2.ONE * radius * (1 - fraction) * 0.28
		draw_circle(highlight, radius * fraction, shadow.lerp(light, 1 - fraction), true, -1, true)
