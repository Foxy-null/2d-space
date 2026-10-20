extends SceneTree

var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _step(count: int = 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)


func _run() -> void:
	change_scene_to_file("res://scenes/stage_2_daylight.tscn")
	await _step(4)
	var stage := current_scene
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	stage.get_node("Background/Stars").motion_enabled = false
	var daylight := stage.get_node("Background/Space")
	daylight.set_process(false)
	daylight.elapsed = 0.0
	daylight._process(0.0)
	await _step(2)
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	var output := "res://deliverables/daylight-anime-frames"
	DirAccess.make_dir_recursive_absolute(output)
	_check(before.save_png("res://deliverables/stage-2-daylight-anime.png") == OK, "Save daylight preview")
	for frame in 90:
		daylight._process(1.0 / 15)
		await process_frame
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(output.path_join("%03d.png" % frame)) == OK, "Save animation frame")
	var after := root.get_texture().get_image()
	for center_x in [44, 1242]:
		var changed := 0
		for y in range(110, 680, 3):
			for x in range(center_x - 12, center_x + 13, 3):
				var difference := before.get_pixel(x, y) - after.get_pixel(x, y)
				if absf(difference.r) + absf(difference.g) + absf(difference.b) > 0.04:
					changed += 1
		_check(changed > 30, "Clouds and daylight animate on both sides")
		_check(after.get_pixel(center_x, 420).get_luminance() > 0.3, "Exterior stays bright blue")
	_check(before.get_pixel(640, 250).is_equal_approx(after.get_pixel(640, 250)), "Exterior light stays behind the tower interior")
	for camera_y in [360.0, -1520.0, -3920.0]:
		stage.camera.position.y = camera_y
		await _step(2)
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().get_pixel(44, 420).get_luminance() > 0.3, "Daylight remains visible at every tower height")
	stage.queue_free()
	await _step(3)
	print("STAGE_2_DAYLIGHT_TEST_%s" % ("FAILED" if failed else "OK"))
	quit(1 if failed else 0)
