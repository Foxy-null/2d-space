extends Node2D

const ROOM_SIZE := Vector2(1280, 720)
const TRANSITION_TIME := 0.28
const ENTRY_STEP := preload("res://scenes/room_entry_step.tscn")
const TITLES := ["壁から壁へ", "天井を進む", "蹴って反転", "上下を往復", "動くゲートへ", "連携のまとめ", "左へ渡り直す", "上層から二段跳び", "風の中で待つ", "バネから二段下降", "左向きのSpring連携", "反発から反転へ", "動くゲートへ下降", "左へ蹴り返す", "反転連鎖のまとめ", "天井の回復リレー", "深い下降をつなぐ", "逆風の左折り返し", "壁の上から角を回る", "左へ上昇して戻る", "上下の回復連鎖", "傘で風の上へ", "反転した上昇気流", "左へ上がって深く下る", "上下をつなぐ傘", "壁から天井へ抜ける", "左への天井回復", "風から壁の上へ", "逆風から左へ反発", "靴から二段上昇", "風から左へつなぐ", "反転して壁の下へ", "左への反発と移動Down", "反転した段差へ跳ぶ", "天井から横風の滑空へ", "壁から斜めの回復へ", "上下二段の折り返し"]
const HINTS := [
	"Springと反転をキックでつなぐ。",
	"天井の反発板から壁を掴む。",
	"空中ジャンプと下ダッシュでトゲの下へ。",
	"縦風を越え、移動ゲートを待つ。",
	"下ダッシュでSpringの下へ回り、床へ戻る。",
	"向かい風と横移動ゲートを越す。",
	"反転した壁の下を左へ渡り、到着台の先へ。",
	"上層の靴を二つつなぎ、下ダッシュで吊り壁の下へ。",
	"二度の上下往復から風を越え、壁で待って移動ゲートへ。",
	"バネで反転。靴二つから下Dashへ。",
	"左へSpringと靴をつなぎ、到着台の先へ進もう。",
	"反発板から床で休み、二つのSpringと壁キックで反転しよう。",
	"天井で動くDownを見て、Jumpから下Dashへ。",
	"左へ壁を渡り、深い下回りへ。下面には巻物の枝もある。",
	"動くゲートと向かい風を越え、浮いたSpringから床のDownへ。",
	"天井で休んだら、横Dashを空中で回復して渡ろう。",
	"反転した下面から下Dashをつなぎ、深いDownへ。",
	"左への風渡りは、回復の後も高い天井を目指そう。",
	"張り出しを蹴り替えて上がり、回復Dashで角の下を回ろう。",
	"上Dashを回復して左上へ。天井から左のDownへ進もう。",
	"上への回復から天井で休み、下への回復で最後の床へ。",
	"傘で風に乗り、高い床から天井へ。",
	"反転中は下向きの風が上昇気流。深い天井から左へ。",
	"左の天井で休み、下Dashを回復して深いDownへ。",
	"上昇と反転した上昇をつなぎ、下Dashの回復から床へ。",
	"張り出しを蹴り替え、反転した天井からDownへ。",
	"右の入口から反転し、空中でDashを回復して左の到着台へ。",
	"傘で風を上がり、壁を蹴り替えて上の天井へ。",
	"左へのDashから休み、天井のSpringで深いDownへ。",
	"靴の追加Jumpで回復へ届き、もう一度上Dashして天井へ。",
	"傘で上がったら左へ反転し、回復Dashで最後の天井へ。",
	"反転したら壁を蹴り替えて、深い床へ戻ろう。",
	"反発から左の天井へ。休んだら動くDownを目指そう。",
	"反転した追加Jumpで、左の深い天井へ。",
	"傘を持って反転し、横風から左の床へ滑ろう。",
	"斜めDashを回復して、張り出しの角を回ろう。",
	"上下の壁を渡り、右と左の折り返しをつなごう。",
]

