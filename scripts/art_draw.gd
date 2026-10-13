class_name ArtDraw
extends RefCounted

const INK := Color("242235")
const CREAM := Color("eee5ce")
const GOLD := Color("efc45f")
const CORAL := Color("fa765f")
const CYAN := Color("35cce0")
const MINT := Color("a9edbb")
const VIOLET := Color("9367c4")


static func polygon(canvas: CanvasItem, points: PackedVector2Array, fill: Color, width: float = 2.5) -> void:
	canvas.draw_colored_polygon(points, fill)
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, INK, width, true)


static func box(canvas: CanvasItem, rect: Rect2, fill: Color, radius: int = 3) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = INK
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	canvas.draw_style_box(style, rect)


static func ellipse(canvas: CanvasItem, center: Vector2, radius: Vector2, fill: Color, width: float = 2.5) -> void:
	var points := PackedVector2Array()
	for i in 40:
		points.append(center + Vector2(cos(TAU * i / 40), sin(TAU * i / 40)) * radius)
	polygon(canvas, points, fill, width)


static func arrow(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color, width: float = 3.5) -> void:
	var direction := (end - start).normalized()
	canvas.draw_line(start, end, color, width, true)
	canvas.draw_polyline(PackedVector2Array([end - direction.rotated(0.7) * 9, end, end - direction.rotated(-0.7) * 9]), color, width, true)


static func dash(canvas: CanvasItem) -> void:
	ellipse(canvas, Vector2.ZERO, Vector2(24, 16), MINT)
	for x in [-6.0, 6.0]:
		canvas.draw_polyline(PackedVector2Array([Vector2(x - 5, -7), Vector2(x + 2, 0), Vector2(x - 5, 7)]), Color("255942"), 4, true)
	for y in [-9.0, 9.0]:
		canvas.draw_line(Vector2(-32, y), Vector2(-26, y), MINT, 2, true)


static func boot(canvas: CanvasItem) -> void:
	var shape := PackedVector2Array([Vector2(-22, 3), Vector2(-19, -3), Vector2(-6, -5), Vector2(-4, -24), Vector2(16, -23), Vector2(13, 7), Vector2(8, 13), Vector2(-19, 12)])
	var halo := shape.duplicate()
	halo.append(shape[0])
	canvas.draw_polyline(halo, CREAM, 5.5, true)
	polygon(canvas, shape, VIOLET)
	canvas.draw_line(Vector2(-4, -19), Vector2(15, -18), INK, 2, true)
	box(canvas, Rect2(-1, -12, 6, 7), CREAM, 1)
	canvas.draw_line(Vector2(-19, 12), Vector2(8, 13), CREAM, 3, true)
	canvas.draw_polyline(PackedVector2Array([Vector2(-9, 17), Vector2(4, 19), Vector2(-8, 22), Vector2(3, 25)]), INK, 4, true)
	canvas.draw_polyline(PackedVector2Array([Vector2(-9, 17), Vector2(4, 19), Vector2(-8, 22), Vector2(3, 25)]), Color("b7b8c0"), 2, true)


static func footprints(canvas: CanvasItem, center: Vector2, scale: float = 1.0) -> void:
	for side in [-1.0, 1.0]:
		var p := center + Vector2(side * 10, 0) * scale
		canvas.draw_circle(p + Vector2(0, -4) * scale, 5 * scale, INK)
		canvas.draw_circle(p + Vector2(-side, 6) * scale, 3 * scale, INK)


static func cube_mark(canvas: CanvasItem, center: Vector2, scale: float = 1.0) -> void:
	var points := PackedVector2Array()
	for p in [Vector2(0, -6), Vector2(7, -2), Vector2(7, 6), Vector2(0, 10), Vector2(-7, 6), Vector2(-7, -2)]:
		points.append(center + p * scale)
	polygon(canvas, points, CREAM, 1.5)
	canvas.draw_line(center, center + Vector2(0, 9) * scale, INK, 1.5, true)
	canvas.draw_polyline(PackedVector2Array([center + Vector2(-7, -2) * scale, center, center + Vector2(7, -2) * scale]), INK, 1.5, true)


static func environment(node: Node) -> int:
	var parent := node
	while parent != null:
		if parent.has_meta("environment_theme"):
			return int(parent.get_meta("environment_theme"))
		parent = parent.get_parent()
	return 0


static func support_color(theme: int) -> Color:
	return [Color("bdb6ab"), Color("a78a6e"), Color("a88b83"), Color("514b54"), Color("51495f")][clampi(theme, 0, 4)]
