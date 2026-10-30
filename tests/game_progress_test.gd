extends SceneTree

const Progress := preload("res://scripts/collection_progress.gd")
var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var progress = root.get_node("CollectionProgress")
	var inputs = root.get_node("InputSettings")
	var display = root.get_node("DisplaySettings")
	_check(not progress.has_save(), "Missing progress disables Continue")
	_check(progress.start_new_game() == OK and progress.has_save(), "New Game creates a resumable zero-progress save")
	_check(progress.collect_scroll("tutorial", progress.TUTORIAL_SCROLL) == OK, "New tutorial scroll saves")
	_check(progress.mark_cleared("tutorial") == OK, "Clear saves at the actual stage endpoint")
	_check(progress.mark_cleared("chaser") == OK, "Stage 6 clear is accepted by the shared save")
	_check(progress.collect_scroll("tower", "spring_alcove") == OK, "New tower collection saves independently")
	var reloaded := Progress.new()
	reloaded.load_progress()
	_check(reloaded.has_save() and reloaded.is_cleared("tutorial") and reloaded.get_count("tutorial") == 1 and reloaded.get_count("tower") == 1, "New process state restores clear marks and collections")
	_check(reloaded.is_cleared("chaser"), "Stage 6 clear survives reloading")
	reloaded.free()
	var original_save_path: String = progress.save_path
	progress.save_path = "user://missing-clear-parent/progress.cfg"
	_check(progress.mark_cleared("gravity") != OK and not progress.is_cleared("gravity"), "Failed clear save never updates the saved clear state")
	var notice: AcceptDialog = progress.get_node("ClearSaveError")
	_check(notice.visible, "A failed clear save is visible to the player")
	notice.queue_free()
	progress.save_path = original_save_path
	var custom := InputEventKey.new()
	custom.physical_keycode = KEY_C
	inputs.set_keyboard_binding("dash", 0, custom)
	display.windowed_size = Vector2i(1024, 640)
	_check(inputs.has_custom_settings() and display.has_custom_settings(), "Changed input and display settings trigger New Game confirmation")
	var old_input_path: String = inputs.save_path
	inputs.save_path = "user://missing-parent/input.cfg"
	var saved := FileAccess.get_file_as_string(progress.save_path)
	_check(progress.start_new_game() != OK, "Failure in a settings save rejects the complete reset")
	_check(progress.is_cleared("tutorial") and progress.get_count("tutorial") == 1 and progress.get_count("tower") == 1, "Failed reset restores progress in memory")
	_check(FileAccess.get_file_as_string(progress.save_path) == saved, "Failed reset preserves the original progress file")
	_check(inputs.keyboard_events("dash")[0].physical_keycode == KEY_C and display.windowed_size == Vector2i(1024, 640), "Failed reset also restores input and display state")
	inputs.save_path = old_input_path
	_check(progress.start_new_game() == OK, "Full reset commits successfully")
	_check(not progress.is_cleared("tutorial") and progress.get_count("tutorial") == 0 and progress.get_count("tower") == 0, "Reset clears every stage and collectible")
	_check(not progress.is_cleared("chaser"), "New Game also resets Stage 6")
	_check(not inputs.has_custom_settings() and not display.has_custom_settings(), "Reset includes input and display settings")
	reloaded = Progress.new()
	reloaded.load_progress()
	_check(reloaded.has_save() and not reloaded.is_cleared("tutorial") and reloaded.get_count("tower") == 0, "Restart sees the fresh run, not old progress")
	reloaded.free()
	var legacy := ConfigFile.new()
	legacy.set_value("tutorial", "scrolls", ["jump_turn_01", "wall_loft_01"])
	legacy.set_value("tower", "scrolls", ["old_tower"])
	legacy.set_value("gravity", "scrolls", ["keep_gravity"])
	legacy.set_value("progress", "cleared", ["tower", "gravity"])
	legacy.save("user://legacy.cfg")
	reloaded = Progress.new()
	reloaded.save_path = "user://legacy.cfg"
	reloaded.load_progress()
	_check(reloaded.get_count("tutorial") == 0 and reloaded.get_count("tower") == 0, "Migration retires both replaced courses' old scroll IDs")
	_check(not reloaded.is_cleared("tower") and reloaded.is_cleared("gravity") and reloaded.has_scroll("gravity", "keep_gravity"), "Migration clears only the old tower achievement and preserves other stages")
	_check(reloaded.collect_scroll("tower", "spring_alcove") == OK and reloaded.mark_cleared("tower") == OK, "The new tower achievements save after migration")
	reloaded.load_progress()
	_check(reloaded.has_scroll("tower", "spring_alcove") and reloaded.is_cleared("tower"), "Migration happens once; new tower progress survives reloading")
	_check(reloaded.collect_scroll("tutorial", progress.TUTORIAL_SCROLL) == OK and reloaded.get_count("tutorial") == 1, "Migrated tutorial collection stays within 0/1 to 1/1")
	reloaded.free()
	legacy.erase_section("tower")
	legacy.save("user://legacy-only-tutorial.cfg")
	reloaded = Progress.new()
	reloaded.save_path = "user://legacy-only-tutorial.cfg"
	reloaded.load_progress()
	_check(reloaded.has_save() and reloaded.get_count("tutorial") == 0, "A valid legacy save still enables Continue after retired tutorial IDs are dropped")
	reloaded.free()
	# Exercise the actual title confirmation: cancel must be non-destructive.
	progress.mark_cleared("tower")
	change_scene_to_file("res://scenes/start_screen.tscn")
	await _step(100)
	var title := current_scene
	title._start()
	_check(title._new_game_dialog.visible and progress.is_cleared("tower"), "New Game asks before deleting existing data")
	title._new_game_dialog.canceled.emit()
	title._new_game_dialog.hide()
	_check(current_scene == title and progress.is_cleared("tower"), "Cancelling keeps progress and stays at title")
	title._continue()
	await _step(30)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn" and progress.is_cleared("tower"), "Continue retains progress and opens stage selection")
	current_scene._return_to_title()
	await _step(100)
	title = current_scene
	title._start()
	title._new_game_dialog.confirmed.emit()
	await _step(30)
	_check(current_scene.scene_file_path == "res://scenes/tutorial.tscn" and not progress.is_cleared("tower"), "Confirmed reset starts Stage 1 with every clear removed")
	print("GAME_PROGRESS_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("GAME_PROGRESS: " + message)
