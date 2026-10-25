extends Node

const STAGE_IDS := ["tutorial", "tower", "gravity", "companion", "canyon"]
const TOTALS := {"tutorial": 6, "tower": 6, "gravity": 8, "companion": 7, "canyon": 5}
var save_path := "user://collection_progress.cfg"
var _collected: Dictionary = {}

func _ready() -> void:
	load_progress()

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
	var config := ConfigFile.new()
	for stage in STAGE_IDS:
		config.set_value(stage, "scrolls", next.get(stage, []))
	# Commit both the file and memory only after the replacement is ready.
	var temporary_path := save_path + ".tmp"
	var result := config.save(temporary_path)
	if result == OK:
		result = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(save_path))
	if result != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
		return result
	_collected = next
	return OK

func load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	for stage in STAGE_IDS:
		var scrolls = config.get_value(stage, "scrolls", [])
		if not scrolls is Array:
			continue
		for scroll_id in scrolls:
			if not scroll_id is String or not _valid_id(stage, scroll_id):
				continue
			if not _collected.has(stage):
				_collected[stage] = []
			if not _collected[stage].has(scroll_id):
				_collected[stage].append(scroll_id)

func _valid_id(stage_id: String, scroll_id: String) -> bool:
	return stage_id in STAGE_IDS and not scroll_id.strip_edges().is_empty() and scroll_id.length() <= 128
