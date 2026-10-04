extends Node2D

const ROOM_SIZE := Vector2(1280, 720)
const TRANSITION_TIME := 0.28
const TITLES := ["天井の航路", "空中でダッシュ補充", "Springから着地", "向かい風と重力", "反転航路の総合課題"]
const HINTS := [
	"↑で天井へ。張り出しを越え、↓で床へ戻ろう。",
	"穴の手前でジャンプ。緑のCrystalを取って再ダッシュ。",
	"Springで跳び、空中ダッシュで高い足場へ。",
	"向かい風はダッシュで抜け、↑で障害物の上を通ろう。",
	"天井から↓で降り、Spring・緑のCrystal・ダッシュをつなごう。",
]

var room_index := 0
var transitioning := false
var completed := false
var cleared: Dictionary = {}

@onready var rooms: Node2D = $Rooms
@onready var player: PlayerController = $Player
@onready var camera: Camera2D = $Camera2D
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	player.get_node("Camera2D").enabled = false
	player.respawned.connect(_on_respawned)
	for room in rooms.get_children():
		var goal: ArrivalSwitch = room.get_node("Goal")
		goal.activated.connect(_on_arrival.bind(room.get_index()))
		goal.set_progress(0, 0, "", "")
	_set_room(0, false)
	player.respawn()
	camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("return_to_stage_select"):
		get_viewport().set_input_as_handled()
		_return_to_stage_select()


func _return_to_stage_select() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")


func _physics_process(_delta: float) -> void:
	if transitioning:
		return
	var left := room_index * ROOM_SIZE.x
	var collision: CollisionShape2D = player.get_node("CollisionShape2D")
	var right := collision.to_global(collision.shape.get_rect().end).x + player.safe_margin
	if right >= left + ROOM_SIZE.x and room_index < rooms.get_child_count() - 1 and cleared.has(room_index):
		_transition_to(room_index + 1)
	elif player.global_position.x < left and room_index > 0:
		_transition_to(room_index - 1)
	elif player.global_position.y < -52.0 or player.global_position.y > ROOM_SIZE.y + 52.0:
		player.respawn()


func _set_room(index: int, from_right: bool) -> void:
	room_index = index
	var room := rooms.get_child(index)
	var entrance: Marker2D = room.get_node("Return" if from_right else "Spawn")
	player.set_respawn_position(entrance.global_position)
	_update_room()


func _transition_to(index: int) -> void:
	transitioning = true
	player.controls_enabled = false
	_set_room(index, index < room_index)
	player.respawn()
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "position", _camera_position(), TRANSITION_TIME)
	await tween.finished
	player.controls_enabled = true
	transitioning = false


func _camera_position() -> Vector2:
	return Vector2(room_index * ROOM_SIZE.x, 0) + ROOM_SIZE * 0.5


func _on_respawned() -> void:
	for area in rooms.get_child(room_index).find_children("*", "Area2D", true, false):
		if area.has_method("reset_for_respawn"):
			area.reset_for_respawn()
	if not transitioning:
		camera.position = _camera_position()
		camera.reset_smoothing()


func _on_arrival(index: int) -> void:
	if transitioning or index != room_index or cleared.has(index):
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
	room.get_node("ExitHint").text = ("クリア！" if room_index == rooms.get_child_count() - 1 else "次の部屋へ →") if done else "到着台を踏もう →"
	room.get_node("ExitHint").modulate = Color(0.55, 1, 0.75) if done else Color(1, 0.8, 0.45)
	room.get_node("Goal").set_progress(0, 0, "", "", done)
	hud.show_stage_room(room_index, rooms.get_child_count(), TITLES[room_index], HINTS[room_index])
	$HUD/Completion.visible = completed
