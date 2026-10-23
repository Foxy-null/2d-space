extends Node2D

const TITLES := [
	"針穴の反射", "横風の狙撃", "風の境目", "三連反射", "逆風を裂く", "天井返し",
	"吹き落とす風", "折り返す航路", "壁からの一撃", "暴走する追い風", "嵐の五連鎖", "暴風の最終試練",
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
	"五つの反射をつなごう。風を受ける区間とダッシュで抜ける区間を見極めよう。",
	"六つの反射と風の総合試練。最後のダッシュを残し、旗のある小さな台へ！",
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


func _ready() -> void:
	player.get_node("Camera2D").enabled = false
	player.respawned.connect(_on_respawned)
	$Rooms/Room12/Goal.activated.connect(_on_completed)
	$Rooms/Room12/Goal.set_progress(0, 0, "", "", false)
	for index in rooms.get_child_count():
		var room := rooms.get_child(index)
		for bumper_index in room.get_node("Bumpers").get_child_count():
			room.get_node("Bumpers").get_child(bumper_index).launched.connect(_on_bumper.bind(index, bumper_index))
		for hazard in room.get_node("Hazards").get_children():
			hazard.body_entered.connect(_on_hazard)
	_set_checkpoint()
	player.respawn()
	camera.make_current()
	_update_hud()


func _physics_process(_delta: float) -> void:
	if transitioning:
		return
	var local_x := player.position.x - room_index * ROOM_WIDTH
	var exit_unlocked := not rooms.get_child(room_index).has_node("ExitLock") or next_bumper == _bumpers().get_child_count()
	if player.position.y < -52 or player.position.y > 772 or local_x < -24:
		player.respawn()
	elif room_index < rooms.get_child_count() - 1 and exit_unlocked and (_landed_on_exit() or local_x >= ROOM_WIDTH):
		_transition_to_next()
	elif local_x > ROOM_WIDTH + 24:
		player.respawn()
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
	if not completed:
		next_bumper = 0
	_update_route()
	if not transitioning:
		camera.position = Vector2(room_index * ROOM_WIDTH + 640, 360)
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
	var unlocked := next_bumper == _bumpers().get_child_count()
	var lock := room.get_node_or_null("ExitLock")
	if lock != null:
		lock.get_node("Collision").set_deferred("disabled", unlocked)
		lock.visible = not unlocked
	room.get_node("ExitLabel").text = "→" if lock == null or unlocked else "%d / %d" % [next_bumper, _bumpers().get_child_count()]
	target_marker.position = room.get_node("Exit").global_position + Vector2(0, -55) if unlocked else _bumpers().get_child(next_bumper).global_position
	target_marker.visible = not completed and (lock != null or hints_visible)
	for index in _bumpers().get_child_count():
		var bumper := _bumpers().get_child(index)
		bumper.modulate = Color(0.55, 0.7, 0.65) if index < next_bumper and (lock != null or hints_visible) else Color.WHITE
		bumper.get_node("Number").text = "✓" if index < next_bumper else str(index + 1)
		bumper.get_node("Number").visible = lock != null or hints_visible


func _on_hazard(body: Node2D) -> void:
	if body == player and not transitioning:
		player.respawn()


func set_hints_visible(value: bool) -> void:
	hints_visible = value
	$HUD/Hint.visible = value
	for room in rooms.get_children():
		room.get_node("Route").visible = value
	_update_route()


func _on_completed() -> void:
	if next_bumper != _bumpers().get_child_count():
		return
	completed = true
	target_marker.hide()
	$HUD/Completion.show()
	$Rooms/Room12/Goal.set_progress(0, 0, "", "", true)


func _update_hud() -> void:
	$HUD/Info/Rows/Title.text = "暴風バンパー峡谷　%02d / 12　%s" % [room_index + 1, TITLES[room_index]]
	var dash := "ダッシュ %s" % ("●" if player.is_dash_ready() else "○")
	$HUD/Info/Rows/Status.text = dash if room_index == 0 else "反射 %d / %d　　%s" % [next_bumper, _bumpers().get_child_count(), dash]
	$HUD/Info/Rows/Stamina.value = player.get_wall_stamina()
	$HUD/Hint.text = HINTS[room_index]
