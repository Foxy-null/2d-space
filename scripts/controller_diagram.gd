extends Control
## Controller silhouette and binding guides, drawn at the settings panel's scale.
const SHORT_NAMES := ["A / ×", "B / ○", "X / □", "Y / △", "Back / −", "Guide", "Start / +", "L 押込", "R 押込", "L / LB", "R / RB", "十字 上", "十字 下", "十字 左", "十字 右"]
const POINTS := [Vector2(624, 166), Vector2(651, 139), Vector2(597, 139), Vector2(624, 112), Vector2(484, 122), Vector2(520, 105), Vector2(556, 122), Vector2(435, 149), Vector2(572, 224), Vector2(434, 67), Vector2(606, 67), Vector2(483, 207), Vector2(483, 241), Vector2(466, 224), Vector2(500, 224)]
var connections: Array = []
var selected := -1

func highlight(index: int) -> void:
	selected = index
	queue_redraw()

func _draw() -> void:
	var cyan := Color("65e4e9")
	var shell := PackedVector2Array([Vector2(406, 81), Vector2(449, 57), Vector2(591, 57), Vector2(634, 81), Vector2(673, 253), Vector2(661, 290), Vector2(632, 296), Vector2(584, 258), Vector2(456, 258), Vector2(408, 296), Vector2(379, 290), Vector2(367, 253)])
	draw_colored_polygon(shell, Color("29364c"))
	var outline := shell.duplicate()
	outline.append(shell[0])
	draw_polyline(outline, Color("6b819f"), 3, true)
	for center in [Vector2(435, 149), Vector2(572, 224)]:
		draw_circle(center, 30, Color("111c30"))
		draw_arc(center, 30, 0, TAU, 40, Color("6b819f"), 2, true)
	for index in POINTS.size():
		var point: Vector2 = POINTS[index]
		var active := selected == index
		draw_circle(point, 17 if index < 4 else 12, Color("176b80") if active else Color("101a2b"))
		var text: String = ["A", "B", "X", "Y", "−", "○", "+", "L", "R", "LB", "RB", "↑", "↓", "←", "→"][index]
		draw_string(ThemeDB.fallback_font, point + Vector2(-9, 6), text, HORIZONTAL_ALIGNMENT_CENTER, 20, 16, cyan if active else Color.WHITE)
	for connection in connections:
		var start: Vector2 = connection[0]
		var index: int = connection[1]
		var end: Vector2 = POINTS[index]
		var bend := 337.0 if start.x < 520 else 703.0
		var color := cyan if selected == index else Color(0.39, 0.89, 0.91, 0.24)
		draw_polyline(PackedVector2Array([start, Vector2(bend, start.y), Vector2(bend, end.y), end]), color, 3 if selected == index else 1, true)
		draw_circle(end, 4, color)
	draw_string(ThemeDB.fallback_font, Vector2(401, 337), "左スティック：移動  /  トリガー：初期設定", HORIZONTAL_ALIGNMENT_CENTER, 240, 13, Color("a8b8d1"))
