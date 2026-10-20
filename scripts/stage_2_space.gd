extends Starfield


func _draw() -> void:
	super._draw()
	var scale := get_viewport_rect().size / Vector2(1280, 720)
	draw_set_transform(Vector2(44, 300) * scale, -0.35, scale * Vector2(1, 0.36))
	draw_arc(Vector2.ZERO, 70, PI, TAU, 48, ArtDraw.INK, 12, true)
	draw_arc(Vector2.ZERO, 70, PI, TAU, 48, ArtDraw.GOLD, 7, true)
	draw_set_transform(Vector2.ZERO, 0, scale)
	_draw_planet(Vector2(44, 300), 44, ArtDraw.CORAL, Color("cf617b"))
	draw_set_transform(Vector2(44, 300) * scale, -0.35, scale * Vector2(1, 0.36))
	draw_arc(Vector2.ZERO, 70, 0, PI, 48, ArtDraw.INK, 12, true)
	draw_arc(Vector2.ZERO, 70, 0, PI, 48, ArtDraw.GOLD, 7, true)
	draw_set_transform(Vector2.ZERO, 0, scale)
	_draw_planet(Vector2(1242, 490), 52, ArtDraw.CYAN, Color("368fb9"))
	_draw_planet(Vector2(1218, 210), 17, Color("c39ce9"), ArtDraw.VIOLET)
	for star in [Vector3(74, 145, 9), Vector3(29, 480, 7), Vector3(83, 640, 11), Vector3(1238, 120, 8), Vector3(1194, 340, 10), Vector3(1246, 650, 7)]:
		draw_set_transform(Vector2(star.x, star.y) * scale, 0, scale)
		var points := PackedVector2Array()
		for point in 10:
			var angle := -PI / 2 + PI * point / 5
			var radius: float = star.z * (1.9 if point % 2 == 0 else 0.85)
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		ArtDraw.polygon(self, points, ArtDraw.GOLD, 2.5)
		draw_circle(Vector2(-3, -3), 2, ArtDraw.CREAM, true, -1, true)
	draw_set_transform(Vector2.ZERO)


func _draw_planet(center: Vector2, radius: float, body: Color, spots: Color) -> void:
	ArtDraw.ellipse(self, center, Vector2.ONE * radius, body, 3.5)
	for spot in [Vector3(-0.22, 0.2, 0.17), Vector3(0.32, -0.08, 0.12), Vector3(0.12, 0.48, 0.09)]:
		draw_circle(center + Vector2(spot.x, spot.y) * radius, radius * spot.z, spots, true, -1, true)
	draw_arc(center, radius * 0.72, PI * 1.12, PI * 1.55, 20, ArtDraw.CREAM, maxf(2, radius * 0.07), true)
