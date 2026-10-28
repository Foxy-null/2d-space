extends SceneTree

var stage
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _fresh()
	var actor: PlayerController = stage.player
	actor._wall_stamina = 1.0
	actor._refill_on_landing()
	_check(actor.get_wall_stamina() == 3.0, "Ordinary landing still refills stamina instantly")
	stage._damage_player(0.45, Vector2.ZERO, true)
	_check(is_equal_approx(actor.get_wall_stamina(), 2.55) and actor.stun_left == 0.0, "A ground spine takes 15 percent without locking movement")
	_check(actor.recovery_slow_left == 4.0 and actor.movement_slow_left == 1.0, "The first hit starts fatigue and a short slow")
	_check(is_equal_approx(actor.get_effective_move_speed(), actor.move_speed * 0.7), "Ground spines reduce running speed by thirty percent")
	actor._refill_on_landing()
	actor.refill_movement_resources()
	_check(is_equal_approx(actor.get_wall_stamina(), 2.55) and actor.is_dash_ready(), "Landing and springs cannot bypass fatigue, while escape abilities still refill")
	stage._damage_player(0.45, Vector2.ZERO, true)
	_check(actor.recovery_slow_left == 4.0 and is_equal_approx(actor.get_wall_stamina(), 2.55), "Invulnerable contacts neither hurt nor extend fatigue")
	stage._hit_grace = 0.0
	stage._damage_player(0.45, Vector2.ZERO, true)
	_check(actor.recovery_slow_left == 6.0, "A second real hit adds two seconds")
	for hit in 3:
		stage._hit_grace = 0.0
		actor._wall_stamina = 3.0
		stage._damage_player(0.45, Vector2.ZERO, true)
	_check(actor.recovery_slow_left == 8.0, "Repeated damage caps the fatigue duration")
	stage._update_hud()
	_check(stage._condition.text.contains("回復低下") and stage._condition.text.contains("減速"), "Both effects are described on the HUD")
	stage.retry_room()
	_check(actor.recovery_slow_left == 8.0 and is_equal_approx(actor.get_wall_stamina(), 2.55), "Retrying a room preserves attack damage and fatigue")
	stage.get_node("PauseMenu").open()
	stage.get_node("PauseMenu").retry()
	_check(actor.recovery_slow_left == 8.0 and is_equal_approx(actor.get_wall_stamina(), 2.55), "Pause retry uses the same preservation rule")
	actor.set_physics_process(true)
	await _step(32)
	_check(actor.get_wall_stamina() > 2.55 and actor.get_wall_stamina() < 2.8, "Grounded fatigue recovery is gradual")
	var remaining := actor.recovery_slow_left
	stage.set_help_visible(true)
	await _step(20)
	_check(actor.recovery_slow_left == remaining, "Help and pause freeze status timers")
	stage.set_help_visible(false)
	actor.recovery_slow_left = 0.01
	await _step(3)
	_check(actor.get_wall_stamina() == 3.0, "Instant ground recovery returns when fatigue ends")
	actor.set_physics_process(false)
	actor._wall_stamina = 0.0
	_check(not stage._game_over_pending, "Using all stamina on movement is not itself a defeat")
	stage._hit_grace = 0.0
	stage._respawn_grace = 0.0
	stage._damage_player(0.45, Vector2.ZERO, true)
	_check(stage._game_over_pending and paused and not actor.controls_enabled, "An actual hit at zero stamina starts a frozen defeat transition")
	_check(stage._stamina.value == 0.0, "The defeat HUD shows the fatal stamina loss immediately")
	await _step(80)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn" and not paused, "Defeat actually returns to the unpaused selection scene")
	_check(current_scene.get_viewport().gui_get_focus_owner().name == "Stage6", "Stage six is selected for the next attempt")
	await _fresh()
	actor = stage.player
	var directions: Array[Vector2] = [Vector2.DOWN]
	stage._spawn_needles(Vector2(180, 650), directions, 3)
	var needle = stage.room.needles.get_child(0)
	needle.advance(0.4, actor)
	_check(needle.stuck, "The endurance fixture uses a real needle embedded in the floor")
	_check(stage._touches_stuck_needle(actor, actor.position) and not stage._touches_hazard(actor, actor.position), "Residual needles have a separate nonfatal contact path")
	_check(not stage._touches_stuck_needle(stage.enemy, needle.tip_position()), "The enemy remains immune to residual needles")
	actor.set_physics_process(true)
	stage.set_physics_process(true)
	stage._chase_delay = -1.0
	var generation: int = stage._generation
	await _step(3)
	_check(stage._generation == generation and actor.get_wall_stamina() < 3.0, "A real tip contact hurts without teleporting the ninja")
	for frame in 800:
		if not is_instance_valid(stage) or stage._game_over_pending:
			break
		# Keep this ash needle for a sustained-contact fixture instead of its normal expiry.
		needle.stuck_left = 10.0
		await _step()
	_check(is_instance_valid(stage) and stage._game_over_pending, "Sustained contact drains faster than ground recovery and cannot be tanked indefinitely")
	await _step(80)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Residual-needle stamina loss uses the same defeat exit")
	print("STAGE_6_FATIGUE_TEST_OK (%d checks)" % checks)
	quit()


func _fresh() -> void:
	change_scene_to_file("res://scenes/stage_6.tscn")
	await _step(4)
	stage = current_scene
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	stage.enemy.set_physics_process(false)
	stage.room.set_physics_process(false)
	stage._intro_left = 0.0
	stage._intro_panel.hide()
	stage.player.controls_enabled = true
	stage._respawn_grace = 0.0
	stage._hit_grace = 0.0


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
