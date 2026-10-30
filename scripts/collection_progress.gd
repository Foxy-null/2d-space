extends Node

signal progress_changed

const STAGE_IDS := ["tutorial", "tower", "gravity", "companion", "canyon", "chaser"]
const TUTORIAL_SCROLL := "castle_summit_01"
const TOWER_SCROLLS := ["spring_alcove", "crystal_cavern", "crumbling_cavern", "bumper_cavern"]
const TOTALS := {"tutorial": 1, "tower": 4, "gravity": 10, "companion": 12, "canyon": 12, "chaser": 0}
var save_path := "user://collection_progress.cfg"
var _collected: Dictionary = {}
var _cleared: Array[String] = []
var _has_save := false


func _ready() -> void:
	load_progress()


func has_save() -> bool:
	return _has_save


func is_cleared(stage_id: String) -> bool:
	return stage_id in _cleared


func has_scroll(stage_id: String, scroll_id: String) -> bool:
	return _valid_id(stage_id, scroll_id) and _collected.get(stage_id, []).has(scroll_id)


func get_count(stage_id: String) -> int:
	return _collected.get(stage_id, []).size() if stage_id in STAGE_IDS else 0


func collect_scroll(stage_id: String, scroll_id: String) -> Error:
	if not _valid_id(stage_id, scroll_id):
		return ERR_INVALID_PARAMETER
	if has_scroll(stage_id, scroll_id):
		return OK
	var next := _collected.duplicate(true)
	if not next.has(stage_id):
		next[stage_id] = []
	next[stage_id].append(scroll_id)
	return _commit(next, _cleared)


func mark_cleared(stage_id: String) -> Error:
	if stage_id not in STAGE_IDS:
		return ERR_INVALID_PARAMETER
	if is_cleared(stage_id):
		return OK
	var next := _cleared.duplicate()
	next.append(stage_id)
	var error := _commit(_collected, next)
	if error != OK and is_inside_tree():
		var notice := AcceptDialog.new()
		notice.name = "ClearSaveError"
		notice.process_mode = Node.PROCESS_MODE_ALWAYS
		notice.title = "保存エラー"
		notice.dialog_text = "クリア記録を保存できませんでした。\n保存先を確認して、もう一度クリアしてください。"
		notice.confirmed.connect(notice.queue_free)
		notice.canceled.connect(notice.queue_free)
		add_child(notice)
		notice.popup_centered(Vector2i(620, 230))
	return error


func _commit(scrolls: Dictionary, cleared: Array[String]) -> Error:
	var config := ConfigFile.new()
	config.set_value("progress", "version", 3)
	config.set_value("progress", "started", true)
	config.set_value("progress", "cleared", cleared)
	for stage in STAGE_IDS:
		config.set_value(stage, "scrolls", scrolls.get(stage, []))
	var temporary_path := save_path + ".tmp"
	var error := config.save(temporary_path)
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(save_path))
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
		return error
	_collected = scrolls.duplicate(true)
	_cleared.assign(cleared)
	_has_save = true
	progress_changed.emit()
	return OK


func load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	var old_tower: bool = config.get_value("progress", "version", 1) != 3
	var collected: Dictionary = {}
	for stage in STAGE_IDS:
		if stage == "tower" and old_tower:
			continue
		var scrolls = config.get_value(stage, "scrolls", [])
		if not scrolls is Array:
			continue
		for scroll_id in scrolls:
			if not scroll_id is String or not _valid_id(stage, scroll_id):
				continue
			if not collected.has(stage):
				collected[stage] = []
			if not collected[stage].has(scroll_id):
				collected[stage].append(scroll_id)
	var cleared: Array[String] = []
	var saved_clears = config.get_value("progress", "cleared", [])
	if saved_clears is Array:
		for stage in saved_clears:
			if stage is String and stage in STAGE_IDS and stage not in cleared and not (stage == "tower" and old_tower):
				cleared.append(stage)
	_collected = collected
	_cleared = cleared
	_has_save = config.get_value("progress", "started", false) == true or not collected.is_empty() or not cleared.is_empty()
	for stage in STAGE_IDS:
		_has_save = _has_save or (config.has_section_key(stage, "scrolls") and config.get_value(stage, "scrolls") is Array)
	progress_changed.emit()


func start_new_game() -> Error:
	var inputs := get_node("/root/InputSettings")
	var display := get_node("/root/DisplaySettings")
	var files: Dictionary = {}
	for path in [save_path, inputs.save_path, display.save_path]:
		files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	var old_scrolls := _collected.duplicate(true)
	var old_clears := _cleared.duplicate()
	var old_saved := _has_save
	var old_bindings: Dictionary = {}
	for action in inputs.ACTIONS:
		old_bindings[action] = InputMap.action_get_events(action).duplicate(true)
	var old_size: Vector2i = display.windowed_size
	var old_fullscreen: bool = display.is_fullscreen()
	var error := _commit({}, [])
	if error == OK:
		error = inputs.restore_defaults()
	if error == OK:
		error = display.restore_defaults()
	if error == OK:
		return OK
	# The three existing save files are one New Game operation, including memory.
	for path in files:
		if files[path] == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_buffer(files[path])
	_collected = old_scrolls
	_cleared.assign(old_clears)
	_has_save = old_saved
	for action in old_bindings:
		InputMap.action_erase_events(action)
		for event in old_bindings[action]:
			InputMap.action_add_event(action, event)
	display.windowed_size = old_size
	if display.available:
		display._restore_window()
		if old_fullscreen:
			get_window().mode = Window.MODE_FULLSCREEN
	inputs.bindings_changed.emit()
	progress_changed.emit()
	return error


func _valid_id(stage_id: String, scroll_id: String) -> bool:
	return stage_id in STAGE_IDS and not scroll_id.strip_edges().is_empty() and scroll_id.length() <= 128 and (stage_id != "tutorial" or scroll_id == TUTORIAL_SCROLL) and (stage_id != "tower" or scroll_id in TOWER_SCROLLS)
