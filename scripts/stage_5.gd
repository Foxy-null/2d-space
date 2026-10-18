extends Node2D

const TITLES := ["溶岩の飛び石", "Springで大跳躍", "天井の帰り道"]
const HINTS := [
	"小さな足場をジャンプで渡ろう。上りと下りで跳ぶ距離を調整しよう。",
	"入口のSpringで高台へ。紫のばね靴を取り、空中でもう一度ジャンプ！",
	"赤い↑で天井へ。右端の青い↓で床へ戻り、旗のある到着台を踏もう。",
]
const ROOM_WIDTH := 1280.0
var room_index := 0
var transitioning := false
var help_visible := false
var hints_visible := false
var completed := false

@onready var player: PlayerController = $Player
@onready var camera: Camera2D = $Camera2D
@onready var rooms: Node2D = $Rooms


func _ready() -> void:
	player.get_node("Camera2D").enabled = false
	player.respawned.connect(_on_respawned)
	$Rooms/Room3/Goal.activated.connect(_on_completed)
	$Rooms/Room3/Goal.set_progress(0, 0, "", "", false)
	$HUD/HelpButton.pressed.connect(func(): set_help_visible(not help_visible))
	$HUD/Help/Rows/Resume.pressed.connect(func(): set_help_visible(false))
	$HUD/Help/Rows/Hints.toggled.connect(_set_hints)
	$HUD/Help/Rows/Retry.pressed.connect(_retry)
	$HUD/Help/Rows/Return.pressed.connect(_return_to_select)
	_set_checkpoint()
	player.respawn()
	camera.make_current()
	_update_hud()


func _physics_process(_delta: float) -> void:
	if transitioning or help_visible:
		return
	var local_x := player.position.x - room_index * ROOM_WIDTH
	if player.position.y < -52 or player.position.y > 772 or local_x < -24:
		player.respawn()
	elif local_x >= 1260 and room_index < rooms.get_child_count() - 1 and player.is_on_floor():
		_transition_to_next()
	_update_hud()


func _set_checkpoint() -> void:
	var entrance: Marker2D = rooms.get_child(room_index).get_node("Spawn")
	player.set_respawn_position(entrance.global_position)


func _transition_to_next() -> void:
	transitioning = true
	player.controls_enabled = false
	room_index += 1
	_set_checkpoint()
	player.respawn()
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "position", Vector2(room_index * ROOM_WIDTH + 640, 360), 0.28)
	await tween.finished
	transitioning = false
	player.controls_enabled = not help_visible
	_update_hud()


func _on_respawned() -> void:
	for item in rooms.get_child(room_index).get_node("Items").get_children():
		item.reset_for_respawn()
	if not transitioning:
		camera.position = Vector2(room_index * ROOM_WIDTH + 640, 360)
		camera.reset_smoothing()


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
	if value:
		$HUD/Help/Rows/Resume.grab_focus()
	else:
		get_viewport().gui_release_focus()


func _set_hints(value: bool) -> void:
	hints_visible = value
	$HUD/Hint.visible = value


func _retry() -> void:
	set_help_visible(false)
	player.respawn()


func _return_to_select() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")


func _on_completed() -> void:
	completed = true
	$HUD/Completion.show()
	$Rooms/Room3/Goal.set_progress(0, 0, "", "", true)


func _update_hud() -> void:
	$HUD/Info/Rows/Title.text = "ステージ5　溶岩ジャンプ回廊　｜　%02d / 03　%s" % [room_index + 1, TITLES[room_index]]
	$HUD/Info/Rows/Status.text = "重力：%s　　ダッシュ：%s　　復帰地点：部屋%d" % ["上 ↑" if player.gravity_direction < 0 else "下 ↓", "使用可" if player.is_dash_ready() else "回復待ち", room_index + 1]
	$HUD/Info/Rows/Stamina.value = player.get_wall_stamina()
	$HUD/Hint.text = HINTS[room_index]
