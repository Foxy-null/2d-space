extends Node2D

const TITLES := [
	"相棒と高い足場へ", "壁キックの峡谷", "低い天井の回廊", "峠を越えて下る", "離れ小島の大跳躍",
	"折り返しの頂", "二段の高台", "壁キックと折り返し", "折り返しの風橋", "相棒と空中の靴",
	"反転して運ぶ", "バネから相棒へ", "風と空中の継ぎ足し", "壁の先で持ち直す", "運搬の長い折り返し",
	"空中でダッシュを継ぐ", "反転中の二つの天井", "風から壁の頂へ",
	"バネと靴", "靴からバネへ", "反射から靴へ", "天井からバネへ", "風から壁へ", "運ぶ相手を選ぶ",
	"回復から靴へ", "左へ反転して運ぶ", "壁から風へ", "反射から天井へ", "左へ靴と反射", "回復からバネへ",
	"投げ渡して壁の上へ", "左へ風を渡って下る", "反射から空中回復へ", "天井を継いで運ぶ", "壁の頂から左の風へ", "相棒と最後の反射へ",
]
const HINTS := [
	"相棒の追加ジャンプと上向きダッシュで高い足場へ。広い足場で次の着地点を見よう。",
	"相棒を持つと壁登りはできない。左右の壁を交互に蹴って峡谷を登ろう。",
	"低い屋根の下を渡る。頭をぶつけると高さを失うので、追加ジャンプは慌てずに。",
	"最初は登り、峠からは下り。飛びすぎないよう空中で向きを調整しよう。",
	"相棒の追加ジャンプと上ダッシュで高い横風へ。風を抜けたら島で休もう。",
	"中央の足場から左上へ折り返す。その後は右の低い足場へ大きく渡ろう。",
	"広い足場で相棒とダッシュを回復。左上の棚にも寄り道できる。",
	"相棒と壁を交互に蹴って登り、左上の足場で休んでから右へ渡ろう。",
	"高い横風から右の島へ。左上の足場へ折り返してから出口へ進もう。",
	"空中の靴と相棒をつなぎ、高い台から左右へ折り返そう。",
	"相棒と反転ゲートへ。天井で休んだら左の下降ゲートから戻ろう。",
	"バネの勢いに相棒のジャンプをつなぎ、上の台へ。",
	"高い風から右の島へ。空中の靴を使い左上へ折り返そう。",
	"対向壁を交互に蹴り、頂から左へ寄って谷を下ろう。",
	"台ごとに相棒とダッシュを回復し、左右へ折り返して最後の風へ。",
	"相棒と空中の回復をつなぎ、再ダッシュで高台へ。左上から右へ渡ろう。",
	"反転した二つの天井を相棒と渡り、Downから床側へ戻ろう。",
	"風で島へ渡り、壁の下から対向壁へ。相棒を持って頂へ登ろう。",
	"バネの初速から相棒へ。靴で左上へ折り返そう。",
	"相棒と靴で上がり、バネから左上へ戻ろう。",
	"丸い反射から休憩台へ。相棒と靴で左上へ。",
	"天井からDownへ。バネから床側を運ぼう。",
	"高い風と保持壁キックをつなぎ、壁の頂へ。",
	"緑は靴の左上へ、赤はバネと右の風へ。どちらかを運ぼう。",
	"空中の回復から再ダッシュ。棚で休み靴で左上へ。",
	"右のバネから左へ。Upで天井へ運び、Downから床へ戻ろう。",
	"対向壁を保持したまま蹴り、頂から高い風へ。",
	"反射からUpへ。天井で休み、Downから床の左枝へ。",
	"靴で左上へ。棚の左へ降りて丸い反射に乗ろう。",
	"左上の回復から棚へ。バネと相棒をつなぎ、到着台へ運ぼう。",
	"相棒を上へ渡し、手ぶらで壁へ。同じ相棒を拾い、バネから右の棚へ。",
	"靴と相棒で左上へ。高い風から遠い低い島へ下ろう。",
	"反射で棚へ。相棒と空中回復をつなぎ、右上へ運ぼう。",
	"Upで天井へ。回復ダッシュから次の天井、Downから床へ戻ろう。",
	"バネから対向壁へ。相棒を持って頂へ登り、左の風へ。",
	"靴と相棒で上の棚へ。バネと反射をつなぎ、到着台へ運ぼう。",
]
var room_index := 0
var transitioning := false
var hints_visible := false
var completed := false

@onready var player: PlayerController = $Player
@onready var camera: Camera2D = $Camera2D
@onready var rooms: Node2D = $Rooms
@onready var goal: ArrivalSwitch = rooms.get_child(rooms.get_child_count() - 1).get_node("Goal")


func _ready() -> void:
	add_to_group("stage_four")
	player.get_node("Camera2D").enabled = false
	player.respawned.connect(_on_respawned)
	goal.activated.connect(_on_completed)
	goal.set_progress(1, 1, "", "緑の相棒を運ぼう", false)
	_set_checkpoint()
	player.respawn()
	camera.make_current()
	_update_hud()


