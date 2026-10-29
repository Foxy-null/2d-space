class_name TutorialLandscape
extends Node2D

const WIDTHS: Array[float] = [1800.0, 2400.0, 3000.0]
const HEIGHTS: Array[float] = [900.0, 1000.0, 900.0]
const ORIGINS: Array[float] = [0.0, 2200.0, 5000.0]
const LEFT_FLOORS: Array[float] = [760.0, 900.0, 620.0]
const RIGHT_FLOORS: Array[float] = [680.0, 520.0, 580.0]
const CASTLE := preload("res://assets/tutorial/castle.png")
const ROCKET := preload("res://assets/tutorial/rocket.png")
const SOIL := Color("b28b5c")
const GRASS := Color("b7d97a")

@export_range(0, 2) var room_index := 0
@export var menu_background := false
var elapsed := 0.0
var stars: Array[Vector3] = []


static func landforms(index: int) -> Array[PackedVector2Array]:
	var forms: Array[PackedVector2Array] = []
	match index:
		0:
			forms.append(PackedVector2Array([Vector2(0, 760), Vector2(300, 760), Vector2(300, 710), Vector2(420, 710), Vector2(420, 900), Vector2(0, 900)]))
			forms.append(PackedVector2Array([Vector2(650, 710), Vector2(850, 710), Vector2(850, 670), Vector2(960, 670), Vector2(960, 710), Vector2(1160, 710), Vector2(1160, 900), Vector2(650, 900)]))
			forms.append(PackedVector2Array([Vector2(1390, 710), Vector2(1610, 710), Vector2(1610, 680), Vector2(1800, 680), Vector2(1800, 900), Vector2(1390, 900)]))
		1:
			forms.append(PackedVector2Array([Vector2(0, 900), Vector2(160, 900), Vector2(160, 730), Vector2(330, 730), Vector2(330, 1000), Vector2(0, 1000)]))
			forms.append(PackedVector2Array([Vector2(510, 650), Vector2(600, 650), Vector2(600, 560), Vector2(720, 560), Vector2(720, 1000), Vector2(510, 1000)]))
			forms.append(PackedVector2Array([Vector2(900, 290), Vector2(1090, 290), Vector2(1090, 610), Vector2(900, 610)]))
			forms.append(PackedVector2Array([Vector2(890, 850), Vector2(1080, 850), Vector2(1080, 1000), Vector2(890, 1000)]))
			forms.append(PackedVector2Array([Vector2(1250, 820), Vector2(1280, 820), Vector2(1280, 1000), Vector2(1250, 1000)]))
			forms.append(PackedVector2Array([Vector2(1450, 760), Vector2(1650, 760), Vector2(1650, 1000), Vector2(1450, 1000)]))
			forms.append(PackedVector2Array([Vector2(1760, 840), Vector2(1900, 840), Vector2(1900, 760), Vector2(2050, 760), Vector2(2050, 680), Vector2(2190, 680), Vector2(2190, 1000), Vector2(1760, 1000)]))
			forms.append(PackedVector2Array([Vector2(2240, 520), Vector2(2400, 520), Vector2(2400, 1000), Vector2(2240, 1000)]))
		2:
			forms.append(PackedVector2Array([Vector2(0, 620), Vector2(320, 620), Vector2(320, 900), Vector2(0, 900)]))
			forms.append(PackedVector2Array([Vector2(2740, 580), Vector2(3000, 580), Vector2(3000, 900), Vector2(2740, 900)]))
	return forms


static func bridge_sections() -> Array[Vector2]:
	return [Vector2(320, 1100), Vector2(1320, 1940), Vector2(2160, 2420), Vector2(2600, 2680)]


static func spikes(index: int) -> Array[Rect2]:
	if index == 0:
		return [Rect2(194, 736, 62, 24), Rect2(868, 646, 68, 24)]
	return []


func _ready() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 7301 + room_index
	for i in 38:
		stars.append(Vector3(random.randf_range(12, WIDTHS[room_index] - 12), random.randf_range(18, 650), random.randf_range(0.7, 2.1)))
	if menu_background:
		position.y = -180


func _process(delta: float) -> void:
	if DisplayServer.accessibility_should_reduce_animation() != 1:
		elapsed += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, WIDTHS[room_index], HEIGHTS[room_index]), Color.BLACK)
	for i in stars.size():
		var star := stars[i]
		draw_circle(Vector2(star.x, star.y), star.z, Color(1, 1, 1, 0.72 + 0.22 * sin(elapsed * 0.65 + i * 2.3)))
	for i in 3:
		var cloud := Vector2(fposmod(360.0 + i * 670.0 + elapsed * (4.0 + i), WIDTHS[room_index] + 250.0) - 120.0, 180.0 + (i % 2) * 120.0)
		_draw_cloud(cloud, 0.8 + i * 0.18)
	if room_index == 0:
		draw_texture_rect(CASTLE, Rect2(-190, 40, 720, 720), false)
	for polygon in landforms(room_index):
		var grounded := false
		for point in polygon:
			grounded = grounded or point.y >= HEIGHTS[room_index]
		var colors := PackedColorArray()
		var top := HEIGHTS[room_index]
		for point in polygon:
			top = minf(top, point.y)
		for point in polygon:
			var shade := 0.58 * (point.y - top) / maxf(1.0, HEIGHTS[room_index] - top) if grounded else 0.0
			colors.append(SOIL.darkened(shade))
		draw_polygon(polygon, colors)
		for i in polygon.size() - 1:
			var a := polygon[i]
			var b := polygon[i + 1]
			if b.x > a.x and is_equal_approx(a.y, b.y):
				draw_rect(Rect2(a, Vector2(b.x - a.x, 12)), GRASS)
		var outline := polygon.duplicate()
		outline.append(polygon[0])
		draw_polyline(outline, Color.BLACK, 3, true)
	for hazard in spikes(room_index):
		for x in range(int(hazard.position.x), int(hazard.end.x), 17):
			var triangle := PackedVector2Array([Vector2(x, hazard.end.y), Vector2(x + 8, hazard.position.y), Vector2(x + 17, hazard.end.y), Vector2(x, hazard.end.y)])
			draw_colored_polygon(triangle, Color("f5eee2"))
			draw_polyline(triangle, Color.BLACK, 2, true)
	if room_index == 2:
		draw_texture_rect(ROCKET, Rect2(2810, 350, 144, 230), false)


func _draw_cloud(center: Vector2, factor: float) -> void:
	draw_set_transform(center, 0, Vector2.ONE * factor)
	for cloud_part in [Vector3(-44, 0, 29), Vector3(-12, -15, 35), Vector3(25, -8, 32), Vector3(57, 3, 22)]:
		draw_circle(Vector2(cloud_part.x, cloud_part.y), cloud_part.z, Color.WHITE)
	draw_rect(Rect2(-45, -5, 102, 28), Color.WHITE)
	draw_set_transform(Vector2.ZERO)
