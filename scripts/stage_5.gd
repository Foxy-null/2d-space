extends Node2D

const TITLES := [
	"針穴の反射", "横風の狙撃", "風の境目", "三連反射", "逆風を裂く", "天井返し",
	"吹き落とす風", "折り返す航路", "壁からの一撃", "暴走する追い風", "嵐の五連鎖", "暴風の六連鎖",
	"折り返す空と巻物", "縦に抜ける峡谷", "嵐の帰り道",
	"左へ抜ける反射", "上層への五段", "深い谷の折り返し",
	"広い空の反射連鎖", "向かい風の左航路", "斜めに登る峡谷", "谷底からの帰還", "風を渡る左折り返し", "天空の大きな一周",
	"バネから反射の階段へ", "左へ跳ねるバネ航路", "傘から反射する空", "天井へ反転する反射", "左へ折り返す天井", "傘から天井の航路へ", "ブーツから反射の空へ", "天井から床の航路へ", "反射から高い岩壁へ",
]
const HINTS := [
	"足場を右へ降りてバンパーの上側へ。反射後は右へ進み、隙間の先のバンパーを狙おう。",
	"横風の流れ込みを読もう。反射後のダッシュは次のバンパーへの位置合わせに。",
	"追い風から向かい風へ。風の境目でダッシュすると姿勢を立て直せる。",
	"足場なしの三連反射。浅くかするだけでは跳ねないので、上側へしっかり当たろう。",
	"向かい風の中は前進が遅い。反射の横方向の勢いとダッシュを組み合わせよう。",
	"②は天井側。下から当てて跳ね返り、回復したダッシュで③へ向かおう。",
	"下向きの風は落下を速める。反射の直後から次のバンパーを狙おう。",
	"②から③は左へ折り返す。番号を見て、次の反射までに進行方向を変えよう。",
	"岩壁は掴める。壁キックで②の上へ回り、反射で③へのダッシュを回復。",
	"追い風では進みすぎに注意。逆入力で調整し、真上からの反射も使おう。",
	"五つの反射をつなごう。中央下の足場で休み、ジャンプと上ダッシュで次の反射へ戻れます。",
	"六つの反射と風の総合試練。最後のダッシュで右の足場へ着地しよう。",
	"右の反射から左へ折り返し、休憩台へ。巻物へ寄るなら、さらに左上を回ろう。",
	"下から反射をつないで登ろう。左への折り返しの後は、右上の切れ目へ向かおう。",
	"横風と下向きの風を抜け、左へ折り返してから最後の反射へ向かおう。",
	"右の入口から上へ戻り、左の出口へ反射をつなごう。",
	"下層から反射をつなぐ。中間の台で休んでから上へ戻れます。",
	"下向きの風に乗り、谷の奥から左上の足場へ折り返そう。",
	"高さの違う反射をつなぎ、右の足場へ。途中の台から同じ反射へ戻れます。",
	"右の入口から左へ。風の変わり目で次の反射を見よう。",
	"下層から斜めに登り、上層の足場へ渡ろう。",
	"谷の底へ降り、最後は反射をつないで右上へ。",
	"上下に流れる風を抜け、左へ反射をつなごう。",
	"上へ登って左へ折り返し、下降の反射から右の到着台へ。",
	"入口のバネで高い反射へ。三つ目の下の台で休んで再出発できます。",
	"右のバネから左上の反射へ。向かい風を越え、左の出口へ渡ろう。",
	"傘で風を上がり、右の反射へ滑空。反射の下の棚で休めます。",
	"上のゲートから天井側へ。反射の後は下のゲートから床へ戻ろう。",
	"右の入口から天井へ。反射を左へつなぎ、下のゲートから床へ。",
	"傘で風を上がり、上のゲートへ。天井のバネから反射をつなごう。",
	"ブーツで高い反射へ。途中の台で休み、上へ跳び直せます。",
	"天井から下のゲートへ。足場で休み、空中の回復から上の反射へ戻ろう。",
	"反射から壁をつかんで上へ。岩の上から次の反射へ跳ぼう。",
]
const ROOM_WIDTH := 1280.0
var room_index := 0
var transitioning := false
var hints_visible := false
var completed := false
var next_bumper := 0

