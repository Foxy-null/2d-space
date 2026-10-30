extends SceneTree

var checks := 0
var stage: Node
var capture_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
	for scene in ["tutorial", "stage_2", "stage_3", "stage_4", "stage_5", "stage_6"]:
		await _open(scene)
		await _natural_intro(scene)
	for scene in ["tutorial", "stage_2", "stage_6"]:
		await _open(scene)
		var menu := stage.get_node("PauseMenu")
		menu.open()
		_check(menu.menu.get_node("SkipCinematic").visible, "The common pause menu offers intro skip")
		menu.skip_cinematic()
		await _step()
		_check(not paused and stage.player.controls_enabled and root.get_camera_2d() == stage.camera, "Skip restores gameplay and the stage camera")
		await _open(scene)
		stage.get_node("PauseMenu").open()
		stage.get_node("PauseMenu").retry()
		await _step(3)
		_check(not paused and not stage.has_node("StageIntro") and stage.player.controls_enabled, "Retry cancels the intro without replaying it")
		_check(root.get_camera_2d() == stage.camera, "Retry restores the normal camera")
		await _open(scene)
		change_scene_to_file("res://scenes/stage_select.tscn")
		await _step(3)
		_check(not paused and current_scene.scene_file_path.ends_with("stage_select.tscn"), "Leaving during the hold releases the world pause")
	current_scene.queue_free()
	await _step(3)
	print("STAGE_INTRO_TEST_OK (%d checks)" % checks)
	quit()


func _open(scene: String) -> void:
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	await _step(2)
	stage = current_scene
	if scene == "stage_6":
		_check(stage._intro_left > 0.0 and not stage.has_node("StageIntro"), "Stage 6 first plays its existing enemy introduction")
		for frame in 180:
			if stage.has_node("StageIntro"):
				break
			await _step()
		_check(stage._intro_left <= 0.0 and not stage._intro_panel.visible, "Stage 6 finishes the enemy introduction before the iris")
	_check(stage.has_node("StageIntro"), "Every stage entrance starts the shared iris")


func _natural_intro(scene: String) -> void:
	var intro: StageIntro = stage.get_node("StageIntro")
	var player: PlayerController = stage.player
	var position_before := player.global_position
	var mode_before := intro._stage_mode
	var normal_view := Rect2(stage.camera.global_position - Vector2(640, 360), Vector2(1280, 720))
	_check(paused and intro._holding and not player.controls_enabled, "The initial hold freezes the world and locks controls")
	_check(intro._intro_camera.zoom.is_equal_approx(Vector2.ONE * 1.4), "The character starts enlarged by forty percent")
	_check(intro.layer > stage.get_node("HUD").layer and intro.layer < stage.get_node("PauseMenu").layer, "The iris covers HUD and leaves pause above it")
	_check_view(intro, normal_view)
	var menu := stage.get_node("PauseMenu")
	menu.open()
	var elapsed := intro._elapsed
	await _step(35)
	_check(intro._elapsed == elapsed and player.global_position == position_before, "Pause freezes both the hold timer and player")
	root.get_node("InputSettings").open_settings()
	await _step(3)
	root.get_node("InputSettings").close_settings()
	_check(paused and menu.overlay.visible and intro._elapsed == elapsed, "Settings preserve the paused intro and its menu")
	menu.resume()
	_check(paused and not menu.overlay.visible, "Closing pause restores the intro's world stop")
	if scene == "stage_6":
		var room_time: float = stage.room._elapsed
		var enemy_position: Vector2 = stage.enemy.position
		await _step(3)
		_check(stage.room._elapsed == room_time and stage.enemy.position == enemy_position, "Stage 6's independent hazards and enemy also freeze")
	_capture(scene + "-hold", intro)
	Input.action_press("move_right")
	var hold_frames := 0
	while intro._holding and hold_frames < 80:
		_check(player.global_position == position_before, "Held movement cannot move the player during the hold")
		await _step()
		hold_frames += 1
	_check(not intro._holding and intro._elapsed >= 1.25 and intro._elapsed < 1.28, "The hold lasts one and a quarter seconds")
	_check(not paused and player.controls_enabled and intro.visible, "Controls unlock when the return begins, while the iris is still visible")
	_check(stage.process_mode == mode_before, "The stage's original processing mode is restored")
	await _step(4)
	_check(player.position.x > position_before.x, "The player can move during the return")
	_check(intro._intro_camera.zoom.x > 1.0 and intro._intro_camera.zoom.x < 1.4, "Zoom returns gradually")
	var radius: float = intro._curtain.material.get_shader_parameter("radius")
	_check(radius > StageIntro.IRIS_RADIUS, "The iris opens during the same return")
	var center: Vector2 = intro._curtain.material.get_shader_parameter("center")
	_check(center.distance_to(root.get_canvas_transform() * player.global_position) < 1.0, "The aperture follows the moving character")
	_check_view(intro, normal_view)
	_capture(scene + "-return", intro)
	menu.open()
	elapsed = intro._elapsed
	await _step(20)
	_check(intro._elapsed == elapsed, "Pause also freezes the return animation")
	menu.resume()
	Input.action_release("move_right")
	var return_frames := 4
	for frame in 35:
		if not is_instance_valid(intro):
			break
		await _step()
		return_frames += 1
	_check(return_frames >= 29 and return_frames <= 32, "The return takes thirty frames plus deferred removal at sixty fps (%s: %d)" % [scene, return_frames])
	_check(not is_instance_valid(intro) and not stage.has_node("StageIntro"), "The effect removes itself after the half-second return")
	_check(not paused and player.controls_enabled and root.get_camera_2d() == stage.camera, "Natural completion restores the normal camera and controls")
	_check(stage.camera.zoom.is_equal_approx(Vector2.ONE), "The normal zoom is unchanged")
	_capture(scene + "-finished")
	player.respawn()
	await _step(3)
	_check(not stage.has_node("StageIntro") and not paused, "Death/checkpoint respawn does not replay the entrance")


func _check_view(intro: StageIntro, bounds: Rect2) -> void:
	var half_view := root.get_visible_rect().size * 0.5 / intro._intro_camera.zoom
	var view := Rect2(intro._intro_camera.global_position - half_view, half_view * 2.0)
	_check(bounds.grow(0.1).encloses(view), "The camera stays within the stage's bounded normal view")


func _capture(label: String, intro: StageIntro = null) -> void:
	if capture_dir.is_empty():
		return
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	image.save_png(capture_dir.path_join(label + ".png"))
	if intro != null and intro._holding:
		_check(image.get_pixel(1200, 80).is_equal_approx(Color.BLACK), "The rendered iris covers distant HUD and scenery")
		var center: Vector2 = intro._curtain.material.get_shader_parameter("center")
		var visible_pixel := false
		for offset in [Vector2i.ZERO, Vector2i(20, 0), Vector2i(-20, 0), Vector2i(0, -20), Vector2i(0, 20)]:
			visible_pixel = visible_pixel or image.get_pixelv(Vector2i(center) + offset).v > 0.02
		_check(visible_pixel, "The rendered aperture leaves the player visible")


func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame
		await create_timer(0.0).timeout


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("STAGE_INTRO: " + message)
		quit(1)
		assert(condition, message)
