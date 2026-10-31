extends Node2D

var sky_progress := 0.0
var elapsed := 0.0
var stars: Array[Vector4] = []
var _sky := GradientTexture2D.new()
@onready var stage := get_parent().get_parent()


func _ready() -> void:
	_sky.gradient = Gradient.new()
	_sky.fill_from = Vector2.ZERO
	_sky.fill_to = Vector2(0, 1)
	var random := RandomNumberGenerator.new()
	random.seed = 82017
	for i in 46:
		stars.append(Vector4(random.randf_range(12, 1268), random.randf_range(12, 708), random.randf_range(0.65, 2.8), random.randf_range(0.35, 0.95)))
	_process(0)


func _process(delta: float) -> void:
	if DisplayServer.accessibility_should_reduce_animation() != 1:
		elapsed += delta
	var start_height := TowerLandscape.start().y
	var goal_height := TowerLandscape.origin(6).y + TowerLandscape.foothold(6, 227, 115).y
	sky_progress = clampf((start_height - stage.player.global_position.y) / (start_height - goal_height), 0, 1)
	_sky.gradient.colors = PackedColorArray([
		Color("73acf0").lerp(Color("080e24"), smoothstep(0, 1, sky_progress)),
		Color("8abdee").lerp(Color("1c2949"), smoothstep(0, 1, sky_progress)),
	])
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(_sky, get_viewport_rect(), false)
	draw_set_transform(Vector2.ZERO, 0, get_viewport_rect().size / Vector2(1280, 720))
	var starlight := smoothstep(0.12, 0.8, sky_progress)
	for star in stars:
		var p := Vector2(star.x, fposmod(star.y + stage.camera.position.y * 0.035, 720))
		draw_circle(p, star.z, Color(0.96, 0.97, 1, star.w * starlight))
	for i in 3:
		var p := Vector2(fposmod(180 + i * 440 + elapsed * 4, 1520) - 120, 260 + (i % 2) * 140 + (TowerLandscape.start().y - stage.camera.position.y) * 0.15)
		var tint := Color(1, 1, 1, 0.55 * (1 - smoothstep(0.1, 0.6, sky_progress)))
		for part in [Vector3(-36, 0, 28), Vector3(0, -14, 38), Vector3(38, 0, 30)]:
			draw_circle(p + Vector2(part.x, part.y), part.z, tint)
	draw_set_transform(Vector2.ZERO)
