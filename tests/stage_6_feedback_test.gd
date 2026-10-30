extends SceneTree

var stage
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/stage_6.tscn")
	await _step(4)
	stage = current_scene
	stage._intro_left = 0.0
	stage._intro_panel.hide()
	stage.player.controls_enabled = true
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	stage.enemy.set_physics_process(false)
	stage.room.set_physics_process(false)
	stage.room.visible_area = Rect2(0, 0, 1280, 960)
	var directions: Array[Vector2] = [Vector2.DOWN]
	stage._spawn_needles(Vector2(300, 650), directions, 3)
	var needle = stage.room.needles.get_child(0)
	needle.advance(0.4, stage.player)
	_check(needle.stuck and needle.is_dangerous() and needle.impact_left > 0.0, "A real embedded tip gains the hazard marker and impact pulse")
	_check(stage._needle_sound.playing, "A visible terrain impact plays a sound")
	stage._respawn_grace = 0.0
	stage._damage_player(0.45, Vector2.ZERO, true)
	stage._update_hud()
	_check(stage._notice.visible and stage._notice.text.contains("残針に接触") and stage._notice.text.contains("減速"), "Ground-needle contact explains the hit next to the player")
	_check(stage._feedback_sound.stream == stage._feedback_tones.ground and stage._feedback_sound.playing, "Ground contact has its own damage sound")
	_check(stage.player.modulate != Color.WHITE and stage._condition.text.contains("回復低下"), "A lingering condition has both color and explicit text")
	var notice: String = stage._notice.text
	var remaining: float = stage._notice_left
	paused = true
	stage._process(0.5)
	_check(stage._notice_left == remaining and stage._notice.text == notice, "Pausing freezes feedback instead of losing the message")
	paused = false
	stage._notice_left = 0.0
	stage._update_player_notice()
	_check(stage._notice.text == "減速・回復低下", "The transient hit message yields to a persistent condition label")
	stage.player.recovery_slow_left = 0.0
	stage.player.movement_slow_left = 0.0
	stage._process(0.0)
	_check(stage._notice.text == "状態回復" and stage._feedback_sound.stream == stage._feedback_tones.recover, "Recovery is announced when the condition actually ends")
	stage.retry_room()
	_check(stage._notice.text.is_empty() and not stage._needle_sound.playing, "Retry clears stale feedback and impact audio")
	stage.enemy.position = Vector2(500, 500)
	stage._previous_enemy = stage.enemy.position
	var box: Grabbable = stage.room.get_node("Items").get_child(0)
	box.position = stage.enemy.position - Vector2(150, 0)
	stage._on_release(box, true, stage.player)
	box.position = stage.enemy.position + Vector2(150, 0)
	stage._check_projectiles()
	_check(stage.enemy.stun_left == 2.0 and stage._notice.text.contains("箱 命中"), "A swept box hit produces a player-side confirmation")
	_check(stage._pulse_at == stage.enemy.position and stage._feedback_sound.stream == stage._feedback_tones.hit, "The actual enemy impact has a burst and a distinct reward sound")
	stage.retry_room()
	stage._capture()
	_check(stage._notice.text == "捕獲失敗" and not stage._message.visible, "Surviving capture uses only the requested short wording")
	stage.retry_room()
	await _step(20)
	_check(not stage._capture_pending and stage._notice.text.is_empty(), "An interrupted capture cannot bring old feedback back after retry")
	stage.player._wall_stamina = 0.0
	stage._capture()
	_check(paused and stage._game_over_pending and stage._message.text.contains("捕獲された") and stage._message.text.contains("チェックポイント"), "Failed capture clearly identifies defeat and the checkpoint destination")
	_check(stage._fade.material != null and stage._feedback_sound.stream == stage._feedback_tones.defeat, "Defeat uses the main-stage iris and its own sound")
	await _step(80)
	_check(not paused and not stage._game_over_pending and stage._fade.material == null and not stage._message.visible, "The defeat overlay and iris clear on restart")
	_check(stage._notice.text == "チェックポイントから再開" and stage.player.get_wall_stamina() == 3.0, "Checkpoint arrival is acknowledged with restored stamina")
	for variant in 4:
		stage.retry_room()
		stage.player.position = Vector2(350, 400)
		stage._previous_player = stage.player.position
		stage.player._wall_stamina = 0.5
		stage._respawn_grace = 0.0
		await _step(2)
		stage._spawn_needles(stage.player.position - Vector2(0, 90), directions, variant)
		var shot = stage.room.needles.get_child(0)
		shot.neutral_left = 0.0
		shot.tracking_left = 0.0
		stage._update_needles(0.3)
		var cause: String = ["敵の長針", "敵の短針", "敵の追尾トゲ", "敵の灰の雨"][variant]
		_check(stage._game_over_pending and stage._message.text.begins_with(cause + "でやられた"), "A real flying attack identifies its fatal damage source: " + cause)
		_check(not stage._message.text.contains("スタミナ切れ"), "Attack defeat is never mislabeled as movement exhaustion")
		await _step(80)
	stage._respawn_grace = 0.0
	stage.player._wall_stamina = 0.1
	stage._damage_player(0.45, Vector2.ZERO, true)
	_check(stage._message.text.begins_with("敵が残したトゲでやられた"), "A lethal embedded tip is distinguished from flying attacks and capture")
	await _step(80)
	for scene in ["grabbable", "heavy_object", "parachute_creature", "jump_creature"]:
		stage.retry_room()
		stage.enemy.position = Vector2(500, 400)
		stage.player.position = Vector2(900, 400)
		stage._previous_enemy = stage.enemy.position
		stage._previous_player = stage.player.position
		var item: Grabbable = load("res://scenes/" + scene + ".tscn").instantiate()
		stage.room.get_node("Items").add_child(item)
		var name: String = {"grabbable": "箱", "heavy_object": "重い箱", "parachute_creature": "傘", "jump_creature": "相棒"}[scene]
		item.position = stage.enemy.position - Vector2(150, 0)
		stage._on_release(item, true, stage.player)
		item.position = stage.enemy.position + Vector2(150, 0)
		stage._check_projectiles()
		_check(stage.enemy.stun_left == 2.0 and stage._notice.text.begins_with(name + " 命中！"), "Enemy stun names the actual throwable: " + name)
		item.position = stage.player.position - Vector2(150, 0)
		stage._on_release(item, true, stage.enemy)
		item.position = stage.player.position + Vector2(150, 0)
		stage.player._wall_stamina = 0.5
		stage._respawn_grace = 0.0
		stage._check_projectiles()
		_check(stage._message.text.begins_with("敵が投げた" + name + "でやられた"), "A thrown object also retains its identity on defeat: " + name)
		await _step(80)
	stage._load_room(10)
	var latch: Dictionary = stage.room.doors.filter(func(entry): return entry.button.position.x > stage.room.size.x - 1000)[0]
	var weight: Grabbable = stage.room.get_node("Items").get_children().filter(func(item): return item.carry_name == "HEAVY")[0]
	weight.position = latch.button.position - Vector2(0, 50)
	await _step(30)
	_check(latch.button.is_pressed() and latch.body.visible, "The exit's optional heavy-box switch really closes the door behind the player")
	stage.retry_room()
	_check(not latch.button.is_pressed() and not latch.body.visible, "Retry reopens the optional escape-blocking door")
	stage._clear_feedback()
	stage.queue_free()
	await _step(2)
	print("STAGE_6_FEEDBACK_TEST_OK (%d checks)" % checks)
	quit()


func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		push_error(label)
		quit(1)
		assert(ok, label)
