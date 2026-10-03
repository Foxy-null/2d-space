extends Node2D

const ROOM_SIZE := Vector2(1280, 720)
const TRANSITION_TIME := 0.28
const MAIN_ROOM_COUNT := 16
const TITLES := ["移動・ジャンプ", "よじ登り・壁キック", "ダッシュ", "重力切り替え",
	"ダッシュの補充", "追加ジャンプ", "Spring", "PinballSpring", "風", "動く重力ゲート",
	"掴む・運ぶ・置く", "投げる", "Jump Creature", "Parachute Creature",
	"追加ジャンプの連携", "滑空・風・重力の連携", "Superdash（任意）"]
const CONTROLS := [
	"移動：A / D・← / →　ジャンプ：Space / W・A / ×",
	"掴む：Shift・ZL / ZR　登る：↑ / ↓　壁キック：Space・A / ×",
	"ダッシュ：X・B / ○ ＋ 方向入力　空中では1回、着地で回復",
	"↑ ゲート：天井へ　↓ ゲート：床へ　左右の操作は同じ",
	"緑のひし形でダッシュ回復　空中で回復してもう一度ダッシュ",
	"紫の八角形で追加ジャンプ1回　ジャンプ：Space・A / ×",
	"矢印に触れると発射　ダッシュと壁スタミナも回復",
	"丸いバンパーは当たる位置で反射方向が変わる",
	"風は歩行・空中に作用　ダッシュ中・壁を掴んでいる間は無効",
	"ゲートの往復を見てから通過　↑ で天井、↓ で床へ",
	"Shift・ZL / ZRを保持して掴む　止まって離すと置く",
	"動きながらGrabキーを離すと、自分の移動方向へ投げる",
	"緑の生物を保持して追加ジャンプ　保持したまま着地で回復",
	"黄色の傘を保持してゆっくり落下　離すと通常の落下へ",
	"紫のCrystal ＋ 緑の生物で追加ジャンプ2回　白い山形に注目",
	"傘を保持して上昇気流へ　反転しても落下がゆっくりになる",
	"地上で水平ダッシュ → すぐジャンプ　Space・A / ×を使おう",
]
const STEPS := [
	["jump"], ["climb", "wall_jump"], ["dash"], ["up", "down"],
	["air_dash", "dash_refill", "refilled_dash"], ["jump_crystal", "air_jump"],
	["floor_spring", "wall_spring", "spring_dash"], ["pinball"],
	["wind_walk", "wind_grab", "wind_dash"], ["up", "down"],
	["light_grab", "light_drop", "heavy_move", "button_on", "button_off"],
	["throw", "throw_button"], ["creature_jump", "creature_landed", "second_creature_jump"],
	["glide", "parachute_release", "fast_fall"],
	["two_jumps", "combo_air", "combo_creature"],
	["wind_lift", "inverted_glide", "down"], ["superdash"],
]
const STEP_LABELS := {
	"jump": "段差と穴を越えよう", "climb": "壁を掴んで登ろう",
	"wall_jump": "壁からキックで跳ぼう", "dash": "ダッシュで進もう",
	"up": "↑ ゲートで天井へ", "down": "↓ ゲートで床へ",
	"air_dash": "空中でダッシュ", "dash_refill": "緑のCrystalで回復",
	"refilled_dash": "着地前に再ダッシュ", "jump_crystal": "紫のCrystalを取ろう",
	"air_jump": "空中で追加ジャンプ", "floor_spring": "床Springで跳ぼう",
	"wall_spring": "壁Springで横に跳ぼう", "spring_dash": "Springの後にダッシュ",
	"pinball": "丸いバンパーで跳ぼう", "wind_walk": "風の中を歩こう",
	"wind_grab": "風の中で壁を掴もう", "wind_dash": "風の中でダッシュ",
	"light_grab": "小さな箱を掴もう", "light_drop": "止まって箱を置こう",
	"heavy_move": "重い箱を運ぼう", "button_on": "重い箱を置いてON",
	"button_off": "箱を持ち上げてOFF", "throw": "移動しながら投げよう",
	"throw_button": "投げた箱でボタンON", "creature_jump": "生物の追加ジャンプ",
	"creature_landed": "生物と着地して回復", "second_creature_jump": "回復後にもう一度跳ぶ",
	"glide": "傘でゆっくり落下", "parachute_release": "空中で傘を手放そう",
	"fast_fall": "傘なしの速い落下", "two_jumps": "生物と紫のCrystal",
	"combo_air": "空中ジャンプ1回目", "combo_creature": "着地せず2回目を跳ぶ",
	"wind_lift": "傘で上昇気流に乗ろう", "inverted_glide": "反転中も傘で降りよう",
	"superdash": "地上ダッシュから跳ぶ",
}

var room_index := 0
var furthest_room := 0
var transitioning := false
var completed := false
var cleared: Dictionary = {}
var seen: Dictionary = {}
var _resetting := false
var _wind_time := 0.0
var _glide_time := 0.0
var _thrown_object: Grabbable
var _released_parachute := false

