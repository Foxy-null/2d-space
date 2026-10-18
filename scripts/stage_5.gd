extends Node2D

const TITLES := [
	"針穴の反射", "横風の狙撃", "風の境目", "三連反射", "逆風を裂く", "天井返し",
	"吹き落とす風", "折り返す航路", "壁からの一撃", "暴走する追い風", "嵐の五連鎖", "暴風の最終試練",
]
const HINTS := [
	"①の上側へ飛び込み、反射後に右へ。細い隙間を越えて②を狙おう。",
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
var help_visible := false
var hints_visible := false
var completed := false
var next_bumper := 0

@onready var player: PlayerController = $Player
@onready var camera: Camera2D = $Camera2D
@onready var rooms: Node2D = $Rooms


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
	elif room_index < rooms.get_child_count() - 1 and next_bumper == _bumpers().get_child_count() and (_landed_on_exit() or local_x >= ROOM_WIDTH):
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
	player.controls_enabled = not help_visible
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
	if index != room_index or transitioning or help_visible or completed:
		return
	if bumper_index == next_bumper:
		next_bumper += 1
		_update_route()


func _update_route() -> void:
	var room := rooms.get_child(room_index)
	var unlocked := next_bumper == _bumpers().get_child_count()
	room.get_node("ExitLock/Collision").set_deferred("disabled", unlocked)
	room.get_node("ExitLock").visible = not unlocked
	room.get_node("ExitLabel").text = ("旗の台へ →" if room_index == TITLES.size() - 1 else "着地して次の部屋へ →") if unlocked else "番号順に反射して解錠"
	for index in _bumpers().get_child_count():
		_bumpers().get_child(index).modulate = Color(0.55, 0.7, 0.65) if index < next_bumper else Color.WHITE


func _on_hazard(body: Node2D) -> void:
	if body == player and not transitioning:
		player.respawn()


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
	for room in rooms.get_children():
		room.get_node("Route").visible = value


func _retry() -> void:
	set_help_visible(false)
	player.respawn()


func _return_to_select() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")


func _on_completed() -> void:
	if next_bumper != _bumpers().get_child_count():
		return
	completed = true
	$HUD/Completion.show()
	$Rooms/Room12/Goal.set_progress(0, 0, "", "", true)


func _update_hud() -> void:
	$HUD/Info/Rows/Title.text = "ステージ5　暴風バンパー峡谷　｜　%02d / 12　%s" % [room_index + 1, TITLES[room_index]]
	$HUD/Info/Rows/Status.text = "反射：%d / %d　　ダッシュ：%s　　復帰地点：部屋%d" % [next_bumper, _bumpers().get_child_count(), "使用可" if player.is_dash_ready() else "回復待ち", room_index + 1]
	$HUD/Info/Rows/Stamina.value = player.get_wall_stamina()
	$HUD/Hint.text = HINTS[room_index]
