extends Node2D

const ROOM_SIZE := Vector2(1280, 720)
const TRANSITION_TIME := 0.28
const TITLES := ["壁から壁へ", "天井を進む", "蹴って反転", "上下を往復", "動くゲートへ", "連携のまとめ"]
const HINTS := [
	"Springと反転をキックでつなぐ。",
	"天井の反発板から壁を掴む。",
	"空中ジャンプで後半の穴を越す。",
	"縦風を越え、移動ゲートを待つ。",
	"短い足場のSpringで床へ戻る。",
	"向かい風と横移動ゲートを越す。",
]

var room_index := 0
var transitioning := false
var completed := false
var hints_visible := false
var help_menu_visible := false
var cleared: Dictionary = {}

@onready var rooms: Node2D = $Rooms
@onready var player: PlayerController = $Player
@onready var camera: Camera2D = $Camera2D
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	player.get_node("Camera2D").enabled = false
	player.respawned.connect(_on_respawned)
	for room in rooms.get_children():
		room.get_node("Goal").activated.connect(_on_arrival.bind(room.get_index()))
	_set_room(0, false)
	player.respawn()
	camera.make_current()
	set_hints_visible(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_stage_hints") and not event.is_echo():
		get_viewport().set_input_as_handled()
		set_help_menu_visible(not help_menu_visible)
	elif event.is_action_pressed("return_to_stage_select") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if help_menu_visible:
			set_help_menu_visible(false)
		else:
			_return_to_stage_select()


func set_help_menu_visible(value: bool) -> void:
	help_menu_visible = value
	$HUD/HelpMenu.visible = value
	$HUD/HelpButton.set_pressed_no_signal(value)
	player.controls_enabled = not value and not transitioning
	if value:
		$HUD/HelpMenu/Rows/ToggleHints.grab_focus()
	else:
		get_viewport().gui_release_focus()


func set_hints_visible(value: bool) -> void:
	hints_visible = value
	for hint in get_tree().get_nodes_in_group("stage_2_hints"):
		hint.visible = value
	$HUD/HelpMenu/Rows/ToggleHints.set_pressed_no_signal(value)
	$HUD/HelpMenu/Rows/ToggleHints.text = "ヒントを非表示にする" if value else "ヒントを表示する"
	hud.show_stage_room(room_index, TITLES[room_index], HINTS[room_index] if value else "", rooms.get_child_count())
	$HUD/Completion.text = "ステージ2クリア！\n左へ戻って、自由に練習できます" if value else "ステージ2クリア！"


func _return_to_stage_select() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")


func _physics_process(_delta: float) -> void:
	if transitioning or help_menu_visible:
		return
	var left := room_index * ROOM_SIZE.x
	var collision: CollisionShape2D = player.get_node("CollisionShape2D")
	var right := collision.to_global(collision.shape.get_rect().end).x + player.safe_margin
	if right >= left + ROOM_SIZE.x and room_index < rooms.get_child_count() - 1 and cleared.has(room_index):
		_transition_to(room_index + 1)
	elif player.global_position.x < left and room_index > 0:
		_transition_to(room_index - 1)
	elif player.global_position.y > ROOM_SIZE.y + 52.0 or player.global_position.y < -52.0:
		player.respawn()


func _set_room(index: int, from_right: bool) -> void:
	room_index = index
	var room := rooms.get_child(index)
	var entrance: Marker2D = room.get_node("Return" if from_right else "Spawn")
	player.set_respawn_position(entrance.global_position)
	hud.show_stage_room(index, TITLES[index], HINTS[index] if hints_visible else "", rooms.get_child_count())
	_update_room()


func _transition_to(index: int) -> void:
	transitioning = true
	player.controls_enabled = false
	_set_room(index, index < room_index)
	player.respawn()
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "position", _camera_position(), TRANSITION_TIME)
	await tween.finished
	transitioning = false
	player.controls_enabled = not help_menu_visible


func _camera_position() -> Vector2:
	return Vector2(room_index * ROOM_SIZE.x, 0) + ROOM_SIZE * 0.5


func _on_respawned() -> void:
	for gate in rooms.get_child(room_index).find_children("*", "Area2D", true, false):
		if gate.has_method("reset_for_respawn"):
			gate.reset_for_respawn()
	_update_room()
	if not transitioning:
		camera.position = _camera_position()
		camera.reset_smoothing()


func _on_arrival(index: int) -> void:
	if index != room_index or transitioning or not player.controls_enabled or cleared.has(index):
		return
	cleared[index] = true
	if index == rooms.get_child_count() - 1:
		completed = true
	_update_room()


func _update_room() -> void:
	var room := rooms.get_child(room_index)
	var done := cleared.has(room_index)
	room.get_node("ExitBarrier/Collision").set_deferred("disabled", done)
	room.get_node("ExitBarrier/Visual").visible = not done
	for curtain in room.find_children("*UpCurtain", "Area2D", false, false):
		curtain.set_deferred("monitoring", not done)
		curtain.visible = not done
	var bridge := room.get_node_or_null("ReturnBridge")
	if bridge != null:
		bridge.visible = done
		bridge.get_node("Collision").set_deferred("disabled", not done)
		room.get_node("PitWarning").visible = not done
	room.get_node("Goal").set_progress(0, 0, "", "", done)
	room.get_node("ExitHint").text = ("クリア！　自由に練習できます" if room_index == 5 else "次の部屋へ →") if done else "到着台に乗ると出口が開く"
	room.get_node("ExitHint").modulate = Color(0.55, 1, 0.75) if done else Color(1, 0.8, 0.45)
	$HUD/Completion.visible = completed and room_index == rooms.get_child_count() - 1
