extends Node

const TITLE := preload("res://assets/audio/title.mp3")
const CLEAR := preload("res://assets/audio/clear.wav")
const IRIS_CLOSE := preload("res://assets/audio/iris-close.wav")
const IRIS_OPEN := preload("res://assets/audio/iris-open.wav")
const STAGE_TRACKS := {
	"res://scenes/tutorial.tscn": "c",
	"res://scenes/stage_2.tscn": "a",
	"res://scenes/stage_3.tscn": "b",
	"res://scenes/stage_4.tscn": "c",
	"res://scenes/stage_5.tscn": "a",
	"res://scenes/stage_6.tscn": "b",
}
const TRACKS := {
	"a": [preload("res://assets/audio/stage-a-normal.mp3"), preload("res://assets/audio/stage-a-quiet.mp3")],
	"b": [preload("res://assets/audio/stage-b-normal.mp3"), preload("res://assets/audio/stage-b-quiet.mp3")],
	"c": [preload("res://assets/audio/stage-c-normal.mp3"), preload("res://assets/audio/stage-c-quiet.mp3")],
}

var music := AudioStreamPlayer.new()
var jump := AudioStreamPlayer.new()
var dash := AudioStreamPlayer.new()
var ui_move := AudioStreamPlayer.new()
var ui_select := AudioStreamPlayer.new()
var menu_open := AudioStreamPlayer.new()
var scroll_touch := AudioStreamPlayer.new()
var scroll_collect := AudioStreamPlayer.new()
var iris := AudioStreamPlayer.new()
var death := AudioStreamPlayer.new()
var _ui_move_frame := -1
var _quiet: AudioStream
var _cleared := false


func _ready() -> void:
	# The first stage pauses gameplay during its clear screen and dash prompt.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for player in [music, jump, dash, ui_move, ui_select, menu_open, scroll_touch, scroll_collect, iris, death]:
		add_child(player)
	jump.stream = preload("res://assets/audio/jump.wav")
	dash.stream = preload("res://assets/audio/dash.wav")
	ui_move.stream = preload("res://assets/audio/ui-move.wav")
	ui_select.stream = preload("res://assets/audio/ui-select.wav")
	menu_open.stream = preload("res://assets/audio/menu-open.wav")
	scroll_touch.stream = preload("res://assets/audio/scroll-touch.wav")
	scroll_collect.stream = preload("res://assets/audio/scroll-collect.wav")
	death.stream = preload("res://assets/audio/death.wav")
	iris.volume_db = -8.0
	death.volume_db = -4.0
	ui_move.volume_db = -4.0
	menu_open.volume_db = -4.0
	scroll_touch.volume_db = -4.0
	music.finished.connect(_on_music_finished)
	get_tree().scene_changed.connect(reset_scene)
	# The initial scene does not emit scene_changed; wait until it is loaded.
	reset_scene.call_deferred()
	get_tree().node_added.connect(_connect_button)
	for button in get_tree().root.find_children("*", "BaseButton", true, false):
		_connect_button(button)


func _connect_button(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_play_ui_select):
		node.focus_entered.connect(_play_ui_move.bind(node))
		node.mouse_entered.connect(_play_ui_move.bind(node))
		node.pressed.connect(_play_ui_select)


func _play_ui_move(button: BaseButton) -> void:
	if button.disabled or not button.is_visible_in_tree() or _ui_move_frame == Engine.get_process_frames():
		return
	_ui_move_frame = Engine.get_process_frames()
	ui_move.play()


func _play_ui_select() -> void:
	ui_move.stop()
	_ui_move_frame = Engine.get_process_frames()
	ui_select.play()


func play_menu_open() -> void:
	ui_move.stop()
	_ui_move_frame = Engine.get_process_frames()
	menu_open.play()


func reset_scene() -> void:
	jump.stop()
	dash.stop()
	scroll_touch.stop()
	scroll_collect.stop()
	iris.stop()
	death.stop()
	iris.stream_paused = false
	death.stream_paused = false
	_cleared = false
	_quiet = null
	var scene := get_tree().current_scene
	if scene == null:
		return
	var family: String = STAGE_TRACKS.get(scene.scene_file_path, "")
	if not family.is_empty():
		_quiet = TRACKS[family][1]
		_play_music(TRACKS[family][0])
	elif scene.scene_file_path in ["res://scenes/start_screen.tscn", "res://scenes/stage_select.tscn"]:
		_play_music(TITLE)
	else:
		_play_music(null)
	var player := scene.find_child("Player", true, false) as PlayerController
	if player != null and not player.movement_action.is_connected(play_movement):
		player.movement_action.connect(play_movement)


func play_movement(action: String) -> void:
	match action:
		"dash":
			dash.play()
		"jump", "wall_jump", "air_jump", "creature_jump", "superdash":
			jump.play()


func play_clear() -> void:
	if _cleared:
		return
	_cleared = true
	jump.stop()
	dash.stop()
	_play_music(CLEAR)


func set_quiet(value: bool) -> void:
	if _cleared or get_tree().current_scene == null:
		return
	var family: String = STAGE_TRACKS.get(get_tree().current_scene.scene_file_path, "")
	if not family.is_empty():
		_play_music(TRACKS[family][1 if value else 0])


func _play_music(stream: AudioStream) -> void:
	music.pitch_scale = 1.0
	music.stream_paused = false
	if music.stream == stream and music.playing:
		return
	music.stop()
	music.stream = stream
	if stream != null:
		music.play()


func _on_music_finished() -> void:
	if music.stream == CLEAR:
		_play_music(_quiet)
