class_name TowerLandscape
extends Node2D

# Coordinates follow the original 2394 × 999 drawing; every room uses one scale.
const SCALE := 1.7
const ACTOR_SCALE := 0.65
const PLAYER_HALF_HEIGHT := 26 * ACTOR_SCALE
const REFERENCE_BOUNDS := [Rect2(73, 864, 215, 103), Rect2(264, 737, 178, 104), Rect2(368, 568, 276, 140), Rect2(689, 449, 277, 256), Rect2(816, 206, 423, 189), Rect2(1281, 207, 423, 189), Rect2(1649, 32, 271, 138), Rect2(127, 605, 216, 103), Rect2(1001, 565, 276, 140), Rect2(1736, 329, 423, 191)]
const TITLES := ["ふもと", "バネと壁キック", "トゲの向こうへ", "崩れる足場", "星空の回廊", "バネをつないで", "ロケット", "回復の寄り道", "薄板の寄り道", "バンパーの寄り道"]
const SCROLLS := {1: Vector2(124, 23) * SCALE, 7: Vector2(16, 32) * SCALE, 8: Vector2(250, 44) * SCALE, 9: Vector2(350, 56) * SCALE}
const SCROLL_IDS := {1: "spring_alcove", 7: "crystal_cavern", 8: "crumbling_cavern", 9: "bumper_cavern"}
const BUMPER := Vector2(227.5, 140.5) * SCALE
const ROCKET_RECT := Rect2(Vector2(204, 49) * SCALE, Vector2(45, 66) * SCALE)
const ROCKET_APPROACH := 185 * SCALE
const ROCKET_DOOR := 227 * SCALE
const SOIL := Color("999a9d")
const INK := Color("30343e")
const ROCKET := preload("res://assets/tutorial/rocket.png")
var room_index := 0


static func size(index: int) -> Vector2:
	return REFERENCE_BOUNDS[index].size * SCALE


static func origin(index: int) -> Vector2:
	return Vector2(index * 6000.0, (REFERENCE_BOUNDS[index].position.y - REFERENCE_BOUNDS[0].position.y) * SCALE)


static func foothold(x: float, y: float) -> Vector2:
	return Vector2(x, y) * SCALE - Vector2(0, PLAYER_HALF_HEIGHT)


static func start() -> Vector2:
	return foothold(13, 90)


static func connections() -> Array:
	# Footholds are permanent floors; returning from E lands on D's central mass.
	var links := [
		[0, Rect2(178, -16, 37, 28), Vector2(190, 37), 1, Rect2(7, 102, 17, 25), Vector2(30, 92)],
		[1, Rect2(149, -16, 29, 28), Vector2(128, 32), 2, Rect2(43, 138, 30, 25), Vector2(83, 127)],
		[2, Rect2(274, 81, 27, 46), Vector2(255, 104), 3, Rect2(-25, 181, 27, 43), Vector2(15, 224)],
		[3, Rect2(135, -16, 108, 28), Vector2(113, 194), 4, Rect2(16, 187, 98, 25), Vector2(70, 173)],
		[4, Rect2(421, 67, 27, 104), Vector2(390, 132), 5, Rect2(-25, 68, 27, 69), Vector2(18, 137)],
		[5, Rect2(380, -16, 36, 28), Vector2(394, 138), 6, Rect2(12, 136, 44, 25), Vector2(70, 116)],
		[2, Rect2(-25, 105, 27, 22), Vector2(22, 127), 7, Rect2(214, 65, 27, 25), Vector2(190, 90)],
		[3, Rect2(275, 170, 27, 48), Vector2(270, 218), 8, Rect2(-25, 64, 27, 38), Vector2(16, 102)],
		[5, Rect2(421, 150, 27, 29), Vector2(400, 179), 9, Rect2(-25, 25, 27, 34), Vector2(55, 60)],
	]
	for link in links:
		for side in [0, 3]:
			var exit: Rect2 = link[side + 1]
			link[side + 1] = Rect2(exit.position * SCALE, exit.size * SCALE)
			link[side + 2] = link[side + 2] * SCALE - Vector2(0, PLAYER_HALF_HEIGHT)
	return links


