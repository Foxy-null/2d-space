extends SceneTree

var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(4)
	var preview: Button = current_scene.get_node("Margin/Content/Preview")
	var gallery: Button = current_scene.get_node("Margin/Content/Gallery")
	_check(gallery.global_position.y >= preview.get_global_rect().end.y, "The gallery is below the environment preview")
	_check(gallery.get_global_rect().end.y < 704.0, "The gallery button stays inside the screen")
	if OS.get_cmdline_user_args().has("--screenshots"):
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/screenshots/stage-selection.png")
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	_check(root.gui_get_focus_owner() == gallery, "Directional navigation reaches the gallery")
	await _key(KEY_ENTER)
	_check(current_scene.scene_file_path.ends_with("gallery.tscn"), "Accept opens the real gallery scene")
	var catalogue = current_scene
	_check(catalogue.entries.item_count == 17 and root.gui_get_focus_owner() == catalogue.entries, "All seventeen entries are accessible by keyboard")
	await _key(KEY_DOWN)
	_check(catalogue.heading.text.contains("UMA妖怪エイリアン") and catalogue.description.text.contains("星間山荒・大赤斑"), "The enemy's group and individual name can be read again")
	if OS.get_cmdline_user_args().has("--screenshots"):
		RenderingServer.force_draw()
		DirAccess.make_dir_recursive_absolute("res://deliverables/stage6-pressure-update")
		root.get_texture().get_image().save_png("res://deliverables/stage6-pressure-update/gallery.png")
	for index in catalogue.ENTRIES.size():
		catalogue.entries.select(index)
		catalogue.entries.item_selected.emit(index)
		await _step(2)
		_check(not catalogue.description.text.is_empty() and catalogue.preview_world.get_child_count() == 1, "Every entry loads its artwork and explanation")
		_check(catalogue.description_scroll.get_global_rect().end.y + 8.0 <= catalogue.back.global_position.y, "Long descriptions scroll inside their panel and leave the return button accessible")
	await _key(KEY_ESCAPE)
	_check(current_scene.scene_file_path.ends_with("stage_select.tscn"), "Esc returns to stage selection")
	_check(root.gui_get_focus_owner() == current_scene.get_node("Margin/Content/Gallery"), "Return preserves gallery focus")
	print("GALLERY_TEST_OK (%d checks)" % checks)
	quit()


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _step()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _step(3)


func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("GALLERY: " + message)
		quit(1)
		assert(condition, message)