var room_index := 0
var transitioning := false
var completed := false
var hints_visible := false
var cleared: Dictionary = {}
var parachute_camera_lead := -80.0
var returning := false

@onready var rooms: Node2D = $Rooms
@onready var player: PlayerController = $Player
@onready var camera: Camera2D = $Camera2D
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	player.get_node("Camera2D").enabled = false
	player.use_default_respawn_bounds = false
	player.respawned.connect(_on_respawned)
	for room in rooms.get_children():
		var step := ENTRY_STEP.instantiate()
		room.add_child(step)
		var width := float(room.get_meta("room_width", ROOM_SIZE.x))
		step.position = Vector2(16 if _exit_direction(room) > 0 else width - 16, room.get_node("Spawn").position.y - 10)
		var boundary := room.get_node_or_null("RightBoundary/Collision")
		if boundary != null and room.get_index() < rooms.get_child_count() - 1:
			boundary.disabled = true
			boundary.get_parent().hide()
		for hint in room.get_children():
			if hint is Label:
				hint.add_theme_color_override("font_outline_color", ArtDraw.INK)
				hint.add_theme_constant_override("outline_size", 2)
		for area in room.find_children("*", "Area2D", true, false):
			if area is ScrollCollectible:
				# Pending scrolls keep following through a room transfer.
				area.process_mode = Node.PROCESS_MODE_PAUSABLE
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
	$HUD/Completion.text = "ステージ3クリア！\n入口へ戻って、自由に練習できます" if value else "ステージ3クリア！"


func _physics_process(delta: float) -> void:
	if transitioning:
		return
	var room := rooms.get_child(room_index)
	var left: float = room.global_position.x
	var width := float(room.get_meta("room_width", ROOM_SIZE.x))
	var collision: CollisionShape2D = player.get_node("CollisionShape2D")
	var right := collision.to_global(collision.shape.get_rect().end).x + player.safe_margin
	var left_edge := collision.to_global(collision.shape.get_rect().position).x - player.safe_margin
	var exit_left := _exit_direction(room) < 0
	var exit_collision: CollisionShape2D = room.get_node("ExitBarrier/Collision")
	var exit_bounds := exit_collision.shape.get_rect()
	var exit_x := exit_collision.to_global(exit_bounds.position if exit_left else exit_bounds.end).x
	var reached_exit := left_edge <= exit_x if exit_left else right >= exit_x
	var left_entrance := player.global_position.x > left + width if exit_left else player.global_position.x < left
	if reached_exit and room_index < rooms.get_child_count() - 1 and cleared.has(room_index):
		_transition_to(room_index + 1)
	elif left_entrance and room_index > 0:
		_transition_to(room_index - 1)
	elif player.global_position.y > float(rooms.get_child(room_index).get_meta("room_bottom", ROOM_SIZE.y)) + 52.0 or player.global_position.y < float(rooms.get_child(room_index).get_meta("room_top", 0.0)) - 52.0:
		player.respawn()
	if room.get_meta("parachute_room", false):
		var look_down := player.gravity_direction < 0 and not player.is_dashing() and (player.is_on_floor() or player.velocity.y > 0)
		parachute_camera_lead = move_toward(parachute_camera_lead, 240.0 if look_down else -80.0, delta * 480.0)
	if not transitioning and (room.has_meta("room_top") or room.has_meta("room_bottom") or room.has_meta("room_width")):
		camera.position = _camera_position()


func _exit_direction(room: Node2D) -> int:
	return -1 if room.get_meta("exit_left", false) else 1


func _set_room(index: int, from_exit: bool) -> void:
	room_index = index
	returning = from_exit
	var room := rooms.get_child(index)
	for candidate in rooms.get_children():
		candidate.process_mode = Node.PROCESS_MODE_INHERIT if candidate == room else Node.PROCESS_MODE_DISABLED
	var entrance: Marker2D = room.get_node("Return" if from_exit else "Spawn")
	player.set_respawn_position(entrance.global_position)
	hud.show_stage_room(index, TITLES[index], HINTS[index] if hints_visible else "", rooms.get_child_count())
	_update_room()