func _physics_process(delta: float) -> void:
	if transitioning:
		return
	var room := rooms.get_child(room_index)
	var local_x: float = player.position.x - room.position.x
	if player.position.y < -52 or player.position.y > rooms.get_child(room_index).room_height + 52 or local_x < -24 or (room.travel_direction == -1 and local_x > room.room_width + 24):
		player.respawn()
	elif (local_x >= room.room_width - 20 if room.travel_direction == 1 else local_x <= 20) and room_index < rooms.get_child_count() - 1 and player.is_on_floor() and _carry_requirement_met():
		_transition_to_next()
	camera.position = camera.position.lerp(_camera_position(), 1.0 - exp(-8.0 * delta))
	_update_hud()


func _set_checkpoint() -> void:
	var room := rooms.get_child(room_index)
	player.set_respawn_position(Vector2(room.position.x + room.entrance_x, room.entrance_top - 26))


func _camera_position() -> Vector2:
	var room := rooms.get_child(room_index)
	var bottom: float = room.room_height - 360.0
	var offset_y: float = 120.0 if room_index == 16 and player.gravity_direction == -1 else room.camera_offset_y
	if room_index == 15 and player.position.y < 1300.0: offset_y = -80.0
	if room_index >= 18:
		offset_y = -80.0 if player.position.y < 1000.0 else -300.0
		if room_index == 20 and player.position.y > 1800.0: offset_y = -200.0
		if room_index == 21 and (player.gravity_direction == -1 or player.position.y > 1400.0): offset_y = -80.0
		if room_index == 26 and player.position.y < 1000 and player.position.x-room.position.x < 550: offset_y = -160.0
		if room_index == 28 and player.position.y > 1000 and player.position.y < 1700: offset_y = -140.0
		if room_index == 27 and player.position.y > 1700:
			offset_y = -160.0
			bottom += 80.0
		if not player.is_on_floor(): offset_y = clampf(offset_y + maxf(0.0, player.velocity.y) * 0.25, -300.0, -80.0)
	if room_index == 30 and player.position.x-room.position.x < 700 and player.position.y < 1400: offset_y = 60.0
	if room_index == 32 and player.position.x-room.position.x < 900 and player.position.y < 1400: offset_y = 80.0
	if room_index == 32 and player.position.y > 1600: offset_y = -120.0
	if room_index == 31 and player.position.y < 1600: offset_y = 0.0
	if room_index == 33 and player.gravity_direction == -1: offset_y = 180.0 if player.is_on_floor() or player.velocity.y >= 0 else -80.0
	if room_index == 35 and player.position.y > 1000: offset_y = -310.0 if player.is_on_floor() else -270.0
	var lead_x := 300.0 if room_index == 26 and player.position.y < 800 and player.position.x-room.position.x > 270 else 0.0
	if room_index in [25, 28] and player.gravity_direction == 1 and player.position.y < 1000: lead_x = -160.0
	if room_index == 27 and player.gravity_direction == 1 and player.position.y < 1000: lead_x = 160.0
	if room_index in [31, 34] and player.position.y < (1600 if room_index == 31 else 1000): lead_x = -300.0
	if room_index == 35 and player.position.y > 1000 and player.position.x-room.position.x > 500: lead_x = 300.0
	var right_margin := 580 if room_index == 23 and player.position.y < room.exit_top + 30 else (600 if room_index >= 18 and room.travel_direction == 1 else 640)
	var camera_x := clampf(player.position.x + lead_x, room.position.x + (600 if room.travel_direction == -1 else 640), room.position.x + room.room_width - right_margin)
	if room_index == 26 and player.position.y < 800 and player.position.x-room.position.x > 270: camera_x = maxf(camera_x, room.position.x + 800)
	if room_index == 35 and player.position.y > 1000 and player.position.x-room.position.x > 600: camera_x = maxf(camera_x,room.position.x+960)
	return Vector2(camera_x, clampf(player.position.y + offset_y, 360.0, bottom))


func _transition_to_next() -> void:
	transitioning = true
	player.controls_enabled = false
	room_index += 1
	_set_checkpoint()
	player.respawn(true)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "position", _camera_position(), 0.28)
	await tween.finished
	transitioning = false
	player.controls_enabled = true
	_update_hud()


func _on_respawned() -> void:
	goal.reset_for_respawn()
	for item in rooms.get_child(room_index).get_node("Items").get_children():
		item.reset_for_respawn()
	for room in rooms.get_children():
		for spike in room.get_node("Hazards").get_children():
			spike.reset_for_respawn()
	if not transitioning:
		camera.position = _camera_position()
		camera.reset_smoothing()
		_update_hud()


func set_hints_visible(value: bool) -> void:
	hints_visible = value
	$HUD/Hint.visible = value


