class_name TowerLandscape
extends Node2D

const SIZES := [Vector2(1280, 720), Vector2(1280, 800), Vector2(1800, 900), Vector2(1600, 1500), Vector2(2200, 1000), Vector2(2400, 1100), Vector2(1600, 800), Vector2(1500, 800), Vector2(1600, 900), Vector2(2200, 1000)]
const HEIGHTS := [0.0, -800.0, -1700.0, -2300.0, -3300.0, -3420.0, -4220.0, -1640.0, -1720.0, -2800.0]
const TITLES := ["ふもと", "バネと壁キック", "トゲの向こうへ", "崩れる足場", "星空の回廊", "バネをつないで", "ロケット", "回復の寄り道", "薄板の寄り道", "バンパーの寄り道"]
const SCROLLS := {1: Vector2(900, 194), 7: Vector2(220, 340), 8: Vector2(1460, 154), 9: Vector2(1970, 382)}
const SCROLL_IDS := {1: "spring_alcove", 7: "crystal_cavern", 8: "crumbling_cavern", 9: "bumper_cavern"}
# Each connection contains its two exit volumes and safe return positions.
const CONNECTIONS := [
	[0, Rect2(1050, -48, 198, 80), Vector2(1120, 154), 1, Rect2(50, 760, 140, 88), Vector2(260, 714)],
	[1, Rect2(1040, -48, 208, 80), Vector2(1150, 114), 2, Rect2(210, 860, 100, 88), Vector2(350, 834)],
	[2, Rect2(1768, 680, 80, 180), Vector2(1690, 834), 3, Rect2(-48, 1180, 80, 200), Vector2(110, 1294)],
	[3, Rect2(800, -48, 600, 80), Vector2(1140, 134), 4, Rect2(90, 960, 120, 88), Vector2(300, 914)],
	[4, Rect2(2168, 650, 80, 300), Vector2(2100, 694), 5, Rect2(-48, 650, 80, 260), Vector2(110, 814)],
	[5, Rect2(2140, -48, 228, 80), Vector2(2240, 274), 6, Rect2(60, 760, 140, 88), Vector2(280, 634)],
	[2, Rect2(-48, 680, 80, 180), Vector2(120, 834), 7, Rect2(1468, 600, 80, 180), Vector2(1390, 714)],
	[3, Rect2(1568, 1180, 80, 200), Vector2(1490, 1354), 8, Rect2(-48, 600, 80, 230), Vector2(120, 714)],
	[5, Rect2(2368, 800, 80, 250), Vector2(2270, 894), 9, Rect2(-48, 180, 80, 200), Vector2(140, 274)],
]
const SOIL := Color("999a9d")
const INK := Color("30343e")
const ROCKET := preload("res://assets/tutorial/rocket.png")
var room_index := 0


static func origin(index: int) -> Vector2:
	return Vector2(index * 6000.0, HEIGHTS[index])


