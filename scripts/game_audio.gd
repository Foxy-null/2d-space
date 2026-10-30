extends Node

const TITLE := preload("res://assets/audio/title.mp3")
const CLEAR := preload("res://assets/audio/clear.wav")
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
var _quiet: AudioStream
var _cleared := false


func _ready() -> void:
	# The first stage pauses gameplay during its clear screen and dash prompt.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)
	add_child(jump)
	add_child(dash)
	jump.stream = preload("res://assets/audio/jump.wav")
	dash.stream = preload("res://assets/audio/dash.wav")
	music.finished.connect(_on_music_finished)
	get_tree().scene_changed.connect(reset_scene)


func reset_scene() -> void:
	jump.stop()
	dash.stop()
	_cleared = false
	_quiet = null
	var scene := get_tree().current_scene
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
