extends Node2D

var elapsed := 0.0
var _sky := GradientTexture2D.new()


func _ready() -> void:
	_sky.gradient = Gradient.new()
	_sky.gradient.colors = PackedColorArray([Color("64b5ed"), Color("d4f1f5")])
	_sky.fill_from = Vector2.ZERO
	_sky.fill_to = Vector2(0, 1)


func _process(delta: float) -> void:
	elapsed = fposmod(elapsed + delta, 60.0)
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(_sky, get_viewport_rect(), false)
	var scale := get_viewport_rect().size / Vector2(1280, 720)
	var phase := elapsed * TAU / 60.0
	draw_set_transform(Vector2.ZERO, 0, scale)
	for band in 6:
		var x := band * 270.0 - 180 + 28 * sin(phase + band)
		var light := Color(1, 0.98, 0.78, 0.09 + 0.025 * sin(phase * 2 + band))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 0), Vector2(x + 38, 0), Vector2(x + 290, 720), Vector2(x + 150, 720),
		]), light)
	var sun := Vector2(58, 156)
	draw_circle(sun, 48, Color(1, 0.96, 0.72, 0.12), true, -1, true)
	draw_circle(sun, 38, Color(1, 0.96, 0.72, 0.2), true, -1, true)
	for ray in 8:
		var angle := ray * TAU / 8 + phase * 0.25
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(sun + direction * 34, sun + direction * 42, ArtDraw.CREAM, 3, true)
	ArtDraw.ellipse(self, sun, Vector2.ONE * 26, Color("ffe7a0"), 2)
	draw_arc(sun, 18, PI * 1.1, PI * 1.6, 18, Color.WHITE, 3, true)
	var clouds := [Vector3(30, 358, 0.85), Vector3(1220, 278, 1), Vector3(78, 590, 0.65), Vector3(1250, 608, 0.85)]
	for index in clouds.size():
		var cloud: Vector3 = clouds[index]
		var p := Vector2(cloud.x + 24 * sin(phase + index * 1.7), cloud.y + 5 * sin(phase * 2 + index))
		draw_set_transform((p + Vector2(0, 5)) * scale, 0, scale * cloud.z)
		_draw_cloud(Color(0.64, 0.82, 0.95, 0.8))
		draw_set_transform(p * scale, 0, scale * cloud.z)
		_draw_cloud(Color(1, 1, 1, 0.94))
	draw_set_transform(Vector2.ZERO)


func _draw_cloud(tint: Color) -> void:
	draw_circle(Vector2(-20, 5), 22, tint, true, -1, true)
	draw_circle(Vector2(2, -6), 28, tint, true, -1, true)
	draw_circle(Vector2(30, 7), 20, tint, true, -1, true)
	draw_rect(Rect2(-20, 5, 50, 21), tint)
