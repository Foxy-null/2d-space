extends Node2D

const TITLES := ["広い回廊", "空中の関門", "相棒と越える", "横切る三連", "上下の関門", "最後の三関門"]
const HINTS := [
	"左右の壁を交互に蹴って上へ。赤いトゲは触れると即やり直し。中央の台で休もう。",
	"床のない壁渡り。トゲの往復を見て、通り道が空いた瞬間に壁を蹴ろう。",
	"Shiftを押したまま緑の相棒を運ぼう。運搬中も壁キック可能。空中でジャンプがもう1回。",
	"左右へ横切る3つのトゲ。安全な壁面でタイミングを調整してから渡ろう。",
	"上下のトゲが通過したら壁を蹴ろう。壁掴みで待つとスタミナを使うので注意。",
	"緑の相棒と最後まで。壁キックと追加ジャンプで3つの関門を越え、到着台へ！",
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
	add_to_group("stage_four")
	player.get_node("Camera2D").enabled = false
	player.respawned.connect(_on_respawned)
	$Rooms/Room6/Goal.activated.connect(_on_completed)
	$Rooms/Room6/Goal.set_progress(1, 1, "", "緑の相棒を運ぼう", false)
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
	elif local_x >= 1260 and room_index < 5 and player.is_on_floor() and _carry_requirement_met():
		_transition_to_next()
	_update_hud()


func _set_checkpoint() -> void:
	player.set_respawn_position(Vector2(room_index * ROOM_WIDTH + 110, 594))


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
	for room in rooms.get_children():
		for spike in room.get_node("Hazards").get_children():
			spike.reset_for_respawn()
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
	if not _carry_requirement_met():
		return
	completed = true
	$HUD/Completion.show()
	$Rooms/Room6/Goal.set_progress(0, 0, "", "", true)


func _update_hud() -> void:
	$HUD/Info/Rows/Title.text = "ステージ4　星渡りの回廊　｜　%02d / 06　%s" % [room_index + 1, TITLES[room_index]]
	$HUD/Info/Rows/Status.text = "トゲ：接触で即死　 ダッシュ：%s　 追加ジャンプ：%d　 復帰：部屋%d" % ["使用可" if player.is_dash_ready() else "回復待ち", player.get_available_extra_jump_count(), room_index + 1]
	$HUD/Info/Rows/Stamina.value = player.get_wall_stamina()
	$HUD/Hint.text = HINTS[room_index]
	if room_index in [2, 5]:
		rooms.get_child(room_index).get_node("ExitLabel").text = "ゴール" if completed else ("相棒と進む →" if _carry_requirement_met() else "緑の相棒が必要")
	if room_index == 5 and not completed:
		var goal: ArrivalSwitch = $Rooms/Room6/Goal
		var should_lock := not _carry_requirement_met()
		if goal.locked != should_lock:
			goal.set_progress(1 if should_lock else 0, 1, "", "緑の相棒を運ぼう", false)


func _carry_requirement_met() -> bool:
	return room_index not in [2, 5] or player.get_held_object() == rooms.get_child(room_index).get_node("Items/JumpCreature")
