extends SceneTree

var stage: Node
var checks := 0
var resets := 0
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
		await _death_sequence(scene)
	await _open("tutorial")
	var intro := await _die()
	stage.get_node("PauseMenu").open()
	stage.get_node("PauseMenu").retry()
	await _step(2)
	_check(resets == 1 and not paused and not stage.has_node("StageIntro"), "Manual retry cancels death and resets exactly once")
	_check(stage.player.controls_enabled and root.get_camera_2d() == stage.camera, "Retry restores the normal camera and controls")
	intro = await _die()
	stage.get_node("PauseMenu").open()
	stage.get_node("PauseMenu").skip_cinematic()
	await _step(2)
	_check(resets == 2 and not paused and not stage.has_node("StageIntro"), "Skipping a death still respawns exactly once")
	intro = await _die()
	intro._reduced_motion = true
	intro._process(0.0)
	await _step(2)
	_check(resets == 3 and not paused and not stage.has_node("StageIntro") and not root.get_node("GameAudio").iris.playing, "Reduced motion respawns immediately without an iris animation")
	intro = await _die()
	intro._process(0.51)
	_check(not paused, "The world is running during the opening")
	var old_intro := intro
	intro = await _die()
	_check(intro != old_intro and paused, "A second death during opening starts a fresh closing effect")
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(3)
	var audio := root.get_node("GameAudio")
	_check(not paused and not audio.iris.playing and not audio.death.playing, "Leaving during death releases the pause and stops scene sounds")
	await _open("tutorial")
	stage.player.die()
	stage.get_node("PauseMenu").open()
	await _step(2)
	stage.get_node("PauseMenu").resume()
	_check(paused and not stage.get_node("PauseMenu").overlay.visible, "A menu opened in the death frame preserves the effect's world pause")
	stage.get_node("StageIntro").finish()
	await _step(2)
	_check(not paused and resets == 1, "The same-frame pause race cannot leave gameplay frozen after recovery")
	await _death_routes()
	audio.music.stop()
	audio.death.stop()
	audio.iris.stop()
	current_scene.queue_free()
	await _step(3)
	stage = null
	print("DEATH_IRIS_TEST_OK (%d checks)" % checks)
	quit()


func _open(scene: String) -> void:
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	await _step(2)
	stage = current_scene
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	if scene == "stage_6":
		stage._intro_left = 0.0
		stage._intro_panel.hide()
		stage.enemy.set_physics_process(false)
		stage.player.controls_enabled = true
		stage._update_camera()
	var intro := stage.get_node_or_null("StageIntro")
	if intro != null:
		intro.finish()
	await _step(2)
	resets = 0
	stage.player.respawned.connect(func(): resets += 1)


func _die() -> StageIntro:
	stage.player.die()
	await _step()
	var intro: StageIntro = stage.get_node("StageIntro")
	intro.set_process(false)
	intro._elapsed = 0.0
	return intro