func _on_completed() -> void:
	if not _carry_requirement_met():
		return
	completed = true
	$HUD/Completion.card.position = Vector2(24, 180)
	$HUD/Completion.show()
	goal.set_progress(0, 0, "", "", true)


func _update_hud() -> void:
	var room := rooms.get_child(room_index)
	$HUD/Info.position = Vector2(580, 620) if room_index in [1, 4, 8, 12, 17] else Vector2(24, 620 if room_index == 0 else (100 if room_index == 11 else 40))
	if room_index == 15: $HUD/Info.position = Vector2(24, 80)
	if room_index == 16: $HUD/Info.position = Vector2(180, 620)
	$HUD/Info.size.x = 436.0 if room_index >= 18 else 676.0
	if room_index >= 18:
		$HUD/Info.position = Vector2(760, 620)
	if room_index == 19 and player.position.y > 1000 and player.position.y < room.walls[0].position.y:
		$HUD/Info.position = Vector2(24, 620)
	if room_index == 23 and player.position.y < room.walls[0].position.y:
		$HUD/Info.position = Vector2(24, 190)
	if room_index >= 24:
		$HUD/Info.position = Vector2(24 if room.travel_direction == -1 else 760, 620)
	if room_index == 28 and player.position.y < 1700:
		$HUD/Info.position = Vector2(760, 620)
	if room_index == 27 and player.gravity_direction == 1 and player.position.x-room.position.x < 650 and player.position.y < 650:
		$HUD/Info.position = Vector2(760, 110)
	if room_index == 29:
		$HUD/Info.position = Vector2(24, 64)
	if room_index == 30: $HUD/Info.position = Vector2(760, 620) if player.position.x-room.position.x < 700 and player.position.y < 1400 else Vector2(24,80)
	if room_index in [31, 34] and player.position.y < (1600 if room_index == 31 else 1000): $HUD/Info.position = Vector2(760, 620)
	if room_index == 34 and player.position.y < 500 and player.position.x-room.position.x > 1660: $HUD/Info.position = Vector2(24,620)
	if room_index == 33: $HUD/Info.position = Vector2(760 if player.position.x-room.position.x < 450 and player.position.y > 1100 else 24, 620)
	if room_index == 35 and player.position.y < 1000: $HUD/Info.position = Vector2(24, 64)
	if room_index == 22:
		$HUD/Info.position = Vector2(24, 40)
	$HUD/Info/Rows/Title.text = "星渡りの回廊　%02d / %02d　%s" % [room_index + 1, rooms.get_child_count(), TITLES[room_index]]
	$HUD/Info/Rows/Status.text = "ダッシュ %s　　追加ジャンプ %d" % ["●" if player.is_dash_ready() else "○", player.get_available_extra_jump_count()]
	$HUD/Info/Rows/Stamina.value = player.get_wall_stamina()
	$HUD/Hint.position.y = 16 if room_index >= 24 else 155
	if room_index >= 30: $HUD/Hint.position.y = 12
	if room_index in [30,34]: $HUD/Hint.position.y = 560 if player.position.y < 520 else 12
	if room_index == 35: $HUD/Hint.position.y = 560 if player.position.y < 1000 else 110
	$HUD/PauseButton.position.y = 620 if room_index == 35 and player.position.y < 1000 else 44
	$HUD/Hint.text = HINTS[room_index]
	var carrying := _carry_requirement_met()
	room.get_node("ExitLabel").text = "✓" if completed else (("✓ →" if carrying else "○ →") if room.travel_direction == 1 else ("← ✓" if carrying else "← ○"))
	room.get_node("DeliveryIcon").modulate = Color.WHITE if carrying or completed else Color(1, 1, 1, 0.45)
	var creature: Grabbable = room.get_node("Items/JumpCreature")
	if room_index == 23:
		var red: Grabbable = room.get_node("Items/ParachuteCreature")
		if player.global_position.distance_to(red.global_position) < player.global_position.distance_to(creature.global_position): creature = red
		var target: Grabbable = player.get_held_object() if carrying else room.get_node("Items/JumpCreature")
		var icon: Sprite2D = room.get_node("DeliveryIcon")
		icon.texture = target.get_node("Visuals/Body").sprite_frames.get_frame_texture("default", 0)
		icon.scale = Vector2.ONE * (42.0 / icon.texture.get_width())
	var prompt: Label = room.get_node("CarryHint")
	prompt.visible = not completed and not carrying and player.global_position.distance_to(creature.global_position) < 140.0
	prompt.position = creature.position + Vector2(-65, -85)
	if room_index == rooms.get_child_count() - 1 and not completed:
		var should_lock := not _carry_requirement_met()
		if goal.locked != should_lock:
			goal.set_progress(1 if should_lock else 0, 1, "", "緑の相棒を運ぼう", false)


func _carry_requirement_met() -> bool:
	var room := rooms.get_child(room_index)
	var held := player.get_held_object()
	return held == room.get_node("Items/JumpCreature") or (room_index == 23 and held == room.get_node("Items/ParachuteCreature"))
