extends Node2D

const ROOM_SIZE := Vector2(1280, 720)
const TRANSITION_TIME := 0.28
const TITLES := ["壁から壁へ", "天井を進む", "蹴って反転", "上下を往復", "動くゲートへ", "連携のまとめ"]
const HINTS := [
	"Springと反転をキックでつなぐ。",
	"天井の反発板から壁を掴む。",
	"空中ジャンプと下ダッシュでトゲの下へ。",
	"縦風を越え、移動ゲートを待つ。",
	"下ダッシュでSpringの下へ回り、床へ戻る。",
	"向かい風と横移動ゲートを越す。",
]

var room_index := 0
var transitioning := false
var completed := false
var hints_visible := false
var cleared: Dictionary = {}

@onready var rooms: Node2D = $Rooms
@onready var player: PlayerController = $Player
@onready var camera: Camera2D = $Camera2D
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	player.get_node("Camera2D").enabled = false
	player.use_default_respawn_bounds = false
	player.respawned.connect(_on_respawned)
	for room in rooms.get_children():
		for hint in room.get_children():
			if hint is Label:
				hint.add_theme_color_override("font_outline_color", ArtDraw.INK)
				hint.add_theme_constant_override("outline_size", 2)
		room.get_node("Goal").activated.connect(_on_arrival.bind(room.get_index()))
	_set_room(0, false)
	player.respawn()
	camera.make_current()
	set_hints_visible(false)


func set_hints_visible(value: bool) -> void:
	hints_visible = value
	for hint in get_tree().get_nodes_in_group("stage_3_hints"):
		hint.visible = value
	hud.show_stage_room(room_index, TITLES[room_index], HINTS[room_index] if value else "", rooms.get_child_count())
	$HUD/Completion.text = "ステージ3クリア！\n左へ戻って、自由に練習できます" if value else "ステージ3クリア！"


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
	elif player.global_position.y > ROOM_SIZE.y + 52.0 or player.global_position.y < float(rooms.get_child(room_index).get_meta("room_top", 0.0)) - 52.0:
		player.respawn()
	if not transitioning and rooms.get_child(room_index).has_meta("room_top"):
		camera.position = _camera_position()


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
	player.controls_enabled = true


func _camera_position() -> Vector2:
	var top := float(rooms.get_child(room_index).get_meta("room_top", 0.0))
	return Vector2(room_index * ROOM_SIZE.x + ROOM_SIZE.x * 0.5, clampf(player.position.y - 80.0, top + ROOM_SIZE.y * 0.5, ROOM_SIZE.y * 0.5))


func _on_respawned() -> void:
	for gate in rooms.get_child(room_index).find_children("*", "Area2D", true, false):
		if gate.has_method("reset_for_respawn"):
			gate.reset_for_respawn()
	_update_room()
	if not transitioning:
		camera.position = _camera_position()
		camera.reset_smoothing()


func _on_arrival(index: int) -> void:
	if index != room_index or transitioning or cleared.has(index):
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
	var bridge := room.get_node_or_null("ReturnBridge")
	if bridge != null:
		bridge.visible = done
		bridge.get_node("Collision").set_deferred("disabled", not done)
		room.get_node("PitWarning").visible = not done
	room.get_node("Goal").set_progress(0, 0, "", "", done)
	room.get_node("ExitHint").text = ("クリア！　自由に練習できます" if room_index == 5 else "次の部屋へ →") if done else "到着台に乗ると出口が開く"
	room.get_node("ExitHint").modulate = Color(0.55, 1, 0.75) if done else Color(1, 0.8, 0.45)
	$HUD/Completion.visible = completed and room_index == rooms.get_child_count() - 1
