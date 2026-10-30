extends SceneTree

var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/stage_2.tscn")
	await _step(4)
	var stage := current_scene
	await stage.get_node("StageIntro").tree_exited
	var backdrop := stage.get_node("Background/Stars")
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	_check(not stage.player.use_default_respawn_bounds, "The tower can rise beyond the shared demo bounds")
	_check(backdrop.environment_theme == 1, "The tower stays on the inhabited planet")
	for art in stage.get_node("Terrain").find_children("*", "Polygon2D", true, false):
		_check(art is TerrainArt and art.environment_theme == 1, "Tower terrain uses the current inhabited art")
	var snapshots: Dictionary = {}
	for camera_y in [360.0, -80.0, -800.0, -1520.0, -2240.0, -2960.0, -3920.0, backdrop.camera_top]:
		stage.camera.position.y = camera_y
		await _step(2)
		var ground_y: float = backdrop._picture.position.y
		var sky: Color = backdrop._sky.gradient.colors[0]
		snapshots[camera_y] = [ground_y, sky]
		_check(is_equal_approx(backdrop.rise, 360.0 - camera_y), "Scenery uses the camera's displayed height")
		if camera_y < 360:
			_check(ground_y > 0 and ground_y < backdrop.rise, "The ground recedes more slowly than terrain")
		if OS.get_cmdline_user_args().has("--screenshots"):
			stage._set_checkpoint(clampi(int(backdrop.rise / 720), 0, stage.checkpoints.get_child_count() - 1))
			stage.player.position = Vector2(640, camera_y + 100)
			stage._update_hud()
			DirAccess.make_dir_recursive_absolute("res://docs/screenshots/stage-2")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/screenshots/stage-2/height_%d.png" % int(360 - camera_y))
	_check(snapshots[-1520.0][0] > 720, "Ground leaves the view in the middle of the climb")
	_check(snapshots[backdrop.camera_top][1].get_luminance() < snapshots[-3920.0][1].get_luminance(), "The expanded tower keeps darkening all the way to the actual summit")
	# Crossing a checkpoint boundary must not switch scenery or reset its position.
	stage.camera.position.y = -800.0
	await _step(2)
	var before: Color = backdrop._sky.gradient.colors[0]
	stage.camera.position.y -= 0.01
	await _step(2)
	_check(backdrop._sky.gradient.colors[0].is_equal_approx(before), "Sky is continuous across section heights")
	for camera_y in [-1520.0, -80.0, 360.0]:
		stage.camera.position.y = camera_y
		await _step(2)
		_check(is_equal_approx(backdrop._picture.position.y, snapshots[camera_y][0]) and backdrop._sky.gradient.colors[0] == snapshots[camera_y][1], "Descending restores the same scenery")
	stage._set_checkpoint(4)
	stage.player.respawn()
	await _step(2)
	_check(is_equal_approx(backdrop.rise, 360.0 - stage.camera.position.y), "Respawn immediately restores checkpoint scenery")
	stage.queue_free()
	await _step(3)
	OS.delay_msec(100)
	print("ASCENT_BACKDROP_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _step(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error(message)
