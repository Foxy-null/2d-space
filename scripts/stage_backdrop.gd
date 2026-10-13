class_name StageBackdrop
extends Node2D

const TEXTURES := [preload("res://assets/environments/base.png"), preload("res://assets/environments/inhabited.png"), preload("res://assets/environments/wild.png"), preload("res://assets/environments/lava.png"), preload("res://assets/environments/evil.png")]
const AMBIENT := preload("res://assets/environments/ambient.gdshader")
const LOOP_TIME := 120.0

var elapsed := 0.0
var motion_enabled := true
var environment_theme := 0:
	set(value):
		environment_theme = clampi(value, 0, 4)
		if _picture != null:
			_picture.texture = TEXTURES[environment_theme]
			_picture.material.set_shader_parameter("environment_theme", environment_theme)
		queue_redraw()
var _picture: Sprite2D


func _ready() -> void:
	_picture = Sprite2D.new()
	_picture.centered = false
	var shader := ShaderMaterial.new()
	shader.shader = AMBIENT
	_picture.material = shader
	add_child(_picture)
	# Particle drawing is a sibling above the art, still inside the background layer.
	var particles := Node2D.new()
	particles.name = "AmbientMotion"
	particles.draw.connect(_draw_motion.bind(particles))
	add_child(particles)
	get_viewport().size_changed.connect(_resize)
	environment_theme = ArtDraw.environment(self)
	_resize()


func _resize() -> void:
	_picture.scale = get_viewport_rect().size / _picture.texture.get_size()


func _process(delta: float) -> void:
	if motion_enabled:
		elapsed = fposmod(elapsed + delta, LOOP_TIME)
	_picture.material.set_shader_parameter("elapsed", elapsed)
	$AmbientMotion.queue_redraw()


func _draw_motion(canvas: Node2D) -> void:
	var size := get_viewport_rect().size
	var scale := size / Vector2(1280, 720)
	canvas.draw_set_transform(Vector2.ZERO, 0, scale)
	match environment_theme:
		0:
			for i in 20:
				var x := fposmod(i * 173.0 - elapsed * 1280.0 / LOOP_TIME, 1280)
				var y := 70.0 + fposmod(i * 83.0, 300)
				var alpha := 0.35 + 0.2 * sin(elapsed * TAU / 10 + i)
				canvas.draw_circle(Vector2(x, y), 1.4, Color(0.88, 0.87, 1, alpha))
		1, 2:
			for i in 3:
				var x := i * 490.0 + 45 * sin(elapsed * TAU / LOOP_TIME + i)
				var y := 120.0 + i * 73
				var tint := Color(0.9, 0.93, 1, 0.14)
				canvas.draw_circle(Vector2(x, y), 16, tint)
				canvas.draw_circle(Vector2(x + 18, y + 5), 11, tint)
				canvas.draw_line(Vector2(x - 15, y + 13), Vector2(x + 32, y + 13), tint, 5, true)
		3:
			_draw_lava(canvas)
		4:
			for i in 4:
				var points := PackedVector2Array()
				for j in 40:
					var x := j * 34.0 - 25
					var y := 460 + i * 47 + 12 * sin(x / 170.0 + elapsed * TAU / 20 + i)
					points.append(Vector2(x, y))
				canvas.draw_polyline(points, Color(0.52, 0.3, 0.7, 0.13), 6 + i * 2, true)
			# A slow, partial arc reinforces the distant vortex without turning into a gate.
			var turn := elapsed * TAU / 120
			canvas.draw_arc(Vector2(1060, 126), 99, turn, turn + 0.8, 24, Color(0.62, 0.35, 0.77, 0.18), 4, true)
	canvas.draw_set_transform(Vector2.ZERO)


func _draw_lava(canvas: Node2D) -> void:
	for i in 7:
		var phase := fposmod(elapsed / 10.0 + float(i) / 7, 1.0)
		var radius := 8 + 12 * sin(phase * PI)
		var center := Vector2(95 + i * 177, 568 + (i % 3) * 32 - 9 * sin(phase * PI))
		var opacity := sin(phase * PI)
		canvas.draw_circle(center, radius, Color(1, 0.55, 0.12, 0.65 * opacity))
		canvas.draw_arc(center, radius, PI, TAU, 20, Color(1, 0.78, 0.27, opacity), 2, true)
		if phase > 0.65:
			for side in [-1.0, 1.0]:
				var splash := center + Vector2(side * radius, -(phase - 0.65) * 50)
				canvas.draw_circle(splash, 2.5, Color(1, 0.72, 0.2, opacity))
	for i in 24:
		var phase := fposmod(elapsed / 12.0 + float(i) / 24, 1.0)
		var x := fposmod(i * 139.0 + 14 * sin(phase * TAU + i), 1280)
		var y := 620 - phase * (220 + (i % 4) * 55)
		var alpha := 0.65 * sin(phase * PI)
		canvas.draw_line(Vector2(x, y + 3), Vector2(x + 1, y), Color(1, 0.7, 0.25, alpha), 1.6, true)