@onready var player: PlayerController = $Player
@onready var camera: Camera2D = $Camera2D
@onready var rooms: Node2D = $Rooms
@onready var target_marker: Line2D = $TargetMarker
@onready var goal: ArrivalSwitch = rooms.get_child(rooms.get_child_count() - 1).get_node("Goal")


func _ready() -> void:
	player.get_node("Camera2D").enabled = false
	player.respawned.connect(_on_respawned)
	goal.activated.connect(_on_completed)
	goal.set_progress(0, 0, "", "", false)
	for index in rooms.get_child_count():
		var room := rooms.get_child(index)
		for bumper_index in room.get_node("Bumpers").get_child_count():
			room.get_node("Bumpers").get_child(bumper_index).launched.connect(_on_bumper.bind(index, bumper_index))
		for hazard in room.get_node("Hazards").get_children():
			hazard.body_entered.connect(_on_hazard)
	_set_checkpoint()
	player.respawn()
	camera.make_current()
	set_hints_visible(false)
	_update_hud()


func _physics_process(delta: float) -> void:
	if transitioning:
		return
	var room := rooms.get_child(room_index)
	var local_x: float = player.position.x - room.position.x
	var width := float(room.get_meta("room_width", ROOM_WIDTH))
	var height := float(room.get_meta("room_height", 720.0))
	var exit_left := bool(room.get_meta("exit_left", false))
	if player.position.y < -52 or player.position.y > height + 52:
		player.respawn()
	elif room_index < rooms.get_child_count() - 1 and (_landed_on_exit() or (local_x <= 0 if exit_left else local_x >= width)):
		_transition_to_next()
	elif local_x < -24 or local_x > width + 24:
		player.respawn()
	if width > ROOM_WIDTH or height > 720:
		camera.position = camera.position.lerp(_camera_position(), 1.0 - exp(-8.0 * delta))
	_update_hud()


func _landed_on_exit() -> bool:
	if not player.is_on_floor():
		return false
	var exit := rooms.get_child(room_index).get_node("Exit")
	for index in player.get_slide_collision_count():
		var contact := player.get_slide_collision(index)
		if contact.get_collider() == exit and contact.get_normal().dot(Vector2.UP) > 0.8:
			return true
	return false


func _set_checkpoint() -> void:
	var entrance: Marker2D = rooms.get_child(room_index).get_node("Spawn")
	player.set_respawn_position(entrance.global_position)


func _camera_position() -> Vector2:
	var room := rooms.get_child(room_index)
	var height := float(room.get_meta("room_height", 720.0))
	var offset_y := float(room.get_meta("camera_offset_y", -80.0))
	var width := float(room.get_meta("room_width", ROOM_WIDTH))
	if width > ROOM_WIDTH and not transitioning and not player.is_on_floor():
		var target: Node2D = _bumpers().get_child(next_bumper) if next_bumper < _bumpers().get_child_count() else room.get_node("Exit")
		offset_y = clampf(target.global_position.y - player.global_position.y, -80, 80)
	if room_index in [24,25,26,30] and next_bumper == 0 and (player.is_on_floor() or player.position.distance_to(room.get_node("Spawn").global_position) < 8):
		offset_y = -160.0
	if room_index >= 27 and player.is_on_floor():
		var target: Node2D = _bumpers().get_child(next_bumper) if next_bumper < _bumpers().get_child_count() else room.get_node("Exit")
		offset_y = clampf(target.global_position.y-player.global_position.y,-240,150)
	var lead_x := 0.0
	if room_index in [24,30] and player.is_on_floor() and player.position.y < 600:
		offset_y = 240.0
		lead_x = 160.0
	if room_index == 27 and player.is_on_floor() and player.position.y > 1300 and player.position.x-room.position.x < 1100:
		offset_y = -270.0
		lead_x = 360.0
	if room_index == 29 and player.gravity_direction == -1 and player.is_on_floor() and player.position.y > 900 and player.position.x-room.position.x < 150:
		offset_y = -200.0
	if completed:
		offset_y = -80.0
	# 入口の反転直後に残る接地判定を、天井の休憩と扱わない。
	if room_index == 31 and player.is_on_floor() and player.gravity_direction == -1 and player.position.y > 900 and player.position.y < 1100:
		offset_y = 220.0
	if room_index == 31 and player.is_on_floor() and player.position.y > 1450:
		offset_y = -300.0
	var margin := 72.0 if room_index >= 24 else 0.0
	return Vector2(clampf(player.position.x + lead_x, room.position.x + 640 - margin, room.position.x + width - 640 + margin), clampf(player.position.y + offset_y, 360, height - 360))


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
	if not completed:
		next_bumper = 0
	_update_route()
	if not transitioning:
		camera.position = _camera_position()
		camera.reset_smoothing()