static func _polygon(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(0, points.size(), 2):
		result.append(Vector2(points[i], points[i + 1]) * SCALE)
	return result


static func landforms(index: int) -> Array[PackedVector2Array]:
	var rectangles: Array[Rect2] = []
	var polygons: Array[PackedVector2Array] = []
	match index:
		0:
			polygons.append(_polygon([0, 0, 178, 0, 178, 12, 106, 13, 47, 8, 43, 20, 8, 25, 7, 90, 18, 90, 18, 103, 0, 103]))
			polygons.append(_polygon([215, 27, 202, 27, 200, 37, 173, 37, 173, 51, 185, 51, 185, 70, 198, 70, 198, 103, 215, 103]))
			rectangles = [Rect2(49, 76, 26, 27), Rect2(93, 48, 23, 55)]
		1:
			polygons.append(_polygon([0, 0, 85, 0, 85, 36, 60, 36, 60, 24, 51, 24, 51, 13, 18, 12, 18, 29, 7, 30, 7, 92, 0, 92]))
			polygons.append(_polygon([24, 92, 36, 92, 36, 84, 44, 84, 44, 104, 24, 104]))
			polygons.append(_polygon([59, 73, 85, 73, 85, 95, 109, 95, 109, 83, 132, 83, 132, 70, 178, 70, 178, 104, 59, 104]))
			polygons.append(_polygon([139, 0, 148, 0, 148, 39, 120, 39, 120, 32, 139, 32]))
		2:
			polygons.append(_polygon([0, 0, 276, 0, 276, 56, 220, 56, 217, 80, 183, 79, 183, 9, 35, 9, 27, 97, 44, 98, 44, 105, 0, 105]))
			polygons.append(_polygon([73, 80, 94, 80, 94, 73, 150, 73, 151, 140, 73, 140, 73, 127, 94, 127, 94, 85, 73, 85]))
			rectangles = [Rect2(0, 127, 43, 13), Rect2(235, 104, 41, 36), Rect2(211, 120, 24, 3)]
		3:
			polygons.append(_polygon([0, 0, 135, 0, 134, 21, 101, 23, 100, 41, 68, 42, 66, 60, 46, 61, 45, 123, 11, 126, 10, 181, 0, 183]))
			polygons.append(_polygon([246, 0, 277, 0, 277, 171, 265, 173, 263, 81, 257, 81, 256, 26, 244, 24]))
			polygons.append(_polygon([0, 224, 32, 221, 36, 224, 36, 235, 23, 239, 23, 256, 0, 256]))
			polygons.append(_polygon([89, 194, 139, 194, 146, 220, 190, 220, 190, 230, 263, 230, 265, 218, 277, 218, 277, 256, 89, 256]))
			rectangles = [Rect2(62, 201, 27, 3)]
		4:
			polygons.append(_polygon([0, 0, 423, 0, 423, 68, 398, 67, 396, 52, 357, 52, 357, 11, 18, 11, 17, 189, 0, 189]))
			polygons.append(_polygon([115, 152, 161, 151, 161, 180, 248, 180, 248, 167, 340, 167, 342, 135, 390, 132, 423, 134, 423, 189, 115, 189]))
			rectangles = [Rect2(17, 173, 98, 3), Rect2(187, 83, 17, 45), Rect2(282, 51, 17, 37)]
		5:
			polygons.append(_polygon([0, 0, 385, 0, 385, 8, 380, 8, 375, 106, 365, 107, 371, 11, 165, 9, 160, 9, 160, 45, 136, 45, 136, 8, 12, 9, 10, 69, 0, 69]))
			polygons.append(_polygon([416, 0, 423, 0, 423, 151, 380, 144, 380, 138, 412, 138, 416, 89]))
			polygons.append(_polygon([234, 189, 242, 77, 264, 77, 253, 189]))
			rectangles = [Rect2(0, 137, 38, 52), Rect2(72, 134, 22, 55), Rect2(133, 114, 24, 75), Rect2(188, 132, 22, 57), Rect2(379, 179, 44, 10)]
		6:
			polygons.append(_polygon([0, 118, 12, 118, 12, 138, 0, 138]))
			polygons.append(_polygon([56, 116, 96, 116, 125, 110, 162, 110, 203, 115, 271, 116, 271, 138, 56, 138]))
		7:
			polygons.append(_polygon([0, 0, 216, 0, 216, 65, 196, 66, 193, 7, 7, 7, 7, 91, 0, 91]))
			rectangles = [Rect2(5, 53, 34, 9), Rect2(164, 90, 52, 13)]
		8:
			polygons.append(_polygon([0, 102, 43, 102, 43, 114, 31, 114, 30, 140, 0, 140]))
			rectangles = [Rect2(108, 96, 38, 44), Rect2(194, 64, 36, 76), Rect2(244, 69, 32, 71), Rect2(108, 0, 36, 54), Rect2(198, 0, 32, 14)]
		9:
			polygons.append(_polygon([0, 0, 423, 0, 423, 191, 412, 191, 412, 169, 404, 163, 404, 145, 383, 143, 382, 104, 359, 101, 355, 92, 327, 90, 327, 79, 399, 79, 402, 28, 360, 28, 359, 39, 322, 37, 319, 12, 304, 12, 302, 18, 286, 17, 289, 61, 252, 61, 252, 19, 243, 12, 188, 11, 187, 20, 114, 22, 85, 20, 85, 11, 29, 9, 25, 25, 0, 25]))
			polygons.append(_polygon([0, 59, 30, 58, 36, 68, 36, 128, 75, 128, 75, 108, 103, 108, 103, 191, 0, 191]))
			polygons.append(_polygon([132, 50, 149, 44, 201, 44, 201, 84, 180, 84, 177, 102, 161, 108, 161, 124, 154, 128, 134, 128]))
			rectangles = [Rect2(36, 60, 34, 3), Rect2(201, 45, 51, 5), Rect2(155, 162, 29, 5)]
	for rect in rectangles:
		polygons.append(_polygon([rect.position.x, rect.position.y, rect.end.x, rect.position.y, rect.end.x, rect.end.y, rect.position.x, rect.end.y]))
	return polygons


static func spikes(index: int) -> Array[Vector4]:
	# x, base y, width, signed tooth height (positive faces up).
	var strips: Array[Vector4] = []
	match index:
		0: strips = [Vector4(18, 97, 31, 5), Vector4(75, 96, 18, 6)]
		1: strips = [Vector4(59, 73, 26, 7), Vector4(85, 95, 24, 6), Vector4(60, 36, 25, -8)]
		2: strips = [Vector4(94, 73, 56, 6)]
		3: strips = [Vector4(146, 220, 44, 9), Vector4(190, 230, 73, 9)]
		4: strips = [Vector4(161, 180, 87, 9), Vector4(248, 167, 92, 9), Vector4(187, 83, 17, 11), Vector4(187, 128, 17, -10), Vector4(282, 51, 17, 13)]
		5: strips = [Vector4(133, 114, 24, 12), Vector4(242, 77, 22, 14), Vector4(136, 45, 24, -18)]
		7: strips = [Vector4(7, 97, 157, 7)]
		8: strips = [Vector4(108, 96, 38, 8), Vector4(194, 64, 36, 9), Vector4(108, 54, 36, -7), Vector4(198, 14, 32, -7)]
		9: strips = [Vector4(36, 128, 39, 9), Vector4(75, 108, 28, 10)]
	for i in strips.size():
		strips[i] *= SCALE
	return strips


static func spike_triangles(index: int) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for strip in spikes(index):
		var teeth := ceili(strip.z / (6 * SCALE))
		var width := strip.z / teeth
		for i in teeth:
			var x := strip.x + i * width
			result.append(PackedVector2Array([Vector2(x, strip.y), Vector2(x + width * 0.5, strip.y - strip.w), Vector2(x + width, strip.y)]))
	return result


static func planks(index: int) -> Array[Rect2]:
	var boards: Array[Rect2] = []
	match index:
		3: boards = [Rect2(128, 130, 31, 4), Rect2(205, 77, 34, 5)]
		5: boards = [Rect2(287, 145, 31, 8)]
		8: boards = [Rect2(63, 102, 21, 4), Rect2(158, 101, 22, 5)]
	for i in boards.size():
		boards[i] = Rect2(boards[i].position * SCALE, boards[i].size * SCALE)
	return boards


static func springs(index: int) -> Array[Vector3]:
	match index:
		1: return [Vector3(160 * SCALE, 70 * SCALE, 900)]
		5: return [Vector3(83 * SCALE, 134 * SCALE, 900), Vector3(199 * SCALE, 132 * SCALE, 1000)]
	return []


static func crystals(index: int) -> Array[Vector2]:
	match index:
		2: return [Vector2(168, 67) * SCALE]
		7: return [Vector2(61, 50) * SCALE, Vector2(112, 60) * SCALE]
		8: return [Vector2(174, 37) * SCALE]
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
		draw_texture_rect(ROCKET, ROCKET_RECT, false)
