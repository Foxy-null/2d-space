extends StageBackdrop

const ASCENT_SHADER := preload("res://assets/environments/ascent.gdshader")
const CAMERA_BOTTOM := 360.0
const CAMERA_TOP := -3920.0
var _cloud_shape := PackedVector2Array([
	Vector2(-64, 22), Vector2(-65, 16), Vector2(-62, 9), Vector2(-55, 5), Vector2(-47, 4), Vector2(-35, 7),
	Vector2(-29, -8), Vector2(-18, -22), Vector2(-5, -29), Vector2(10, -30), Vector2(23, -24), Vector2(31, -12),
	Vector2(34, 1), Vector2(42, -1), Vector2(53, 2), Vector2(62, 9), Vector2(64, 18), Vector2(59, 23),
])

var rise := 0.0
var sky_progress := 0.0
var _sky := GradientTexture2D.new()

@onready var camera: Camera2D = $"../../Camera2D"


func _ready() -> void:
	_sky.gradient = Gradient.new()
	_sky.fill_from = Vector2.ZERO
	_sky.fill_to = Vector2(0, 1)
	super._ready()
	_picture.material.shader = ASCENT_SHADER
	_process(0)


func _process(delta: float) -> void:
	rise = maxf(0, CAMERA_BOTTOM - camera.position.y)
	sky_progress = clampf(rise / (CAMERA_BOTTOM - CAMERA_TOP), 0, 1)
	_picture.position.y = rise * 0.5 * get_viewport_rect().size.y / 720.0
	_sky.gradient.colors = PackedColorArray([
		Color("73acf0").lerp(Color("0b1330"), smoothstep(0, 1, sky_progress)),
		Color("8abdee").lerp(Color("263356"), smoothstep(0.1, 1, sky_progress)),
	])
	super._process(delta)
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(_sky, get_viewport_rect(), false)


func _draw_motion(canvas: Node2D) -> void:
	var scale := get_viewport_rect().size / Vector2(1280, 720)
	canvas.draw_set_transform(Vector2.ZERO, 0, scale)
	var starlight := smoothstep(0.35, 0.9, sky_progress)
	for i in 80:
		var p := Vector2(fposmod(i * 173.0 + 61, 1280), fposmod(i * 83.0 + rise * 0.08, 720))
		var tint := Color(0.92, 0.92, 1, starlight * (0.3 + (i % 4) * 0.15))
		canvas.draw_circle(p, 1.2 + (i % 3) * 0.4, tint)
		if i % 17 == 0:
			canvas.draw_line(p - Vector2(4, 0), p + Vector2(4, 0), tint, 1, true)
			canvas.draw_line(p - Vector2(0, 4), p + Vector2(0, 4), tint, 1, true)
	var moon := Vector2(1050, -480 + rise * 0.18)
	canvas.draw_circle(moon, 65, Color(0.64, 0.74, 0.94, starlight * 0.4))
	for offset in [Vector2(-21, -17), Vector2(24, 12), Vector2(-8, 33)]:
		canvas.draw_circle(moon + offset, 12, Color(0.46, 0.58, 0.82, starlight * 0.25))
	# Cloud bands have fixed heights; the ground appears only once at the foot of the tower.
	for i in 7:
		var p := Vector2(160 + fposmod(i * 431, 960) + 18 * sin(elapsed * TAU / LOOP_TIME + i), 320 - i * 280 + rise * 0.38)
		var tint := Color(0.87, 0.93, 1, (1 - smoothstep(0.55, 0.95, sky_progress)) * 0.32)
		canvas.draw_set_transform(p * scale, 0, scale)
		canvas.draw_colored_polygon(_cloud_shape, tint)
	canvas.draw_set_transform(Vector2.ZERO)
