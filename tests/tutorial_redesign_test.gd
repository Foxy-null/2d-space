extends SceneTree

var tutorial
var progress
var inputs
var stage
var audio
var player: PlayerController
var checks := 0
var failed := false
var respawns := 0
var capture_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	tutorial = load("res://scripts/tutorial.gd")
	progress = root.get_node("CollectionProgress")
	inputs = root.get_node("InputSettings")
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
	stage = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	audio = root.get_node("GameAudio")
	audio.reset_scene()
	player = stage.player
	player.respawned.connect(func(): respawns += 1)
	await _step(5)
	await stage.get_node("StageIntro").tree_exited
	_check(not stage._bubble.visible, "The first room has no jump explanation")
	_check(player.wall_actions_enabled and not player.wall_jump_enabled and not player.dash_enabled, "Climbing is available from the start; wall kick and early dash are not")
	await _capture("room1-start")
	# Negative control: short jumping cannot clear the first gap, even beside a climbable wall.
	player.position = Vector2(405, 684)
	player.velocity = Vector2(360, 0)
	await _step(2)
	_hold("move_right")
	_hold("jump")
	await _step()
	Input.action_release("jump")
	var before := respawns
	await _until(func(): return respawns > before, 120, "short jump fails the first gap")
	_release()
	stage._enter_room(0, false)
	await _step(5)
	await _jump_at(148)
	await _jump_at(405)
	await _jump_at(808)
	await _jump_at(1144)
	await _walk(1575)
	_hold("jump")
	await _until(func(): return stage.room_index == 1, 160, "first room completes with long jumps")
	_release()
	if failed:
		_finish()
		return
	_check(stage._bubble.visible and "壁登り" in stage._prompt.text, "The second room introduces climbing")
	await _capture("room2-entry")
	await _climb(212)
	await _step(12)
	_check(stage._wall_guide_done and not stage._bubble.visible, "The climb prompt disappears only after mantling and landing above")
	await _jump_at(310)
	await _climb(650)
	await _walk(695)
	_hold("jump")
	_hold("wall_grab")
	_hold("move_up")
	await _until(func(): return _x() >= 938 and player.position.y < 290, 220, "optional scroll summit is reachable by climbing")
	Input.action_release("jump")
	Input.action_release("wall_grab")
	Input.action_release("move_up")
	await _walk(989)
	Input.action_release("move_right")
	await _until(func(): return progress.has_scroll("tutorial", progress.TUTORIAL_SCROLL), 90, "scroll secures after a safe landing")
	await _capture("room2-scroll")
	await _jump_at(1070)
	await _capture("room2-planks")
	await _jump_at(1628)
	await _climb(2090)
	await _walk(2165)
	_hold("jump")
	_hold("wall_grab")
	_hold("move_up")
	await _until(func(): return stage.room_index == 2, 240, "second room exits over the final wall")
	_release()
	if failed:
		_finish()
		return
	# Backtracking updates the checkpoint to the side actually entered.
	player.position.x = TutorialLandscape.ORIGINS[2] - 1
	await _step(2)
	_check(stage.room_index == 1 and _x() > 2300, "Returning enters the previous room from its right side")
	player.respawn()
	await _step(3)
	_check(stage.room_index == 1 and _x() > 2300, "Retry after backtracking uses the right entry")
	_hold("move_right")
	await _until(func(): return stage.room_index == 2, 40, "return to the bridge")
	_release()
	await _capture("room3-entry")
	# Low speed loses to the collapse before reaching the first gap.
	before = respawns
	_hold("move_right", 0.8)
	await _until(func(): return respawns > before, 200, "slow running loses to the bridge collapse")
	_release()
	_check(not stage.bridge.running and stage.bridge.front == 224.0, "Retry rebuilds the whole bridge")
	for plank in stage.bridge.planks:
		_check(plank.collision_layer == 1, "Each bridge plank is restored")
	# Walking off the final takeoff never receives the scripted rescue.
	stage._enter_room(2, false)
	player.position = Vector2(TutorialLandscape.ORIGINS[2] + 2388, 594)
	await _step(3)
	before = respawns
	_hold("move_right")
	await _until(func(): return respawns > before, 140, "Walking off the end dies without rescue")
	_check(stage.phase == tutorial.Phase.RUN, "An invalid approach never enters input wait")
	_release()
	for invalid in ["vertical", "left", "short"]:
		stage._enter_room(2, false)
		player.position = Vector2(TutorialLandscape.ORIGINS[2] + 2388, 594)
		await _step(3)
		before = respawns
		if invalid != "vertical":
			_hold("move_left" if invalid == "left" else "move_right")
			await _step(6)
		_hold("jump")
		await _step()
		if invalid == "short":
			Input.action_release("jump")
		if invalid == "vertical":
			await _step(100)
		else:
			await _until(func(): return respawns > before, 180, invalid + " final jump is not rescued")
		_check(stage.phase == tutorial.Phase.RUN, invalid + " final jump never enters input wait")
		_release()
	# The unskipped slowdown must also finish, and retry must clear its global stop.
	stage._enter_room(2, false)
	player.position = Vector2(TutorialLandscape.ORIGINS[2] + 2388, 594)
	await _step(3)
	_hold("move_right")
	await _step(6)
	_hold("jump")
	await _until(func(): return stage.phase == tutorial.Phase.SLOW, 160, "Natural fall starts slowdown")
	await _step(2)
	_check(audio.music.pitch_scale < 1.0 and is_equal_approx(audio.music.pitch_scale, Engine.time_scale), "BGM speed and pitch follow the falling world's slowdown")
	_check(audio.jump.pitch_scale == 1.0 and audio.dash.pitch_scale == 1.0, "The cinematic changes only BGM, leaving movement SE at normal pitch")
	await _until(func(): return stage.phase == tutorial.Phase.WAIT, 160, "Natural slowdown reaches the mandatory stop")
	_check(paused and Engine.time_scale == 1.0 and stage.bridge.tip_collapsed, "Natural slowdown freezes a collapsed tip without leaving a global slow time scale")
	_check(audio.music.stream_paused, "Natural input wait pauses BGM")
	var frozen_music_position: float = audio.music.get_playback_position()
	await _step(10)
	_check(is_equal_approx(audio.music.get_playback_position(), frozen_music_position), "BGM position stays frozen during input wait")
	_check(player.get_node("Visuals/Body").animation == &"bonk", "The frozen fall keeps the existing head-impact sprite")
	await _capture("dash-wait-natural")
	_release()
	stage.get_node("PauseMenu").open()
	stage.get_node("PauseMenu").retry()
	_check(not paused and stage.phase == tutorial.Phase.RUN and player.controls_enabled and not stage.bridge.tip_collapsed, "Retry from input wait restores normal time, controls and bridge")
	_check(audio.music.pitch_scale == 1.0 and not audio.music.stream_paused, "Retry restores normal BGM speed and playback")
	_check(player.get_node("Visuals/Body").animation != &"bonk" and player.get_node("Visuals/Body").is_processing(), "Retry restores the normal pose updates")
	stage._enter_room(2, false)
	await _step(5)
	await _jump_at(1084)
	await _jump_at(1924)
	await _walk(2395)
	_hold("jump")
	await _until(func(): return stage.phase == tutorial.Phase.SLOW, 100, "A correct maximum-speed jump triggers the collapsing tip")
	if failed:
		_finish()
		return
	_check(player.get_node("Visuals/Body").animation == &"bonk", "The existing head-impact pose is visible as slowdown begins")
	await _capture("bridge-slow")
	_event("dash", true)
	await _key(KEY_ESCAPE)
	var menu_pitch: float = audio.music.pitch_scale
	await _step(3)
	_check(not audio.music.stream_paused and is_equal_approx(audio.music.pitch_scale, menu_pitch), "The pause menu keeps BGM playing at the held cinematic speed")
	_check(stage.get_node("PauseMenu").menu.get_node("SkipCinematic").visible, "Skip is available inside the pause menu during slowdown")
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await _step(2)
	_check(stage.phase == tutorial.Phase.WAIT and paused, "Skipping slowdown reaches mandatory input wait")
	_check(audio.music.stream_paused, "Skipping slowdown also pauses BGM at input wait")
	var wait_playback: AudioStreamPlayback = audio.music.get_stream_playback()
	_check(player.get_node("Visuals/Body").animation == &"bonk", "Skipped slowdown also freezes the existing head-impact pose")
	_check(not stage.player.controls_enabled, "Input wait cannot move the player")
	_hold("move_up")
	await _step(2)
	_check(stage.phase == tutorial.Phase.WAIT, "A dash held before the stop cannot succeed merely by adding Up")
	Input.action_release("move_up")
	var frozen: Vector2 = player.position
	await _step(10)
	_check(player.position == frozen, "World remains frozen until a fresh valid input")
	await _capture("dash-wait")
	stage.get_node("PauseMenu").open()
	_check(not stage.get_node("PauseMenu").menu.get_node("SkipCinematic").visible, "Mandatory input cannot be skipped")
	stage.get_node("PauseMenu").resume()
	_check(paused, "Closing pause restores input wait")
	inputs.open_settings()
	var binding := InputEventKey.new()
	binding.physical_keycode = KEY_C
	inputs.set_keyboard_binding("dash", 0, binding)
	_check("C" in stage._prompt.text, "Rebinding immediately updates the frozen prompt")
	inputs.close_settings()
	_check(paused, "Closing settings preserves the learning stop")
	_check(audio.music.stream_paused, "Pause and settings menus preserve the input wait's BGM stop")
	for key in inputs.keyboard_events("dash"):
		InputMap.action_erase_event("dash", key)
	inputs.save_settings()
	_check(stage._settings_button.visible, "Unbound required input offers settings instead of a softlock")
	inputs.restore_defaults()
	_check(inputs.pad_button_label(1, "DualSense Wireless Controller") == "○", "Sony glyph follows the mapped position")
	_check(inputs.pad_button_label(1, "Xbox One Controller") == "B", "Xbox glyph follows the mapped position")
	_check(inputs.pad_button_label(1, "Generic Gamepad") == "右ボタン", "Unknown controllers use position labels")
	_event("dash", false)
	_release()
	_hold("move_left")
	_event("dash", true)
	await _step(2)
	_check(stage.phase == tutorial.Phase.WAIT, "Wrong direction does not consume or exit the lesson")
	_check(audio.music.stream_paused, "An invalid dash does not resume BGM")
	Input.action_release("move_left")
	_hold("move_right")
	_hold("move_up")
	await _step(2)
	_check(stage.phase == tutorial.Phase.WAIT, "Changing direction while dash is held is not a fresh input")
	_event("dash", false)
	var dash_key := InputEventKey.new()
	dash_key.physical_keycode = KEY_X
	dash_key.pressed = true
	Input.parse_input_event(dash_key)
	await _step(2)
	_check(audio.music.pitch_scale == 1.0 and not audio.music.stream_paused, "The accepted dash resumes BGM at normal speed")
	_check(audio.music.get_stream_playback() == wait_playback, "The accepted dash continues the same BGM playback without restarting")
	_check(player.get_node("Visuals/Body").animation == &"jump", "A successful cinematic dash returns to the jumping pose")
	await _until(func(): return stage.completed, 160, "Fresh up-right dash guarantees safe landing")
	dash_key.pressed = false
	Input.parse_input_event(dash_key)
	_check(progress.is_cleared("tutorial"), "The clear flag is saved at landing")
	_check(stage.phase == tutorial.Phase.FADE and paused, "Landing starts the ending fade")
	await _key(KEY_ESCAPE)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	_event("dash", false)
	_release()
	await _step(3)
	_check(stage.phase == tutorial.Phase.CLEAR and stage._clear_layers.size() == 3, "Ending has exactly background, rocket and text layers")
	_check(root.get_visible_rect().encloses(stage._return_button.get_global_rect()), "Clear confirmation stays fully within the screen")
	print("CLEAR_BUTTON_RECT ", stage._return_button.get_global_rect())
	await _capture("clear")
	stage._return_to_select()
	await _step(8)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Clear confirmation returns to stage selection")
	_check(current_scene.get_node("Margin/Content/Stages/Stage1/Content/Cleared").text.contains("クリア済み"), "Stage selection shows the saved clear mark")
	_check(current_scene.get_node("Starfield").menu_background, "Selection shares the first room landscape")
	await _capture("stage-select")
	current_scene._return_to_title()
	await _step(110)
	_check(current_scene.get_node("Backdrop").menu_background, "Title shares the same first room landscape")
	_check(not current_scene.get_node("Center/Content/Continue").disabled, "A saved run enables Continue")
	await _capture("title")
	_finish()