@onready var rooms: Node2D = $Rooms
@onready var player: PlayerController = $Player
@onready var camera: Camera2D = $Camera2D
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	player.get_node("Camera2D").enabled = false
	player.respawned.connect(_on_respawned)
	player.movement_action.connect(_on_action)
	player.object_released.connect(_on_release)
	player.gravity_changed.connect(_on_gravity)
	player.carry_changed.connect(_on_carry)
	for room in rooms.get_children():
		var goal: ArrivalSwitch = room.get_node("Goal")
		var index := room.get_index()
		goal.activated.connect(_on_arrival.bind(index))
		room.get_node("ExitHint").z_index = 1
		goal.set_progress(STEPS[index].size(), STEPS[index].size(), STEPS[index][0], STEP_LABELS[STEPS[index][0]])
		for hint in ["ArrivalHint", "GoalHint"]:
			if room.has_node(hint):
				room.get_node(hint).hide()
		for node in room.find_children("*", "Area2D", true, false):
			if node.has_signal("collected"):
				node.collected.connect(_on_crystal.bind(node))
			if node.has_signal("launched"):
				node.launched.connect(_on_launch.bind(node))
			if node.has_signal("pressed_changed"):
				node.pressed_changed.connect(_on_button.bind(node))
	_set_room(0, false)
	_retry()
	camera.position = _camera_position()
	camera.make_current()


func _physics_process(delta: float) -> void:
	if transitioning:
		return
	_observe_lesson(delta)
	var left := room_index * ROOM_SIZE.x
	var collision_shape := player.get_node("CollisionShape2D") as CollisionShape2D
	# A taller neighboring floor can stop the player's center before the boundary.
	var right := collision_shape.to_global(collision_shape.shape.get_rect().end).x + player.safe_margin
	if right >= left + ROOM_SIZE.x and room_index < rooms.get_child_count() - 1 and cleared.has(room_index):
		_transition_to(room_index + 1)
	elif player.global_position.x < left and room_index > 0:
		_transition_to(room_index - 1)
	elif player.global_position.y > ROOM_SIZE.y + 52.0 or player.global_position.y < -52.0:
		_retry()


func _set_room(index: int, from_right: bool) -> void:
	room_index = index
	furthest_room = maxi(furthest_room, index)
	var room := rooms.get_child(index) as Node2D
	var entrance := room.get_node("Return" if from_right else "Spawn") as Marker2D
	player.set_respawn_position(entrance.global_position)
	player.wall_actions_enabled = furthest_room >= 1
	player.dash_enabled = furthest_room >= 2
	hud.show_tutorial_room(index, TITLES[index], CONTROLS[index], player.wall_actions_enabled, player.dash_enabled, MAIN_ROOM_COUNT)
	_update_lesson()


func _transition_to(index: int) -> void:
	transitioning = true
	player.controls_enabled = false
	_set_room(index, index < room_index)
	_retry()
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "position", _camera_position(), TRANSITION_TIME)
	await tween.finished
	player.controls_enabled = true
	transitioning = false


func _retry() -> void:
	_resetting = true
	player.respawn()
	_resetting = false


func _camera_position() -> Vector2:
	return Vector2(room_index * ROOM_SIZE.x, 0) + ROOM_SIZE * 0.5


func _on_respawned() -> void:
	seen.clear()
	_wind_time = 0.0
	_glide_time = 0.0
	_thrown_object = null
	_released_parachute = false
	for area in rooms.get_child(room_index).find_children("*", "Area2D", true, false):
		if area.has_method("reset_for_respawn"):
			area.reset_for_respawn()
	_update_lesson()
	if not transitioning:
		camera.position = _camera_position()
		camera.reset_smoothing()


func _active(source: Node = null) -> bool:
	return not transitioning and not _resetting and player.controls_enabled and (source == null or rooms.get_child(room_index).is_ancestor_of(source))


func _mark(key: String) -> void:
	if not _active() or seen.has(key):
		return
	seen[key] = true
	_update_lesson()


func _steps_done() -> bool:
	for key in STEPS[room_index]:
		if not seen.has(key):
			return false
	return true


func _on_arrival(index: int) -> void:
	if index != room_index or not _active() or not _steps_done() or cleared.has(index):
		return
	cleared[index] = true
	if index == MAIN_ROOM_COUNT - 1:
		completed = true
	_update_lesson()


func _update_lesson() -> void:
	var room := rooms.get_child(room_index)
	var done := cleared.has(room_index)
	room.get_node("ExitBarrier/Collision").set_deferred("disabled", done)
	room.get_node("ExitBarrier/Visual").visible = not done
	room.get_node("ExitHint").text = "任意のSuperdash →" if done and room_index == 15 else ("次の部屋へ →" if done else "到着台を押すと開く")
	room.get_node("ExitHint").modulate = Color(0.55, 1, 0.75) if done else Color(1, 0.8, 0.45)
	var count := 0
	var next := "赤い到着台に乗ろう"
	var next_key := ""
	for key in STEPS[room_index]:
		if seen.has(key):
			count += 1
		elif next_key.is_empty():
			next_key = key
			next = STEP_LABELS[key]
	room.get_node("Goal").set_progress(STEPS[room_index].size() - count, STEPS[room_index].size(), next_key, next, done)
	hud.show_lesson_progress("体験済み ✓　自由に練習できます" if done else "目標 %d/%d：%s" % [count, STEPS[room_index].size(), next], done)
	$HUD/Completion.visible = completed and room_index >= 15
	$HUD/Completion.text = "チュートリアル完了！　右は任意のSuperdash部屋" if room_index == 15 else "本編クリア済み　Superdashも自由に練習できます"
	if room_index == 16:
		room.get_node("ExitHint").text = "練習完了 ✓" if done else "到着台へ着地しよう"


