extends Node2D

const TITLES := ["相棒と登る階段", "壁キックの峡谷", "低い天井の回廊", "峠を越えて下る", "離れ小島の大跳躍", "折り返しの頂"]
const HINTS := [
	"全室、相棒を持ったまま出口へ。空中ジャンプは頂点近くで使い、段ごとに着地して回復。",
	"相棒を持つと壁登りはできない。左右の壁を交互に蹴って峡谷を登ろう。",
	"低い屋根の下を渡る。頭をぶつけると高さを失うので、追加ジャンプは慌てずに。",
	"最初は登り、峠からは下り。飛びすぎないよう空中で向きを調整しよう。",
	"小島の間は広い。横へ走って跳び、落ち始める前に相棒のジャンプを使おう。",
	"中央の足場から左上へ折り返す。その後は右の低い足場へ大きく渡ろう。",
]
const ROOM_WIDTH := 1280.0
var room_index := 0
var transitioning := false
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
	_set_checkpoint()
	player.respawn()
	camera.make_current()
	_update_hud()


func _physics_process(_delta: float) -> void:
	if transitioning:
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
	player.controls_enabled = true
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


func set_hints_visible(value: bool) -> void:
	hints_visible = value
	$HUD/Hint.visible = value


func _on_completed() -> void:
	if not _carry_requirement_met():
		return
	completed = true
	$HUD/Completion.show()
	$Rooms/Room6/Goal.set_progress(0, 0, "", "", true)


func _update_hud() -> void:
	$HUD/Info/Rows/Title.text = "ステージ4　星渡りの回廊　｜　%02d / 06　%s" % [room_index + 1, TITLES[room_index]]
	$HUD/Info/Rows/Status.text = "相棒の運搬が必須　 ダッシュ：%s　 追加ジャンプ：%d　 復帰：部屋%d" % ["使用可" if player.is_dash_ready() else "回復待ち", player.get_available_extra_jump_count(), room_index + 1]
	$HUD/Info/Rows/Stamina.value = player.get_wall_stamina()
	$HUD/Hint.text = HINTS[room_index]
	rooms.get_child(room_index).get_node("ExitLabel").text = "ゴール" if completed else ("相棒と進む →" if _carry_requirement_met() else "緑の相棒が必要")
	if room_index == 5 and not completed:
		var goal: ArrivalSwitch = $Rooms/Room6/Goal
		var should_lock := not _carry_requirement_met()
		if goal.locked != should_lock:
			goal.set_progress(1 if should_lock else 0, 1, "", "緑の相棒を運ぼう", false)


func _carry_requirement_met() -> bool:
	return player.get_held_object() == rooms.get_child(room_index).get_node("Items/JumpCreature")
