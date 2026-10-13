@tool
class_name TerrainArt
extends Polygon2D

@export_enum("宇宙基地", "生活圏", "未開発", "溶岩", "邪悪なオーラ") var environment_theme := 0:
	set(value):
		environment_theme = value
		color = ArtDraw.support_color(value)
		queue_redraw()


func _ready() -> void:
	environment_theme = ArtDraw.environment(self)


func _draw() -> void:
	if polygon.size() < 3:
		return
	var rect := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		rect = rect.expand(point)
	var cap: Color = [ArtDraw.CREAM, Color("b5cba0"), Color("d0b9a7"), Color("aba09a"), Color("b4a6bf")][clampi(environment_theme, 0, 4)]
	# Every contact edge stays at the existing collider, including ceiling walking.
	draw_rect(rect, color)
	var edge := minf(5, minf(rect.size.x, rect.size.y) * 0.18)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, edge)), cap)
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - edge), Vector2(rect.size.x, edge)), cap.darkened(0.12))
	draw_rect(Rect2(rect.position, Vector2(2, rect.size.y)), cap)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 2, 0), Vector2(2, rect.size.y)), cap.darkened(0.12))
	var outline := polygon.duplicate()
	outline.append(polygon[0])
	draw_polyline(outline, ArtDraw.INK, 2.5, true)
	if get_parent().name == "ExitBarrier":
		for y in range(int(rect.position.y + 32), int(rect.end.y), 72):
			draw_line(Vector2(rect.position.x + 4, y), Vector2(rect.end.x - 4, y), ArtDraw.INK, 2, true)
		ArtDraw.footprints(self, rect.get_center(), 0.6)
		return
	if minf(rect.size.x, rect.size.y) < 24:
		return
	var count := clampi(int(maxf(rect.size.x, rect.size.y) / 140), 1, 10)
	for i in count:
		var p := rect.position + rect.size * Vector2(float(i + 1) / (count + 1) if rect.size.x >= rect.size.y else 0.5, 0.5 if rect.size.x >= rect.size.y else float(i + 1) / (count + 1))
		if environment_theme == 0 or get_parent().name == "ReturnBridge":
			draw_circle(p, 3, ArtDraw.INK)
			draw_circle(p + Vector2(-0.5, -0.5), 1.3, cap)
			if rect.size.x > 150:
				draw_line(Vector2(p.x - 25, rect.position.y + 8), Vector2(p.x - 25, rect.end.y - 8), color.darkened(0.2), 1.5, true)
		else:
			var length := minf(10 + (i % 3) * 4, minf(rect.size.x, rect.size.y) * 0.2)
			var mark := Color("ed9260") if environment_theme == 3 else (Color("936fa9") if environment_theme == 4 else color.darkened(0.18))
			draw_polyline(PackedVector2Array([p - Vector2(length, length * (0.4 if i % 2 == 0 else -0.6)), p + Vector2(-3, 0), p + Vector2(4, -1), p + Vector2(length, length * 0.6)]), mark, 1.7, true)
	if environment_theme == 1 and rect.size.x > 65:
		for x in range(int(rect.position.x + 15), int(rect.end.x - 12), 48):
			draw_circle(Vector2(x, rect.position.y + 6), 4, cap)
			draw_circle(Vector2(x + 5, rect.position.y + 7), 3, cap)