func _on_action(action: String) -> void:
	if not _active():
		return
	_mark(action)
	if action == "dash":
		if not player.is_on_floor():
			if seen.has("dash_refill"):
				_mark("refilled_dash")
			_mark("air_dash")
		if seen.has("floor_spring") or seen.has("wall_spring"):
			_mark("spring_dash")
		var wind := rooms.get_child(room_index).get_node_or_null("Wind") as Area2D
		if wind != null and wind.overlaps_body(player):
			_mark("wind_dash")
	if action == "creature_jump" and seen.has("creature_landed"):
		_mark("second_creature_jump")
	if room_index == 14 and player.get_held_object() != null:
		if action == "air_jump" and seen.has("two_jumps"):
			_mark("combo_air")
		if action == "creature_jump" and seen.has("combo_air"):
			_mark("combo_creature")


func _on_crystal(body: PlayerController, crystal: Area2D) -> void:
	if body != player or not _active(crystal):
		return
	if crystal.refill_kind == 0 and not player.is_dash_ready() and seen.has("air_dash") and not player.is_on_floor():
		_mark("dash_refill")
	elif crystal.refill_kind == 1:
		_mark("jump_crystal")


func _on_launch(body: PlayerController, source: Area2D) -> void:
	if body != player or not _active(source):
		return
	_mark("pinball" if source.name == "Pinball" else ("floor_spring" if source.name == "FloorSpring" else "wall_spring"))


func _on_gravity(inverted: bool) -> void:
	if _active():
		if inverted:
			_glide_time = 0.0
			_mark("up")
		elif seen.has("up") or seen.has("inverted_glide"):
			_mark("down")


func _on_carry(label: String) -> void:
	if label == "OBJECT":
		_mark("light_grab")


func _on_release(object: Grabbable, thrown: bool) -> void:
	if not _active(object):
		return
	if object.carry_name == "OBJECT" and not thrown:
		_mark("light_drop")
	if object.carry_name == "HEAVY" and thrown:
		_thrown_object = object
		_mark("throw")
	if object.carry_name == "PARACHUTE" and not player.is_on_floor() and seen.has("glide"):
		_released_parachute = true
		_mark("parachute_release")


func _on_button(pressed: bool, button: Area2D) -> void:
	if not _active(button):
		return
	if pressed:
		_mark("button_on")
		if is_instance_valid(_thrown_object) and button.overlaps_body(_thrown_object):
			_mark("throw_button")
	elif seen.has("button_on") and player.get_held_object() != null:
		_mark("button_off")


func _observe_lesson(delta: float) -> void:
	if room_index == 4 and player.is_on_floor() and not seen.has("refilled_dash") and (seen.has("air_dash") or seen.has("dash_refill")):
		seen.erase("air_dash")
		seen.erase("dash_refill")
		_update_lesson()
	if player.is_wall_grabbing() and player.velocity.y < -20:
		_mark("climb")
	var held := player.get_held_object()
	if held != null and held.carry_name == "HEAVY" and absf(player.velocity.x) > 200:
		_mark("heavy_move")
	if held != null and held.carry_name == "JUMP":
		if player.get_available_extra_jump_count() == 2:
			_mark("two_jumps")
		if player.is_on_floor() and seen.has("creature_jump") and held.extra_jump_count() > 0:
			_mark("creature_landed")
	var wind := rooms.get_child(room_index).get_node_or_null("Wind") as Area2D
	if wind != null and wind.overlaps_body(player):
		if player.is_wall_grabbing():
			_mark("wind_grab")
		elif not player.is_dashing() and absf(player.velocity.x) > 30:
			_wind_time += delta
			if _wind_time > 0.3:
				_mark("wind_walk")
		if held != null and held.carry_name == "PARACHUTE" and player.velocity.y < -80:
			_mark("wind_lift")
	if held != null and held.carry_name == "PARACHUTE" and not player.is_on_floor() and not player.is_dashing() and player.velocity.y * player.gravity_direction > 170:
		_glide_time += delta
		if _glide_time > 0.3:
			_mark("glide")
			if player.gravity_direction < 0:
				_mark("inverted_glide")
	if _released_parachute and player.velocity.y > 260:
		_mark("fast_fall")
	if room_index == 14 and player.is_on_floor() and seen.has("combo_air") and not seen.has("combo_creature"):
		seen.erase("combo_air")
		_update_lesson()
