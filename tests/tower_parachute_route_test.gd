extends "res://tests/stage_2_test.gd"

var checks := 0
var capture := false
var progress: Node
var monitor_view := false

func _run() -> void:
	capture = OS.get_cmdline_user_args().has("--screenshots")
	progress = root.get_node("CollectionProgress")
	for profile in ([[1.0,20]] if capture else [[1.0,20],[0.8,16],[0.8,20],[0.8,24]]):
		upper_strength = profile[0]
		parachute_delay = profile[1]
		await _fresh_para()
		Input.action_press("move_right",upper_strength)
		_check(is_equal_approx(Input.get_axis("move_left","move_right"),upper_strength),"The actual movement axis matches the tested strength")
		_release()
		var started := Engine.get_physics_frames()
		await _parachute_course()
		var seconds := (Engine.get_physics_frames()-started)/60.0
		print("TOWER_PARACHUTE_SECONDS ",seconds," axis=",upper_strength," wait=",parachute_delay," respawns=",respawns)
		_check(stage.completed and respawns == 0 and seconds < 30,"The real wind and glide course reaches Goal within thirty seconds without a fall")
		_check(progress.get_count("tower") == 0,"The main course leaves the optional scroll untouched")
		if failed: return
	for strength in ([1.0] if capture else [1.0,0.8]):
		upper_strength = strength
		progress._collected.clear()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		if not capture:
			for interruption in ["reset","fall","leave"]:
				await _fresh_para()
				await _branch_touch()
				if failed: return
				if interruption == "reset": await _upper_pulse("reset")
				elif interruption == "fall": await _fall_away()
				else:
					stage.get_node("PauseMenu").return_to_select()
					await _step(5)
					await _fresh_para()
				await _step(6)
				_check(not progress.has_scroll("tower","wind_glide_06") and not stage.get_node("ScrollBranch/ParachuteScroll")._secured,"An unconfirmed scroll cancels after real R, fall or leaving")
		await _fresh_para()
		var started := Engine.get_physics_frames()
		await _branch_touch()
		if failed: return
		await _land_on(-650,-23176,240)
		_horizontal(player.position.x)
		await _step(180)
		_check(stage.get_node("ScrollBranch/ParachuteScroll")._secured,"The real optional balcony confirms the scroll during its safe rest")
		await _parachute_view("scroll_rest")
		_horizontal(-200)
		await _upper_pulse("jump")
		await _wind_rise(-200,-23280)
		await _step(24)
		await _parachute_view("scroll_return")
		var seconds := (Engine.get_physics_frames()-started)/60.0
		_check(respawns == 0 and stage.checkpoint_index == 18 and seconds < 30,"The optional branch naturally returns to the same main wind within thirty seconds")
		print("TOWER_PARACHUTE_BRANCH_SECONDS ",seconds," axis=",upper_strength)
		await _parachute_finish()
		_check(stage.completed and progress.get_count("tower")==1,"The confirmed branch rejoins the main course and real Goal")
		await _upper_pulse("reset")
		await _step(6)
		await _fall_away()
		_check(progress.has_scroll("tower","wind_glide_06"),"Confirmed collection survives R and an actual fall")
		progress._collected.clear()
		progress.load_progress()
		_check(progress.has_scroll("tower","wind_glide_06"),"The actually acquired scroll survives a disk reload")
		stage.get_node("PauseMenu").return_to_select()
		await _step(5)
		var card: Button = current_scene.get_node("Margin/Content/Stages/Stage2")
		_check(card.get_node("Content/Collection/Count").text=="1 / 6" and card.accessibility_name.contains("巻物 1 / 6"),"Selection displays and announces the real collection count")
		await _fresh_para()
		_check(stage.get_node("ScrollBranch/ParachuteScroll")._secured,"A confirmed scroll is faint on re-entry")
	if OS.get_cmdline_user_args().has("--keep-fixture"): print("TOWER_PARACHUTE_SAVED_PATH ",progress.save_path)
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	_release()
	current_scene.queue_free()
	await _step(5)
	OS.delay_msec(100)
	print("TOWER_PARACHUTE_ROUTE_TEST_OK (",checks," checks)")
	quit()

func _fresh_para() -> void:
	monitor_view = false
	_release()
	change_scene_to_file("res://scenes/stage_2.tscn")
	await _step(6)
	stage = current_scene
	player = stage.player
	stage._set_checkpoint(18)
	player.respawn()
	await _step(8)
	respawns = 0
	player.respawned.connect(func():respawns += 1)
	monitor_view = true
	var ids := {}
	for node in stage.get_node("ScrollBranch").get_children():
		if node is Area2D:
			_check(not ids.has(node.scroll_id),"Every tower collectible has a unique ID")
			ids[node.scroll_id]=true
	_check(ids.size()==6 and progress.TOTALS["tower"]==6,"The selection total matches six actual unique placements")