func _death_sequence(scene: String) -> void:
	var player: PlayerController = stage.player
	var audio := root.get_node("GameAudio")
	var spawn := player._spawn_position
	var normal_zoom: Vector2 = stage.camera.zoom
	player.position += Vector2(100, -60)
	player.velocity = Vector2(250, -100)
	player.set_gravity_direction(-1)
	player._wall_stamina = 0.2
	var death_position := player.global_position
	var intro: StageIntro
	if scene == "stage_6":
		stage._game_over("攻撃でスタミナが尽きました")
		await _step()
		intro = stage.get_node("StageIntro")
		intro.set_process(false)
		intro._elapsed = 0.0
		_check(stage._message.visible and stage._game_over_pending, "Stage 6 uses the shared death effect and keeps its reason until reset")
	else:
		intro = await _die()
	_check(paused and not player.controls_enabled and resets == 0, "Death freezes the world before resetting: " + scene)
	_check(root.get_camera_2d() == stage.camera and stage.camera.zoom == normal_zoom, "Death uses the normal camera without a close-up (%s current=%s normal=%s zoom=%s)" % [scene, root.get_camera_2d(), stage.camera, stage.camera.zoom])
	if capture_dir.is_empty():
		_check(audio.death.playing and audio.iris.playing and audio.iris.stream == audio.IRIS_CLOSE, "Impact and closing sounds can overlap")
		var playback: AudioStreamPlayback = audio.death.get_stream_playback()
		player.die()
		_check(audio.death.get_stream_playback() == playback, "Repeated death contacts do not restart the sound")
	else:
		player.die()
	_check(stage.get_node("StageIntro") == intro, "Repeated death contacts do not restart the effect")
	var menu := stage.get_node("PauseMenu")
	menu.open()
	intro._process(0.2)
	_check(intro._elapsed == 0.0 and (not audio.iris.playing or audio.iris.stream_paused) and (not audio.death.playing or audio.death.stream_paused), "Pause freezes the animation and its sounds")
	root.get_node("InputSettings").open_settings()
	intro._process(0.2)
	root.get_node("InputSettings").close_settings()
	_check(intro._elapsed == 0.0 and menu.overlay.visible, "Input settings preserve the stopped death effect")
	menu.resume()
	intro._process(0.15)
	var radius: float = intro._curtain.material.get_shader_parameter("radius")
	_check(radius > 0.0 and radius < root.get_visible_rect().size.length(), "The circle shrinks before any reset")
	_check(player.global_position == death_position and resets == 0, "The death location remains visible while closing")
	_capture(scene + "-closing")
	intro._process(0.16)
	_check(intro._curtain.material.get_shader_parameter("radius") == 0.0 and resets == 0, "The circle closes completely before the dark hold")
	_capture(scene + "-black", true)
	intro._process(0.18)
	_check(paused and resets == 0 and player.global_position == death_position, "The black hold lasts until half a second after death")
	intro._process(0.02)
	_check(resets == 1 and player.global_position == spawn and player.gravity_direction == 1 and player.velocity == Vector2.ZERO, "The existing checkpoint reset runs exactly once behind black")
	_check(player.get_wall_stamina() == player.wall_stamina_max, "Checkpoint reset restores movement resources")
	_check(not paused and player.controls_enabled and not intro._holding, "Controls and the world resume at opening start")
	_check(stage.camera.zoom == normal_zoom and root.get_camera_2d() == stage.camera, "Opening changes only the circle, with normal zoom and camera position")
	_check(audio.iris.stream == audio.IRIS_OPEN and audio.iris.playing, "Opening uses the expanding sound")
	intro._process(0.1)
	_capture(scene + "-opening")
	if scene == "stage_6":
		stage.camera.position.x += 80
		stage.camera.force_update_scroll()
	var camera_center: Vector2 = stage.camera.get_screen_center_position()
	intro._process(0.4)
	_check(stage.camera.get_screen_center_position() == camera_center, "Finishing the circle does not snap the live camera's smoothing")
	await _step(2)
	_check(not stage.has_node("StageIntro") and not paused and player.controls_enabled, "The one-second death effect cleans itself up")
	_check(not audio.iris.playing, "The iris sound stops at effect completion")
	audio.death.stop()
	Input.action_press("reset")
	player._physics_process(0.0)
	Input.action_release("reset")
	await _step(2)
	_check(resets == 2 and not stage.has_node("StageIntro") and not audio.death.playing, "R retries immediately without death sound or animation")


func _death_routes() -> void:
	for scene in ["tutorial", "stage_2", "stage_3", "stage_4", "stage_5", "stage_6"]:
		await _open(scene)
		match scene:
			"tutorial":
				stage._queue_death()
			"stage_2":
				stage.player.position.y += 2000
				stage._physics_process(0.0)
			"stage_3", "stage_4":
				stage.player.position.y = 3000
				stage._physics_process(0.0)
			"stage_5":
				stage._on_hazard(stage.player)
			"stage_6":
				stage.player.position.y = stage.room.size.y + 200
				stage._physics_process(0.0)
		await _step(2)
		_check(stage.has_node("StageIntro") and stage.get_node("StageIntro")._death and resets == 0, "Real hazard/fall paths start death before respawning: " + scene)
		stage.get_node("StageIntro").finish()
		await _step(2)
		_check(resets == 1 and not paused, "Real hazard recovery returns to gameplay: " + scene)


func _capture(label: String, black := false) -> void:
	if capture_dir.is_empty():
		return
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	image.save_png(capture_dir.path_join(label + ".png"))
	if black:
		var center: Vector2 = stage.get_node("StageIntro")._curtain.material.get_shader_parameter("center")
		_check(image.get_pixelv(Vector2i(center).clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)).is_equal_approx(Color.BLACK), "Even the circle center is fully black during reset")
		_check(image.get_pixel(1200, 80).is_equal_approx(Color.BLACK), "The black hold also covers scenery and HUD")


func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame
		await create_timer(0.0).timeout


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		push_error("DEATH_IRIS: " + label)
		quit(1)
		assert(ok, label)
