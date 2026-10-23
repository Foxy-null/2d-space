extends Node2D

const TITLES := ["相棒と高い足場へ", "壁キックの峡谷", "低い天井の回廊", "峠を越えて下る", "離れ小島の大跳躍", "折り返しの頂"]
const HINTS := [
	"相棒の追加ジャンプと上向きダッシュで高い足場へ。広い足場で次の着地点を見よう。",
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
	$Rooms/Room6/Goal.reset_for_respawn()
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
	$HUD/Info.position.y = 620.0 if room_index == 0 else 40.0
	$HUD/Info/Rows/Title.text = "星渡りの回廊　%02d / 06　%s" % [room_index + 1, TITLES[room_index]]
	$HUD/Info/Rows/Status.text = "ダッシュ %s　　追加ジャンプ %d" % ["●" if player.is_dash_ready() else "○", player.get_available_extra_jump_count()]
	$HUD/Info/Rows/Stamina.value = player.get_wall_stamina()
	$HUD/Hint.text = HINTS[room_index]
	var room := rooms.get_child(room_index)
	var carrying := _carry_requirement_met()
	room.get_node("ExitLabel").text = "✓" if completed else ("✓ →" if carrying else "○ →")
	room.get_node("DeliveryIcon").modulate = Color.WHITE if carrying or completed else Color(1, 1, 1, 0.45)
	var creature: Grabbable = room.get_node("Items/JumpCreature")
	var prompt: Label = room.get_node("CarryHint")
	prompt.visible = not completed and not carrying and player.global_position.distance_to(creature.global_position) < 140.0
	prompt.position = creature.position + Vector2(-65, -85)
	if room_index == 5 and not completed:
		var goal: ArrivalSwitch = $Rooms/Room6/Goal
		var should_lock := not _carry_requirement_met()
		if goal.locked != should_lock:
			goal.set_progress(1 if should_lock else 0, 1, "", "緑の相棒を運ぼう", false)


func _carry_requirement_met() -> bool:
	return player.get_held_object() == rooms.get_child(room_index).get_node("Items/JumpCreature")
