extends SceneTree
## Reproducible presentation fixtures, separate from the normal-input course test.

const OUTPUT := "res://deliverables/stage6-course-feedback"
var stage


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	change_scene_to_file("res://scenes/stage_6.tscn")
	await _step(4)
	stage = current_scene
	stage._intro_left = 0.0
	stage._intro_panel.hide()
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	stage.enemy.set_physics_process(false)
	if OS.get_cmdline_user_args().has("--maps"):
		for number in stage.ROOM.FINAL_ROOM:
			stage._load_room(number)
			stage.room.set_physics_process(false)
			stage.room.open_passage()
			stage._entry_left = 0.0
			stage._effect_left = 0.0
			stage._respawn_grace = 0.0
			stage._hit_grace = 0.0
			stage.player.position = stage.room.passage_route[0]
			stage.player.controls_enabled = false
			stage.enemy.visuals.hide()
			stage.camera.position_smoothing_enabled = false
			stage.camera.position = Vector2(stage.room.size.x - 520, stage.room.exit_position.y - 145)
			stage.camera.zoom = Vector2.ONE * 0.9
			stage._update_hud()
			await _step(2)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUTPUT + "/passage-%02d.png" % (number + 1))
		quit()
		return
	stage.room.set_physics_process(false)
	stage.player.controls_enabled = true
	stage._effect_left = 0.0
	stage.player.position = Vector2(450, 794)
	stage.enemy.position = Vector2(820, 794)
	stage.enemy.active = false
	stage.camera.position_smoothing_enabled = false
	stage.camera.position = Vector2(640, 600)
	stage.room.visible_area = Rect2(0, 240, 1280, 720)
	stage._update_hud()
	await _step(36)
	var directions: Array[Vector2] = [Vector2.DOWN]
	stage._spawn_needles(Vector2(490, 650), directions, 3)
	stage.room.needles.get_child(0).advance(0.4, stage.player)
	await _step(60)
	await _shot("needle")
	stage._respawn_grace = 0.0
	stage._damage_player(0.45, Vector2.ZERO, true)
	stage._update_hud()
	await _step(30)
	await _shot("damage")
	await _step(70)
	stage.player.recovery_slow_left = 0.0
	stage.player.movement_slow_left = 0.0
	stage._update_hud()
	await _step(65)
	var box: Grabbable = stage.room.get_node("Items").get_child(0)
	box.position = stage.enemy.position - Vector2(150, 0)
	stage._previous_enemy = stage.enemy.position
	stage._on_release(box, true, stage.player)
	box.position = stage.enemy.position + Vector2(150, 0)
	stage._check_projectiles()
	stage._update_hud()
	await _step(15)
	await _shot("box-hit")
	await _step(65)
	stage._capture()
	await _step(30)
	await _shot("capture-failed")
	await _step(90)
	stage.player._wall_stamina = 0.0
	stage._capture()
	await _step(45)
	await _shot("checkpoint-defeat")
	await _step(65)
	await _shot("checkpoint-return")
	await _step(55)
	print("STAGE_6_FEEDBACK_REVIEW_OK")
	quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png")


func _step(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame
