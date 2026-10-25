extends SceneTree

const Progress := preload("res://scripts/collection_progress.gd")
const TEST_PATH := "user://collection_progress_test.cfg"
var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func _run() -> void:
	var progress := Progress.new()
	progress.save_path = TEST_PATH
	var args := OS.get_cmdline_user_args()
	if "--write" in args:
		_clean()
		_check(progress.collect_scroll("tutorial", "upper_alcove") == OK, "A separate game process saves a confirmed scroll")
	elif "--read" in args:
		progress.load_progress()
		_check(progress.has_scroll("tutorial", "upper_alcove") and progress.get_count("tutorial") == 1, "A restarted game process restores its saved scroll")
		_clean()
	else:
		_clean()
		progress.load_progress()
		_check(progress.get_count("tutorial") == 0 and progress.get_count("unknown") == 0, "A missing save starts empty")
		_check(progress.collect_scroll("unknown", "scroll") == ERR_INVALID_PARAMETER, "Unknown stages are rejected")
		for invalid in ["", "   ", "x".repeat(129)]:
			_check(progress.collect_scroll("tutorial", invalid) == ERR_INVALID_PARAMETER, "Invalid scroll identifiers are rejected")
		_check(not FileAccess.file_exists(TEST_PATH), "Rejected input does not create a save")
		_check(progress.collect_scroll("tutorial", "upper_alcove") == OK, "The first confirmed scroll saves immediately")
		var saved := FileAccess.get_file_as_string(TEST_PATH)
		_check(progress.collect_scroll("tutorial", "upper_alcove") == OK and progress.get_count("tutorial") == 1, "Collecting the same scroll twice counts once")
		_check(FileAccess.get_file_as_string(TEST_PATH) == saved, "Duplicate collection leaves the save unchanged")
		_check(progress.collect_scroll("tower", "left_detour") == OK, "A second stage saves independently")
		var reloaded := Progress.new()
		reloaded.save_path = TEST_PATH
		reloaded.load_progress()
		_check(reloaded.get_count("tutorial") == 1 and reloaded.has_scroll("tower", "left_detour"), "Reload restores every saved stage")
		reloaded.free()
		saved = FileAccess.get_file_as_string(TEST_PATH)
		progress.save_path = TEST_PATH + "/missing/save.cfg"
		_check(progress.collect_scroll("tutorial", "failed_write") != OK, "A missing parent reports the save failure")
		_check(progress.get_count("tutorial") == 1 and not progress.has_scroll("tutorial", "failed_write"), "A failed write preserves confirmed memory")
		_check(FileAccess.get_file_as_string(TEST_PATH) == saved, "A failed write preserves the existing save")
		progress.save_path = TEST_PATH + ".directory"
		DirAccess.make_dir_absolute(ProjectSettings.globalize_path(progress.save_path))
		var marker := FileAccess.open(progress.save_path + "/keep", FileAccess.WRITE)
		marker.store_string("keep")
		marker.close()
		_check(progress.collect_scroll("tutorial", "failed_replace") != OK, "A target directory reports replacement failure")
		_check(progress.get_count("tutorial") == 1 and FileAccess.get_file_as_string(progress.save_path + "/keep") == "keep", "A failed replacement preserves memory and destination")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path + "/keep"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		progress.save_path = TEST_PATH
		var malformed := ConfigFile.new()
		malformed.set_value("tutorial", "scrolls", ["valid", "valid", 42, "", "x".repeat(129)])
		malformed.set_value("tower", "scrolls", {"wrong": "type"})
		malformed.set_value("unknown", "scrolls", ["unknown_scroll"])
		_check(malformed.save(TEST_PATH) == OK, "Malformed value fixture saves")
		var filtered := Progress.new()
		filtered.save_path = TEST_PATH
		filtered.load_progress()
		_check(filtered.get_count("tutorial") == 1 and filtered.has_scroll("tutorial", "valid"), "Loading ignores invalid IDs and duplicates")
		_check(filtered.get_count("tower") == 0 and filtered.get_count("unknown") == 0, "Loading ignores invalid types and unknown stages")
		var corrupt := FileAccess.open(TEST_PATH, FileAccess.WRITE)
		corrupt.store_string("[broken\n")
		corrupt.close()
		filtered.load_progress()
		_check(filtered.has_scroll("tutorial", "valid"), "A corrupt reload preserves confirmed memory")
		filtered.free()
		_clean()
	progress.free()
	print("Collection progress tests: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _clean() -> void:
	for path in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
