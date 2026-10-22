extends SceneTree
## Open the actual help UI in every playable stage, including keyboard/controller input.

var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for scene in ["tutorial", "stage_2", "stage_3", "stage_4", "stage_6"]:
		change_scene_to_file("res://scenes/%s.tscn" % scene)
		await _step(4)
		var stage := current_scene
		var menu: PanelContainer = stage.get_node("HUD/HelpMenu" if scene == "stage_3" else "HUD/Help")
		_check(not menu.visible, "Help starts closed: " + scene)
		if scene == "stage_3":
			# Isolate modal priority using the real completion card.
			stage.get_node("HUD/Completion").show()
		await _key(KEY_H)
		_check(paused and menu.visible and not stage.player.controls_enabled, "H opens and pauses the stage: " + scene)
		if scene == "stage_3":
			_check(not stage.get_node("HUD/Completion").card.visible, "An existing completion card cannot cover the help menu")
		var player_position: Vector2 = stage.player.position
		await _step(10)
		_check(stage.player.position == player_position, "Reading help freezes real player physics: " + scene)
		var hint: Label = menu.get_node("Rows/Columns/HintScroll/Hint")
		var first_hint := hint.text
		_check(hint.text.contains("ジャンプ") or hint.text.contains("キック") or hint.text.contains("箱") or hint.text.contains("Shift"), "Help explains a usable action: " + scene)
		_check(root.get_visible_rect().encloses(menu.get_global_rect()), "The whole help menu fits the viewport: " + scene)
		var actions: Control = menu.get_node("Rows/Actions")
		_check(menu.get_global_rect().encloses(actions.get_global_rect()), "Resume, retry and return stay inside the panel: " + scene)
		if OS.get_cmdline_user_args().has("--screenshots"):
			await _capture(scene)
		await _key(KEY_ESCAPE)
		_check(not paused and not menu.visible and current_scene == stage, "Escape closes help and resumes the same stage: " + scene)
		if scene == "stage_3":
			_check(stage.get_node("HUD/Completion").card.visible, "Closing help restores the completion card")
			stage.get_node("HUD/Completion").hide()
		if scene == "stage_6":
			stage._load_room(11)
		elif scene == "stage_2":
			stage._set_checkpoint(1)
			stage.player.respawn()
		elif scene == "stage_4":
			stage.room_index = 1
			stage._set_checkpoint()
			stage.player.respawn()
		else:
			stage._set_room(1, false)
			stage.player.respawn()
		await _joy(JOY_BUTTON_Y)
		_check(paused and menu.visible and hint.text != first_hint, "Controller help shows the current room rather than stale advice: " + scene)
		if scene == "tutorial":
			_check(hint.text.contains("まだ達成していない目標") and hint.text.contains("壁"), "Tutorial help includes remaining lesson objectives")
		if scene == "stage_6":
			_check(hint.text.contains("投擲を6回") and hint.text.contains("20秒") and hint.text.contains("檻の屋根の鍵") and hint.text.contains("自分だけ入口"), "Final help explains all three wins and the revised fall recovery")
			_check(stage.room.find_children("*", "Label", false, false).is_empty() and not stage.room.arrival.get_node("Bubble").visible, "Stage 6 has no explanation labels scattered over the course")
			var enemy_position: Vector2 = stage.enemy.position
			await _step(10)
			_check(stage.enemy.position == enemy_position, "The enemy also freezes while help is open")
			var scroll: ScrollContainer = menu.get_node("Rows/Columns/HintScroll")
			scroll.grab_focus()
			await _key(KEY_DOWN)
			_check(scroll.scroll_vertical > 0, "Long final-stage help scrolls with the keyboard")
			await _key(KEY_RIGHT)
			_check(root.gui_get_focus_owner() == menu.get_node("Rows/Actions/Resume"), "The player can leave the scroll area with the direction key")
			scroll.grab_focus()
			var before_scroll := scroll.scroll_vertical
			await _joy(JOY_BUTTON_DPAD_DOWN)
			_check(scroll.scroll_vertical > before_scroll, "The controller can also scroll long hints")
			await _joy(JOY_BUTTON_DPAD_RIGHT)
			_check(root.gui_get_focus_owner() == menu.get_node("Rows/Actions/Resume"), "The controller can return from reading hints to the buttons")
			if OS.get_cmdline_user_args().has("--screenshots"):
				scroll.scroll_vertical = 0
				await _capture("stage_6_final")
		menu.get_node("Rows/Actions/Resume").pressed.emit()
		await _step(2)
		_check(not paused and stage.player.controls_enabled, "Resume works while the tree is paused: " + scene)
		await _key(KEY_H)
		menu.get_node("Rows/Actions/Retry").pressed.emit()
		await _step(2)
		_check(not paused and not menu.visible, "Retry resumes the game: " + scene)
		await _key(KEY_H)
		menu.get_node("Rows/Actions/Return").pressed.emit()
		await _step(4)
		_check(not paused and current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Return leaves no paused state in stage selection: " + scene)
	print("STAGE_HELP_TEST_OK (%d checks)" % checks)
	quit()


func _capture(name: String) -> void:
	await _step(2)
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/help")
	root.get_texture().get_image().save_png("res://docs/screenshots/help/%s.png" % name)


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


func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await _step()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _step(2)


func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("STAGE_HELP: " + message)
		quit(1)