func _bumpers() -> Node2D:
	return rooms.get_child(room_index).get_node("Bumpers")


func _on_bumper(_body: PlayerController, index: int, bumper_index: int) -> void:
	if index != room_index or transitioning or completed:
		return
	if bumper_index == next_bumper:
		next_bumper += 1
		_update_route()


func _update_route() -> void:
	var room := rooms.get_child(room_index)
	var route_complete := next_bumper == _bumpers().get_child_count()
	target_marker.position = room.get_node("Exit").global_position + Vector2(0, -55) if route_complete else _bumpers().get_child(next_bumper).global_position
	target_marker.visible = not completed and hints_visible
	for index in _bumpers().get_child_count():
		var bumper := _bumpers().get_child(index)
		bumper.modulate = Color(0.55, 0.7, 0.65) if index < next_bumper and hints_visible else Color.WHITE
		bumper.get_node("Number").text = "✓" if index < next_bumper else str(index + 1)
		bumper.get_node("Number").visible = hints_visible


func _on_hazard(body: Node2D) -> void:
	if body == player and not transitioning:
		player.respawn()


func set_hints_visible(value: bool) -> void:
	hints_visible = value
	$HUD/Hint.visible = value
	for room in rooms.get_children():
		room.get_node("Route").visible = value
		room.get_node("ExitLabel").visible = value
	_update_route()


func _on_completed() -> void:
	completed = true
	target_marker.hide()
	$HUD/Completion.show()
	goal.set_progress(0, 0, "", "", true)


func _update_hud() -> void:
	$HUD/Info.position = Vector2(24, 620 if room_index in [16, 20, 21, 24, 26] else 16)
	if room_index == 30:
		var upper_branch: bool = next_bumper==3 and player.position.y<1000 and player.position.x-rooms.get_child(30).position.x<1350
		$HUD/Info.position.y = 620 if player.position.y-camera.position.y+360 < 180 or upper_branch else 16
	$HUD/Info.size.x = 500 if room_index == 23 else (560 if room_index in [20, 21] else 676)
	$HUD/Info/Rows/Title.text = "暴風バンパー峡谷　%02d / %02d　%s" % [room_index + 1, rooms.get_child_count(), TITLES[room_index]]
	$HUD/Info/Rows/Status.text = "ダッシュ %s" % ("●" if player.is_dash_ready() else "○")
	$HUD/Info/Rows/Stamina.value = player.get_wall_stamina()
	var high_body := player.position.y-camera.position.y+360 < (200 if room_index >= 27 else 220)
	$HUD/Hint.position.y = 16 if room_index == 26 else (570 if (room_index == 24 or room_index >= 27) and high_body else 110)
	if room_index == 31 and player.is_on_floor() and player.gravity_direction == -1 and player.position.y > 900 and player.position.y < 1100:
		$HUD/Info.position.y = 8
		$HUD/Hint.position.y = 650
	if room_index == 32 and next_bumper == 0:
		$HUD/Info.position = Vector2(560, 200)
		$HUD/Hint.position.y = 650
	if room_index == 29 and player.is_on_floor() and player.gravity_direction == 1 and player.position.y > 1600 and player.position.x < rooms.get_child(29).position.x + 300:
		$HUD/Hint.position.y = 200
	$HUD/Hint.text = HINTS[room_index]
