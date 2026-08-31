class_name Starfield
extends Node2D

@export_range(1, 300) var star_count := 96
@export var drift_speed := 8.0

var _stars: Array[Vector3] = []


func _ready() -> void:
	get_viewport().size_changed.connect(_rebuild)
	_rebuild()


func _process(delta: float) -> void:
	var width := get_viewport_rect().size.x
	if width <= 0.0:
		return

	for index in _stars.size():
		var star := _stars[index]
		star.x = fposmod(star.x - drift_speed * star.z * delta, width)
		_stars[index] = star
	queue_redraw()


func _draw() -> void:
	for index in _stars.size():
		var star := _stars[index]
		var depth := inverse_lerp(0.8, 2.2, star.z)
		var color := Color(0.45, 0.67, 0.88, lerpf(0.35, 0.9, depth))
		var position := Vector2(star.x, star.y)
		draw_circle(position, star.z, color)
		if index % 17 == 0:
			var flare := star.z * 2.5
			draw_line(position - Vector2(flare, 0.0), position + Vector2(flare, 0.0), color, 1.0)
			draw_line(position - Vector2(0.0, flare), position + Vector2(0.0, flare), color, 1.0)


func _rebuild() -> void:
	var bounds := get_viewport_rect().size
	var random := RandomNumberGenerator.new()
	random.seed = 20260831
	_stars.clear()
	for _index in star_count:
		_stars.append(Vector3(
			random.randf_range(0.0, bounds.x),
			random.randf_range(0.0, bounds.y),
			random.randf_range(0.8, 2.2)
		))
	queue_redraw()
