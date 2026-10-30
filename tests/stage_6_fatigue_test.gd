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
	_check(actor.recovery_slow_left == 0.0 and actor.movement_slow_left == 0.0 and actor.get_wall_stamina() == 3.0, "Retrying a room heals attack damage and clears all status effects")
	_check(stage._condition.text.is_empty() and stage._stamina.value == 3.0, "Retry updates the HUD immediately")
	actor.apply_attack_damage(0.45, true)
	stage.get_node("PauseMenu").open()
	stage.get_node("PauseMenu").retry()
	_check(actor.recovery_slow_left == 0.0 and actor.movement_slow_left == 0.0 and actor.get_wall_stamina() == 3.0 and not paused, "Pause retry uses the same complete reset")
	actor.apply_attack_damage(0.45, true)
	Input.action_press("reset")
	actor._physics_process(0.0)
	Input.action_release("reset")
	_check(actor.recovery_slow_left == 0.0 and actor.movement_slow_left == 0.0 and actor.get_wall_stamina() == 3.0, "Reset input uses the same complete reset")
	await _step()
	actor.apply_attack_damage(0.45, true)
	stage.set_help_visible(true)
	stage._help.get_node("Rows/Actions/Retry").pressed.emit()
	_check(actor.recovery_slow_left == 0.0 and actor.movement_slow_left == 0.0 and actor.get_wall_stamina() == 3.0 and not paused and not stage.help_visible, "Help retry also clears conditions and resumes play")
	actor.apply_attack_damage(0.45, true)
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
	stage._load_room(6)
	actor._wall_stamina = 0.000005
	stage._hit_grace = 0.0
	stage._respawn_grace = 0.0
	stage._damage_player(0.000001, Vector2.ZERO, true)
	_check(actor.get_wall_stamina() > 0.0 and not stage._game_over_pending, "A tiny positive remainder after damage is not rounded into defeat")
	actor._wall_stamina = 0.0
	_check(not stage._game_over_pending, "Using all stamina on movement is not itself a defeat")
	stage._hit_grace = 0.0
	stage._respawn_grace = 0.0
	stage._damage_player(0.45, Vector2.ZERO, true)
	await _step(2)
	_check(stage._game_over_pending and paused and not actor.controls_enabled, "An actual hit at zero stamina starts a frozen defeat transition")
	_check(stage._stamina.value == 0.0, "The defeat HUD shows the fatal stamina loss immediately")
	await _step(80)
	_check(current_scene == stage and stage.room_index == 6 and not paused, "Defeat resumes the same room instead of restarting the stage")
	_check(actor.position == stage.room.spawn and actor.controls_enabled and not stage._game_over_pending, "The player resumes at the room checkpoint without another input")
	_check(actor.get_wall_stamina() == actor.wall_stamina_max and actor.recovery_slow_left == 0.0 and actor.movement_slow_left == 0.0, "Defeat restores stamina and clears the attack conditions")
	_check(not stage.has_node("StageIntro") and not stage._message.visible and stage._stamina.value == actor.wall_stamina_max, "Defeat darkness and messages clear and the restored stamina is displayed")
	_check(stage.get_node("PauseMenu").is_processing_input() and not stage.get_node("HUD/HelpButton").disabled and not stage.get_node("HUD/PauseButton").disabled, "Pause and help are usable again after defeat")
	stage.set_help_visible(true)
	_check(paused and stage.help_visible, "Help can actually open after the checkpoint restart")
	stage.set_help_visible(false)
	stage.get_node("PauseMenu").open()
	_check(paused and stage.get_node("PauseMenu").overlay.visible, "Pause can actually open after the checkpoint restart")
	stage.get_node("PauseMenu").resume()
	stage._hit_grace = 0.0
	stage._respawn_grace = 0.0
	actor._wall_stamina = 0.5
	stage._damage_player(1.0)
	_check(stage._game_over_pending, "A fatal flying attack uses the same defeat path")
	await _step(80)
	_check(current_scene == stage and stage.room_index == 6 and actor.get_wall_stamina() == actor.wall_stamina_max and not paused, "Repeated defeats from different attacks keep the checkpoint and restore control")
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
	await _step(65)
	_check(current_scene == stage and not stage._game_over_pending and not paused and actor.controls_enabled, "Residual-needle defeat automatically resumes the current checkpoint")
	_check(stage.room.needles.get_child_count() == 0 and actor.get_wall_stamina() == actor.wall_stamina_max and stage._respawn_grace > 0.0, "Checkpoint restart removes old needles and restores health with spawn protection")
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