func _hold(action: String, strength := 1.0) -> void:
	Input.action_press(action, strength)


func _event(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _step()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _step(2)


func _release() -> void:
	for action in ["move_right", "move_left", "move_up", "move_down", "wall_grab", "jump", "jump_up", "dash"]:
		Input.action_release(action)


func _x() -> float:
	return player.position.x - TutorialLandscape.ORIGINS[stage.room_index]


func _step(count := 1) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _until(predicate: Callable, frames: int, message: String) -> void:
	for i in frames:
		if predicate.call():
			_check(true, message)
			return
		await _step()
	_check(false, "%s (room %d, x %.1f, y %.1f, phase %d)" % [message, stage.room_index, _x(), player.position.y, stage.phase])


func _walk(x: float) -> void:
	_hold("move_right")
	await _until(func(): return _x() >= x, 400, "reach x %.0f" % x)


func _jump_at(x: float) -> void:
	await _walk(x)
	_hold("jump")
	await _step(3)
	await _until(func(): return player.is_on_floor(), 160, "land after long jump at %.0f" % x)
	Input.action_release("jump")


func _climb(x: float) -> void:
	_hold("wall_grab")
	_hold("move_up")
	await _walk(x)
	Input.action_release("wall_grab")
	Input.action_release("move_up")
	Input.action_release("move_right")
	await _step(10)


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("TUTORIAL_REDESIGN: " + message)


func _capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))
	_check(error == OK, "capture " + name)


func _finish() -> void:
	_release()
	paused = false
	Engine.time_scale = 1.0
	print("TUTORIAL_REDESIGN_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)
