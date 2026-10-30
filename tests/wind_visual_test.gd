extends SceneTree

const WIND := preload("res://scenes/wind_area.tscn")
var checks := 0
var failed := false
var viewport: SubViewport
var wind: Area2D
var max_draw_calls := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "gl_compatibility":
		push_error("WIND_VISUAL_TEST requires OpenGL: run with xvfb-run -a Godot --rendering-method gl_compatibility --path . --script tests/wind_visual_test.gd")
		quit(1)
		return
	RenderingServer.set_default_clear_color(Color("bdaee6"))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	wind = WIND.instantiate()
	wind.area_size = Vector2(600, 480)
	wind.position = Vector2(640, 360)
	viewport.add_child(wind)
	wind.set_process(false)
	var baseline := await _render(Vector2.ZERO)
	_check(baseline.get_size() == viewport.size, "The isolated render fixture is exactly 1280 by 720 pixels")
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var picture := await _render(direction)
		var center := Vector2(640, 130) if direction.x != 0 else Vector2(350, 360)
		_check_arrow(picture, baseline, center, direction)
	var peak := await _render(Vector2.RIGHT)
	var faint := await _render(Vector2.RIGHT, 0.06)
	var invisible := await _render(Vector2.RIGHT, 0.0)
	var wrapped := await _render(Vector2.RIGHT, 6.0)
	_check(_contrast(peak, baseline, Vector2(640, 130)) > _contrast(faint, baseline, Vector2(356, 130)) * 4, "The midpoint is substantially stronger than the fading start of the same arrow")
	_check(_contrast(invisible, baseline, Vector2(350, 130)) < 0.01 and _contrast(wrapped, baseline, Vector2(350, 130)) < 0.01, "The first arrow fades completely at both ends of its six-second cycle")
	var rotated_baseline := await _render(Vector2.ZERO, 3.0, PI / 2)
	var rotated := await _render(Vector2.RIGHT, 3.0, PI / 2)
	_check_arrow(rotated, rotated_baseline, Vector2(640, 70), Vector2.RIGHT)
	var zero := await _render(Vector2.ZERO)
	var uniform := zero.get_pixel(640, 360)
	var has_marks := false
	for y in range(128, 600, 16):
		for x in range(348, 940, 16):
			has_marks = has_marks or _difference(zero.get_pixel(x, y), uniform) > 0.01
	_check(not has_marks, "Zero wind direction leaves only the uniform area tint, without arrows or a fan")
	# The isolated GL canvas uses 11 calls; the same arrows via per-arrow ArtDraw use 82.
	_check(max_draw_calls <= 16, "The isolated wind stays batched within sixteen canvas draw calls: observed %d" % max_draw_calls)
	viewport.queue_free()
	await process_frame
	print("WIND_VISUAL_TEST_%s checks=%d max_draw_calls=%d" % ["FAILED" if failed else "OK", checks, max_draw_calls])
	quit(1 if failed else 0)


func _render(direction: Vector2, time := 3.0, angle := 0.0) -> Image:
	wind.wind_direction = direction
	wind.rotation = angle
	wind._time = time
	wind.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	max_draw_calls = maxi(max_draw_calls, viewport.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
	return viewport.get_texture().get_image()


func _check_arrow(picture: Image, baseline: Image, center: Vector2, direction: Vector2) -> void:
	var side := direction.orthogonal()
	_check(_contrast(picture, baseline, center - direction * 5) > 0.04, "The arrow shaft is visible in direction " + str(direction))
	for sign in [-1, 1]:
		var head: Vector2 = center + direction * 3 + side * sign * 5
		var tail: Vector2 = center - direction * 3 + side * sign * 5
		_check(_contrast(picture, baseline, head) > _contrast(picture, baseline, tail) + 0.03, "Both arrowhead wings point toward the world wind direction " + str(direction))
	var dark_edge := 0.0
	var edge := Vector2i(center - direction * 4 + side * 2)
	for y in range(edge.y - 1, edge.y + 2):
		for x in range(edge.x - 1, edge.x + 2):
			var before := baseline.get_pixel(x, y)
			var after := picture.get_pixel(x, y)
			dark_edge = maxf(dark_edge, Vector3(before.r - after.r, before.g - after.g, before.b - after.b).dot(Vector3(0.2126, 0.7152, 0.0722)))
	_check(dark_edge > 0.05, "A dark outline separates the cyan shaft from the light background")


func _contrast(picture: Image, baseline: Image, at: Vector2) -> float:
	var peak := 0.0
	var pixel := Vector2i(at.round())
	for y in range(pixel.y - 1, pixel.y + 2):
		for x in range(pixel.x - 1, pixel.x + 2):
			peak = maxf(peak, _difference(picture.get_pixel(x, y), baseline.get_pixel(x, y)))
	return peak


func _difference(a: Color, b: Color) -> float:
	return (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error(message)
