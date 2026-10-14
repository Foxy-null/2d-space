extends Node2D

const ROOM_WIDTH := 1280.0
const TITLES := ["細い星の橋", "揺れる航路", "上下の急旋回", "嵐の回廊", "風の中の空中跳躍", "高速の帰還ゲート", "瞬間を蹴る", "極限の連携"]
const HINTS := [
	"短い入口からジャンプ。緑をつなぎ、狭い赤↑と青↓を通ろう。",
	"動くゲートを見てからダッシュ。失敗すると1面からやり直し。",
	"上下に並ぶ緑と4つの反転をつなぐ。ここが次のチェックポイント。",
	"風と動くゲートの中で緑を拾う。最後の青↓を通って出口へ。",
	"壁キックで赤↑へ。向かい風の穴を跳び、紫を取って空中ジャンプ。",
	"床と天井を往復し、最後は壁を掴んで高速の青↓へ蹴り込もう。",
	"速い赤↑のタイミングを壁で待つ。天井の穴から壁キック、Springへ。",
	"Spring・壁キック・反転を連続させ、向かい風の先の移動する青↓へ。",
]

var room_index := 0
var checkpoint_index := 0
var transitioning := false
var help_visible := false
var hints_visible := false
var completed := false
var cleared: Dictionary = {}
var _entering_room := false

@onready var player: PlayerController = $Player
@onready var camera: Camera2D = $Camera2D
@onready var rooms: Node2D = $Rooms


func _ready() -> void:
	player.get_node("Camera2D").enabled = false
	player.respawned.connect(_on_respawned)
	for room in rooms.get_children():
		var goal := room.get_node_or_null("Goal")
		if goal != null:
			goal.activated.connect(_on_arrival.bind(room.get_index()))
	$HUD/HelpButton.pressed.connect(func(): set_help_visible(not help_visible))
	$HUD/Help/Rows/Resume.pressed.connect(func(): set_help_visible(false))
	$HUD/Help/Rows/Hints.toggled.connect(_set_hints)
	$HUD/Help/Rows/Retry.pressed.connect(_retry)
	$HUD/Help/Rows/Return.pressed.connect(_return_to_select)
	player.set_respawn_position(_spawn_position(0))
	player.respawn()
	camera.make_current()
	_update_hud()


func _physics_process(_delta: float) -> void:
	_update_hud()
	if transitioning or help_visible:
		return
	var local_x := player.position.x - room_index * ROOM_WIDTH
	if player.position.y < -52 or player.position.y > 772 or local_x < -24:
		player.respawn()
	elif local_x >= 1258 and room_index < rooms.get_child_count() - 1:
		if room_index < 4 and player.is_on_floor():
			cleared[room_index] = true
		if cleared.has(room_index):
			_transition_to_next()


func _spawn_position(index: int) -> Vector2:
	return rooms.get_child(index).get_node("Spawn").global_position


func _transition_to_next() -> void:
	transitioning = true
	player.controls_enabled = false
	room_index += 1
	if room_index % 2 == 0:
		checkpoint_index = room_index
	# Enter the next room without advancing the saved checkpoint on even-numbered faces.
	_entering_room = true
	player.set_respawn_position(_spawn_position(room_index))
	player.respawn()
	_entering_room = false
	player.set_respawn_position(_spawn_position(checkpoint_index))
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "position", _camera_position(), 0.28)
	await tween.finished
	transitioning = false
	player.controls_enabled = not help_visible
	_update_hud()


func _camera_position() -> Vector2:
	return Vector2(room_index * ROOM_WIDTH + 640, 360)


func _on_respawned() -> void:
	if not _entering_room:
		room_index = checkpoint_index
		completed = false
		# Both faces must be replayed; opened exits cannot survive a failed pair.
		for index in range(checkpoint_index, rooms.get_child_count()):
			cleared.erase(index)
			var goal := rooms.get_child(index).get_node_or_null("Goal")
			if goal != null:
				goal.reset_activation()
	for room in rooms.get_children():
		for item in room.find_children("*", "Area2D", true, false):
			if item.has_method("reset_for_respawn"):
				item.reset_for_respawn()
		room.process_mode = Node.PROCESS_MODE_INHERIT if room.get_index() == room_index and not help_visible else Node.PROCESS_MODE_DISABLED
		_update_room(room)
	if not transitioning:
		camera.position = _camera_position()
		camera.reset_smoothing()
	_update_hud()


func _on_arrival(index: int) -> void:
	if index != room_index or transitioning or cleared.has(index):
		return
	cleared[index] = true
	completed = index == rooms.get_child_count() - 1
	_update_room(rooms.get_child(index))
	_update_hud()


func _update_room(room: Node2D) -> void:
	var done := cleared.has(room.get_index())
	var barrier := room.get_node_or_null("ExitBarrier")
	if barrier != null:
		barrier.get_node("Collision").set_deferred("disabled", done)
		barrier.get_node("Visual").visible = not done
	var goal := room.get_node_or_null("Goal")
	if goal != null:
		goal.set_progress(0, 0, "", "", done)
	# Pits remain open even after arrival: a retry must repeat the same challenge.
	var hint := room.get_node_or_null("ExitHint")
	if hint != null:
		hint.text = ("ステージ5クリア！" if room.get_index() == 7 else "次の面へ →") if done else "到着台に乗ると出口が開く"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("toggle_stage_hints"):
		set_help_visible(not help_visible)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("return_to_stage_select"):
		get_viewport().set_input_as_handled()
		if help_visible:
			set_help_visible(false)
		else:
			_return_to_select()


func set_help_visible(value: bool) -> void:
	help_visible = value
	$HUD/Help.visible = value
	player.controls_enabled = not value and not transitioning
	rooms.get_child(room_index).process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	if value:
		$HUD/Help/Rows/Resume.grab_focus()
	else:
		get_viewport().gui_release_focus()


func _set_hints(value: bool) -> void:
	hints_visible = value
	$HUD/Hint.visible = value
	for hint in get_tree().get_nodes_in_group("stage_5_hints"):
		hint.visible = value


func _retry() -> void:
	set_help_visible(false)
	player.respawn()


func _return_to_select() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")


func _update_hud() -> void:
	$HUD/Info/Rows/Title.text = "ステージ5　星嵐の試練　｜　%02d / 08　%s" % [room_index + 1, TITLES[room_index]]
	$HUD/Info/Rows/Status.text = "復帰：%d面　｜　2面ごと　　ダッシュ：%s　空中ジャンプ：%d" % [checkpoint_index + 1, "使用可" if player.is_dash_ready() else "回復待ち", player.get_available_extra_jump_count()]
	$HUD/Info/Rows/Stamina.value = player.get_wall_stamina()
	$HUD/Hint.text = HINTS[room_index]
	$HUD/Completion.visible = completed
	var inverted := player.gravity_direction < 0
	$HUD/Info.position.y = 616 if inverted else 16
	$HUD/HelpButton.position.y = 636 if inverted else 20
	$HUD/Hint.position.y = 580 if inverted else 110
	var checkpoint_label := rooms.get_child(room_index).get_node("Label" if room_index < 4 else "CheckpointLabel")
	checkpoint_label.visible = not inverted