static func _polygon(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(0, points.size(), 2):
		result.append(Vector2(points[i], points[i + 1]))
	return result


static func landforms(index: int) -> Array[PackedVector2Array]:
	var rectangles: Array[Rect2] = []
	var polygons: Array[PackedVector2Array] = []
	match index:
		0:
			rectangles = [Rect2(0, 0, 1040, 48), Rect2(0, 0, 48, 720), Rect2(0, 640, 290, 80), Rect2(290, 540, 170, 180), Rect2(530, 390, 150, 330), Rect2(1248, 0, 32, 720)]
			polygons.append(_polygon([920, 720, 920, 450, 1000, 450, 1000, 300, 1060, 300, 1060, 180, 1248, 180, 1248, 720]))
		1:
			rectangles = [Rect2(0, 0, 1040, 48), Rect2(0, 0, 48, 760), Rect2(1248, 0, 32, 800), Rect2(220, 740, 210, 60), Rect2(430, 540, 170, 260), Rect2(600, 780, 190, 20), Rect2(790, 640, 490, 160), Rect2(450, 48, 200, 210), Rect2(880, 220, 180, 24), Rect2(1000, 140, 248, 24), Rect2(340, 650, 90, 14)]
		2:
			rectangles = [Rect2(0, 0, 1800, 48), Rect2(0, 48, 48, 632), Rect2(1768, 48, 32, 632), Rect2(0, 860, 210, 40), Rect2(310, 860, 1490, 40), Rect2(650, 430, 240, 430), Rect2(500, 530, 110, 16), Rect2(1200, 48, 220, 430), Rect2(1490, 650, 310, 30)]
		3:
			rectangles = [Rect2(0, 0, 800, 48), Rect2(1400, 0, 200, 48), Rect2(0, 48, 48, 1132), Rect2(1568, 48, 32, 1132), Rect2(0, 1320, 210, 180), Rect2(440, 1100, 170, 400), Rect2(610, 1320, 240, 180), Rect2(850, 1400, 260, 100), Rect2(1110, 1460, 490, 40), Rect2(1420, 1380, 180, 120), Rect2(1040, 160, 300, 24)]
			polygons.append(_polygon([48, 48, 800, 48, 800, 120, 600, 120, 600, 260, 430, 260, 430, 430, 280, 430, 280, 720, 48, 720]))
		4:
			rectangles = [Rect2(0, 0, 2200, 48), Rect2(0, 0, 48, 960), Rect2(0, 940, 90, 60), Rect2(210, 940, 340, 60), Rect2(550, 800, 270, 200), Rect2(820, 960, 360, 40), Rect2(1180, 870, 570, 130), Rect2(1750, 720, 450, 280), Rect2(2168, 0, 32, 650), Rect2(980, 360, 90, 210), Rect2(1500, 180, 90, 190), Rect2(1840, 48, 328, 160), Rect2(2050, 208, 118, 90)]
		5:
			rectangles = [Rect2(0, 0, 2140, 48), Rect2(2368, 0, 32, 800), Rect2(0, 48, 48, 602), Rect2(0, 840, 230, 260), Rect2(480, 840, 120, 260), Rect2(880, 700, 130, 400), Rect2(1180, 820, 120, 280), Rect2(1540, 470, 130, 630), Rect2(800, 48, 160, 210), Rect2(2150, 920, 250, 180), Rect2(1740, 300, 628, 24)]
		6:
			rectangles = [Rect2(0, 0, 1600, 40), Rect2(0, 0, 40, 760), Rect2(1560, 0, 40, 800), Rect2(0, 740, 60, 60), Rect2(200, 660, 1400, 140)]
		7:
			rectangles = [Rect2(0, 0, 1500, 48), Rect2(0, 0, 48, 800), Rect2(1468, 48, 32, 552), Rect2(48, 430, 170, 24), Rect2(1250, 740, 250, 60), Rect2(0, 780, 1250, 20)]
		8:
			rectangles = [Rect2(0, 740, 230, 160), Rect2(620, 680, 190, 220), Rect2(1110, 500, 180, 400), Rect2(1380, 220, 220, 680), Rect2(620, 0, 190, 350), Rect2(1120, 0, 180, 90), Rect2(0, 0, 48, 600), Rect2(1552, 0, 48, 220)]
		9:
			rectangles = [Rect2(0, 0, 2200, 48), Rect2(0, 48, 48, 132), Rect2(0, 300, 220, 700), Rect2(220, 620, 220, 380), Rect2(440, 700, 160, 300), Rect2(1100, 900, 180, 16), Rect2(520, 470, 110, 16), Rect2(600, 700, 120, 16), Rect2(1760, 430, 440, 24), Rect2(2168, 48, 32, 952), Rect2(1340, 48, 160, 230), Rect2(1720, 48, 448, 120)]
			polygons.append(_polygon([900, 280, 1260, 280, 1260, 440, 1140, 440, 1140, 560, 1030, 560, 1030, 680, 900, 680]))
	for rect in rectangles:
		polygons.append(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]))
	return polygons


static func spikes(index: int) -> Array[Vector4]:
	match index:
		0: return [Vector4(150, 640, 120, 1), Vector4(460, 700, 70, 1)]
		1: return [Vector4(450, 540, 130, 1), Vector4(620, 780, 150, 1), Vector4(470, 258, 160, -1)]
		2: return [Vector4(670, 430, 180, 1)]
		3: return [Vector4(850, 1400, 240, 1), Vector4(1110, 1460, 300, 1)]
		4: return [Vector4(820, 960, 360, 1), Vector4(1340, 870, 410, 1), Vector4(980, 360, 90, 1), Vector4(980, 570, 90, -1), Vector4(1500, 180, 90, 1)]
		5: return [Vector4(880, 700, 130, 1), Vector4(1540, 470, 130, 1), Vector4(800, 258, 160, -1)]
		7: return [Vector4(48, 780, 1202, 1)]
		8: return [Vector4(620, 680, 190, 1), Vector4(1110, 500, 180, 1), Vector4(620, 350, 190, -1), Vector4(1120, 90, 180, -1)]
		9: return [Vector4(250, 620, 160, 1), Vector4(460, 700, 120, 1)]
	return []


static func spike_triangles(index: int) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for strip in spikes(index):
		for x in range(int(strip.x), int(strip.x + strip.z), 20):
			result.append(PackedVector2Array([Vector2(x, strip.y), Vector2(x + 10, strip.y - strip.w * 22), Vector2(x + 20, strip.y)]))
	return result


static func planks(index: int) -> Array[Rect2]:
	match index:
		3: return [Rect2(680, 900, 180, 16), Rect2(1050, 620, 180, 16)]
		5: return [Rect2(1860, 840, 180, 16)]
		8: return [Rect2(350, 740, 120, 16), Rect2(920, 740, 120, 16)]
	return []


static func springs(index: int) -> Array[Vector3]:
	match index:
		1: return [Vector3(1080, 640, 1450)]
		5: return [Vector3(540, 840, 1200), Vector3(1240, 820, 1550)]
	return []


static func crystals(index: int) -> Array[Vector2]:
	match index:
		2: return [Vector2(1020, 380)]
		7: return [Vector2(650, 440), Vector2(1000, 500)]
		8: return [Vector2(1000, 240)]
	return []


func _draw() -> void:
	for polygon in landforms(room_index):
		draw_colored_polygon(polygon, SOIL)
		var border := polygon.duplicate()
		border.append(polygon[0])
		draw_polyline(border, INK, 3, true)
	for triangle in spike_triangles(room_index):
		draw_colored_polygon(triangle, Color("f3efdf"))
		var border := triangle.duplicate()
		border.append(triangle[0])
		draw_polyline(border, INK, 2, true)
	if room_index == 6:
		draw_texture_rect(ROCKET, Rect2(1200, 430, 144, 230), false)