func _branch_touch() -> void:
	await _parachute_begin()
	_horizontal(-650)
	await _land_on(-650,-23176,300)
	if failed: return
	await _upper_pulse("jump")
	var scroll: Area2D = stage.get_node("ScrollBranch/ParachuteScroll")
	for frame in 90:
		_horizontal(-650)
		await _step()
		if scroll._follower == player: break
	_check(scroll._follower==player and not scroll._secured and not player.is_on_floor(),"The optional scroll is acquired by a real airborne jump")
	await _parachute_view("scroll_air")

func _fall_away() -> void:
	monitor_view = false
	var before := respawns
	for frame in 600:
		_horizontal(-1400)
		await _step()
		if respawns > before: break
	_horizontal(player.position.x)
	await _step(8)
	_check(respawns==before+1 and player.is_on_floor() and stage.checkpoint_index==18 and player.is_dash_ready(),"An actual off-edge fall restores CP19 and its resources")
	monitor_view = true

func _parachute_view(phase: String) -> void:
	var shape: CollisionShape2D = player.get_node("CollisionShape2D")
	var bounds := Rect2(shape.get_global_transform_with_canvas()*shape.shape.get_rect().position,shape.shape.get_rect().size)
	var hud: Control = stage.get_node("HUD/Info")
	_check(root.get_visible_rect().encloses(bounds) and not hud.get_global_rect().intersects(bounds),"The full player stays visible outside the HUD at "+phase)
	if phase in ["wind_a","scroll_return","wind_b"]:
		var floor_node: StaticBody2D = stage.get_node("Terrain/ParachuteSummit" if phase=="wind_b" else "Terrain/ParachuteRest")
		var collision: CollisionShape2D = floor_node.get_node("Collision")
		var landing := collision.shape.get_rect()
		if phase=="wind_b": landing.position.x=landing.end.x-100
		landing.size.x=100
		landing.position=collision.get_global_transform_with_canvas()*landing.position
		_check(root.get_visible_rect().encloses(landing) and not hud.get_global_rect().intersects(landing),"The next real landing is visible before gliding at "+phase)
	if phase == "wind_b":
		for path in ["Case/Collision","Cap/Collision","Base/Collision"]:
			var goal_shape: CollisionShape2D = stage.get_node("Goal/"+path)
			var goal_bounds := Rect2(goal_shape.get_global_transform_with_canvas()*goal_shape.shape.get_rect().position,goal_shape.shape.get_rect().size)
			_check(root.get_visible_rect().encloses(goal_bounds) and not hud.get_global_rect().intersects(goal_bounds),"The actual Goal body is fully visible from the last wind before gliding")
	if phase == "rest":
		var wind: Area2D = stage.get_node("Items/ParachuteWindB")
		var fan_center: Vector2 = wind.get_global_transform_with_canvas()*Vector2(0,wind.area_size.y/2-16)
		var fan := Rect2(fan_center-Vector2(14,14),Vector2(28,28))
		_check(root.get_visible_rect().encloses(fan) and not hud.get_global_rect().intersects(fan) and not stage.get_node("HUD/PauseButton").get_global_rect().intersects(fan),"The next updraft's actual fan is visible from the safe rest outside both HUD panels")
	if capture:
		await process_frame
		RenderingServer.force_draw()
		await process_frame
		var folder := "res://docs/screenshots/tower-parachute"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		_check(root.get_texture().get_image().save_png(folder+"/"+phase+".png")==OK,"The actual native view saves: "+phase)

func _step(count: int = 1) -> void:
	for frame in count:
		await super._step()
		if monitor_view and is_instance_valid(player) and is_instance_valid(stage):
			var shape: CollisionShape2D = player.get_node("CollisionShape2D")
			var body := Rect2(shape.get_global_transform_with_canvas()*shape.shape.get_rect().position,shape.shape.get_rect().size)
			_check(root.get_visible_rect().encloses(body) and not stage.get_node("HUD/Info").get_global_rect().intersects(body) and not stage.get_node("HUD/PauseButton").get_global_rect().intersects(body),"The actual body stays visible throughout intended movement and camera changes")
			var obstacles: Array[Control] = [stage.get_node("HUD/Info"),stage.get_node("HUD/PauseButton")]
			var clear_card: PanelContainer = stage.get_node("HUD/Completion").card
			if clear_card.visible: obstacles.append(clear_card)
			var held: Grabbable = player.get_held_object()
			for obstacle in obstacles:
				_check(not obstacle.get_global_rect().intersects(body),"The completion card also leaves the actual player visible")
				if held != null:
					var held_bounds := Rect2(held.collider.get_global_transform_with_canvas()*held.collider.shape.get_rect().position,held.collider.shape.get_rect().size)
					_check(not obstacle.get_global_rect().intersects(held_bounds),"The carried parachute stays visible: panel=%s bounds=%s held=%s" % [obstacle.name,obstacle.get_global_rect(),held_bounds])

func _check(ok: bool, message: String) -> void:
	checks += 1
	super._check(ok,message)
	if not ok:
		print("PARACHUTE_FAIL ",message," p=",player.position," v=",player.velocity," cp=",stage.checkpoint_index," respawns=",respawns)
		quit(1)