func _transition_to(index: int) -> void:
	transitioning = true
	player.controls_enabled = false
	# Same-side entrances cannot be represented by a horizontal camera pan.
	var fade := create_tween()
	fade.tween_property($Transition/Curtain, "color:a", 1.0, TRANSITION_TIME * 0.5)
	await fade.finished
	_set_room(index, index < room_index)
	player.respawn(true)
	camera.position = _camera_position()
	camera.reset_smoothing()
	fade = create_tween()
	fade.tween_property($Transition/Curtain, "color:a", 0.0, TRANSITION_TIME * 0.5)
	await fade.finished
	transitioning = false
	player.controls_enabled = true


func _camera_position() -> Vector2:
	var top := float(rooms.get_child(room_index).get_meta("room_top", 0.0))
	var bottom := float(rooms.get_child(room_index).get_meta("room_bottom", ROOM_SIZE.y))
	var room := rooms.get_child(room_index)
	var left: float = room.global_position.x
	var width := float(room.get_meta("room_width", ROOM_SIZE.x))
	var margin := float(room.get_meta("camera_margin_x", 72.0 if room.get_meta("parachute_room", false) else 0.0))
	var vertical_lead := float(room.get_meta("camera_offset_y", parachute_camera_lead if room.get_meta("parachute_room", false) else -80.0))
	if player.gravity_direction == 1:
		vertical_lead = float(room.get_meta("camera_offset_y_normal", vertical_lead))
		if cleared.has(room_index):
			# The arrival is visible now; keep carried objects below the upper HUD on the exit walk.
			vertical_lead = minf(vertical_lead, 40.0)
	return Vector2(clampf(player.position.x + float(room.get_meta("camera_offset_x", 0.0)), left + ROOM_SIZE.x * 0.5 - margin, left + width - ROOM_SIZE.x * 0.5 + margin), clampf(player.position.y + vertical_lead, top + ROOM_SIZE.y * 0.5, bottom - ROOM_SIZE.y * 0.5))


func _on_respawned() -> void:
	parachute_camera_lead = -80.0
	player.facing_direction = _exit_direction(rooms.get_child(room_index)) * (-1 if returning else 1)
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
	for path in room.get_meta("return_bridges", PackedStringArray(["ReturnBridge"])):
		var bridge := room.get_node_or_null(NodePath(path))
		if bridge != null:
			bridge.visible = done
			bridge.get_node("Collision").set_deferred("disabled", not done)
	for path in room.get_meta("pit_warnings", PackedStringArray(["PitWarning"])):
		var warning := room.get_node_or_null(NodePath(path))
		if warning != null:
			warning.visible = not done
	for path in room.get_meta("return_retract", PackedStringArray()):
		var obstacle := room.get_node(NodePath(path))
		obstacle.visible = not done
		if obstacle is StaticBody2D:
			obstacle.get_node("Collision").set_deferred("disabled", done)
		elif obstacle is SpikeBlock:
			obstacle.set_physics_process(not done)
		elif obstacle is Area2D:
			obstacle.set_deferred("monitoring", not done)
	room.get_node("Goal").set_progress(0, 0, "", "", done)
	var exit_hint := room.get_node_or_null("ExitHint")
	if exit_hint != null:
		exit_hint.text = ("クリア！　自由に練習できます" if room_index == rooms.get_child_count() - 1 else ("← 次の部屋へ" if _exit_direction(room) < 0 else "次の部屋へ →")) if done else "到着台に乗ると出口が開く"
		exit_hint.modulate = Color(0.55, 1, 0.75) if done else Color(1, 0.8, 0.45)
	$HUD/Completion.visible = completed and room_index == rooms.get_child_count() - 1
