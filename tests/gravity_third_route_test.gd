extends "res://tests/stage_3_test.gd"

var progress: Node
var negatives := 0
var captured: Dictionary = {}


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://gravity_third_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	var arguments := OS.get_cmdline_user_args()
	var selected := -1
	for argument in arguments:
		if argument.begins_with("--room="): selected = int(argument.trim_prefix("--room=")) - 1
	if arguments.has("--entry-captures"):
		for index in ([selected] if selected >= 15 and selected <= 20 else [15,16,17,18,19,20]):
			await _fresh(index)
			await _third_entry(index)
	elif arguments.has("--timing"):
		for gap in [16, 24]: await _main_routes([1.0, 0.8], [15,16,17,18,19,20], gap)
	elif arguments.has("--negative-only"):
		await _negative_routes()
	elif arguments.has("--roof-only"):
		await _roof_routes()
	elif arguments.has("--guards-only"):
		await _roof_guards()
	elif arguments.has("--recovery-only"):
		await _recoveries()
	elif arguments.has("--seams-only"):
		await _seams()
	elif arguments.has("--capture-only"):
		await _main_routes([1.0])
		for index in [17,19]:
			await _confirm_branch(index,false)
			progress._collected.clear()
			await _confirm_branch(index,true)
			progress._collected.clear()
	elif selected >= 15 and selected <= 20:
		await _main_routes([1.0, 0.8], [selected])
	elif arguments.has("--scroll-only"):
		await _scroll_routes()
	else:
		await _main_routes()
		if not arguments.has("--routes-only"): await _scroll_routes()
	await _finish()


func _main_routes(strengths: Array = [1.0, 0.8], indices: Array = [15,16,17,18,19,20], gap := 20) -> void:
	for strength in strengths:
		third_strength = strength
		for index in indices:
			await _fresh(index)
			_third_drive(_third_x() + 100)
			_check(is_equal_approx(absf(Input.get_axis("move_left", "move_right")), strength), "The real action axis uses its direct 1.0 or 0.8 strength")
			_release_inputs()
			var start := Engine.get_physics_frames()
			await _third_course(index, gap)
			if index in [17, 19]:
				await _third_walk(72)
				await _third_capture("room_%d_right_return" % (index+1))
			var seconds := float(Engine.get_physics_frames() - start) / 60.0
			print("GRAVITY_THIRD_ROOM_%d %.2fs strength=%.2f gap=%d actions=%s flips=%s" % [index+1, seconds, strength, gap, actions, flips])
			_check(respawns == 0 and stage.cleared.has(index) and seconds < 30, "Two connected challenges, an idle rest and the actual return stay below thirty seconds")
			_check(actions.get("dash", 0) == [2,2,2,2,3,4][index-15] and actions.get("dash_crystal", 0) == (2 if index == 20 else 1), "The new route actually spends its intended Dash refills")
			_check(flips == [-1, 1] and not actions.has("air_jump"), "Both real gravity directions are used without an airborne boot")
			_check(index != 18 or actions.get("wall_jump",0) >= 3, "The staggered projections keep the intended wall kicks")
			_check(progress.get_count("gravity") == 0, "Normal main traversal leaves every optional scroll untouched")
			await _retry()
			_check(stage.cleared.has(index) and player.gravity_direction == 1, "R keeps the actually cleared checkpoint and restores normal gravity")
			for name in stage.rooms.get_child(index).get_meta("return_retract"):
				_check(not stage.rooms.get_child(index).get_node(NodePath(name)).visible, "Only actual arrival opens the physical return lane")


func _fresh(index: int) -> void:
	_release_inputs()
	_reset_course()
	change_scene_to_file("res://scenes/stage_3.tscn")
	await _step(4)
	stage = current_scene
	player = stage.player
	stage._set_room(index, false)
	player.respawn()
	await _step(4)
	respawns = 0
	actions.clear()
	flips.clear()
	player.movement_action.connect(func(action): actions[action] = actions.get(action,0) + 1)
	player.gravity_changed.connect(func(inverted): flips.append(-1 if inverted else 1))
	player.respawned.connect(func(): respawns += 1)
	for node in stage.rooms.get_child(index).get_children():
		if node.has_signal("collected") and node.get_script().resource_path == "res://scripts/refill_crystal.gd":
			node.collected.connect(func(_body): actions["dash_crystal"] = actions.get("dash_crystal",0) + 1)
	var total := 0
	for room in stage.rooms.get_children():
		for node in room.find_children("*", "Area2D", true, false):
			if node.get_script() != null and node.get_script().resource_path == "res://scripts/scroll_collectible.gd": total += 1
	_check(total == 10 and progress.TOTALS["gravity"] == total, "The ten actual scroll nodes match the stage-selection total")
	_check(stage.rooms.get_child_count() == 37 and not stage.completed, "Thirty-seven native rooms begin without a premature completion")
	await _third_capture("room_%d_entrance" % (index+1))


func _finish() -> void:
	_release_inputs()
	if OS.get_cmdline_user_args().has("--keep-fixture"):
		print("GRAVITY_THIRD_SAVED_PATH ", progress.save_path)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	current_scene.queue_free()
	await _step(5)
	print("GRAVITY_THIRD_ROUTE_TEST_%s (%d checks, %d negative trials)" % ["FAILED" if failed else "OK", checks, negatives])
	quit.call_deferred(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	super._check(condition, message)
	if not condition:
		_release_inputs()
		quit(1)


var branch_started := 0


func _scroll_routes() -> void:
	for strength in [1.0, 0.8]:
		third_strength = strength
		progress._collected.clear()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		for index in [17, 19]:
			var id := _third_scroll_id(index)
			var previous: int = progress.get_count("gravity")
			for interruption in ["retry", "death", "leave"]:
				await _fresh(index)
				await _branch_touch(index, false)
				var scroll: Area2D = stage.rooms.get_child(index).get_node("Scroll")
				_check(scroll._follower == player and not progress.has_scroll("gravity", id), "The optional branch actually touches a pending airborne scroll")
				if interruption == "retry":
					await _retry()
					_check(scroll._follower == null and scroll.global_position == scroll._origin, "R returns the real pending scroll to its native position")
				elif interruption == "death":
					var hits: Array[bool] = []
					stage.rooms.get_child(index).get_node("ScrollTrap").player_hit.connect(func(): hits.append(true), CONNECT_ONE_SHOT)
					var before := respawns
					_third_drive(1390)
					await _until(func(): return respawns > before, 180, "Real lateral movement touches the visible branch spikes before confirming")
					_release_inputs()
					await _step(5)
					_check(not hits.is_empty() and scroll._follower == null and scroll.global_position == scroll._origin, "Actual spike death cancels the pending pickup")
				else:
					stage.get_node("PauseMenu").return_to_select()
					await _step(4)
				_check(progress.get_count("gravity") == previous, "Pending retry, contact death and unfinished return do not change the saved count")
			await _confirm_branch(index, false)
		# Recollect after real arrival rather than reusing a faint confirmed node.
		progress._collected.clear()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		for index in [17, 19]: await _confirm_branch(index, true)
	# The existing four IDs are exercised by the retained old branch suites, separately from this total fixture.
	for id in ["wall_loft_01", "inverted_return_02", "upper_current_03", "left_depth_04"]:
		_check(progress.collect_scroll("gravity", id) == OK, "Old confirmed IDs combine with the two actually recollected new branches")
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(4)
	var card: Button = current_scene.get_node("Margin/Content/Stages/Stage3")
	_check(card.get_node("Content/Collection/Count").text == "6 / 10" and card.accessibility_name.contains("巻物 6 / 10") and not card.disabled, "Visible and accessible stage selection show six retained scrolls of ten")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.get_count("gravity") == 6, "Six unique IDs survive a fresh file reload")


func _third_scroll_id(index: int) -> String:
	return "wind_return_05" if index == 17 else "upper_return_06"


func _branch_touch(index: int, after: bool) -> void:
	if after:
		await _third_course(index)
		_check(stage.cleared.has(index), "Post-arrival exploration first physically presses the actual goal")
		await _third_walk(1300)
	else:
		await _third_entry(index)
		if index == 17: await _third_horizontal(20, true)
		else: await _third_walk(1300)
	branch_started = Engine.get_physics_frames()
	if after and index == 19:
		await _jump()
		await _step(20)
		await _third_dash(Vector2.UP)
		await _until(func(): return player.is_on_floor() and player.position.y < 850, 180, "The opened return lane can jump to the actual optional one-way shelf")
		_release_inputs()
		await _step(12)
	await _jump()
	await _step(20)
	await _third_dash(Vector2.UP if after else Vector2.DOWN)
	if not after and index == 19:
		await _until(func(): return not player.is_dashing(), 30, "The branch's first downward Dash finishes")
		_check(player.is_dash_ready(), "The optional airborne branch Crystal supplies the second downward Dash")
		await _third_dash(Vector2.DOWN)
	var scroll: Area2D = stage.rooms.get_child(index).get_node("Scroll")
	await _until(func(): return scroll._follower == player, 120, "Actual input reaches the new branch's airborne scroll")
	_release_inputs()
	await _third_capture("room_%d_scroll_%s" % [index+1,"after" if after else "before"])


func _confirm_branch(index: int, after: bool) -> void:
	var id := _third_scroll_id(index)
	var previous: int = progress.get_count("gravity")
	await _fresh(index)
	await _branch_touch(index, after)
	await _until(func(): return progress.has_scroll("gravity", id) and player.is_on_floor(), 180, "The real safe landing confirms the actual new scroll")
	await _third_rest()
	var expected_y := (774 if index == 19 else 1074) if after else (206 if index == 19 else 526)
	_check(absf(player.position.y - expected_y) < 5 and respawns == 0, "The collectible confirms on the intended safe support without a death or a stage re-entry")
	if after and index == 19:
		_third_drive(1500)
		await _until(func(): return player.is_on_floor() and player.position.y > 1000, 180, "Walk off the optional shelf onto the opened main bridge")
	await _third_walk(1300)
	await _third_capture("room_%d_scroll_return_%s" % [index+1,"after" if after else "before"])
	var seconds := float(Engine.get_physics_frames() - branch_started) / 60.0
	print("GRAVITY_THIRD_SCROLL_%d %.2fs strength=%.2f after=%s" % [index+1,seconds,third_strength,after])
	_check(seconds < 30 and progress.get_count("gravity") == previous+1, "The physical optional round trip and idle rest stay short and count once")
	if not after:
		if index == 17: await _third_walk(1500)
		else: await _third_exit_high()
		await _third_goal()
		_check(stage.cleared.has(index) and respawns == 0, "The collected branch rejoins the real main course and reaches actual arrival")
	await _third_walk(72)
	await _retry()
	_check(progress.has_scroll("gravity",id) and stage.cleared.has(index), "R after returning from the branch preserves the confirmed record and opened lane")
	if OS.get_cmdline_user_args().has("--capture-only"): return
	await _confirmed_contact_death(index)
	_check(progress.get_count("gravity") == previous+1 and progress.has_scroll("gravity",id), "An actual later contact death preserves confirmed collection")
	stage.get_node("PauseMenu").return_to_select()
	await _step(4)
	var card: Button = current_scene.get_node("Margin/Content/Stages/Stage3")
	var expected := "%d / 10" % (previous+1)
	_check(card.get_node("Content/Collection/Count").text == expected and card.accessibility_name.contains("巻物 "+expected), "An unfinished return preserves the record in visible and accessible stage selection")
	progress._collected.clear()
	progress.load_progress()
	_check(progress.get_count("gravity") == previous+1 and progress.has_scroll("gravity",id), "The confirmed optional pickup survives rereading the actual save file")
	await _fresh(index)
	_check(stage.rooms.get_child(index).get_node("Scroll").modulate.a < 1, "Confirmed scrolls remain faint on a fresh revisit")


func _confirmed_contact_death(index: int) -> void:
	await _fresh(index)
	await _third_entry(index)
	var hits: Array[bool] = []
	var hazard := "EntryEdgeSpikes" if index in [15,17] else "TopSpikes"
	stage.rooms.get_child(index).get_node(NodePath(hazard)).player_hit.connect(func(): hits.append(true), CONNECT_ONE_SHOT)
	_third_drive(200 if index == 18 else 2000)
	await _until(func(): return respawns > 0, 360, "Omitting the next transfer physically hits the actual visible edge or ceiling spikes")
	_release_inputs()
	await _step(5)
	_check(not hits.is_empty() and player.position.distance_to(player._spawn_position) < 5 and player.gravity_direction == 1 and player.is_dash_ready(), "Actual contact death restores the current checkpoint and movement resources")


func _negative_routes() -> void:
	var directions := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]
	var only := -1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--room="): only = int(argument.trim_prefix("--room="))-1
	for example in [[15,"DashCrystal","horizontal"], [16,"DashCrystal","down"], [17,"DashCrystal","horizontal"], [18,"DashCrystal","corner"], [19,"DashCrystal","up"], [20,"UpDashCrystal","up"], [20,"DownDashCrystal","down"]]:
		if only >= 0 and only != example[0]: continue
		for gap in [16,24]:
			for aim in directions:
				await _fresh(example[0])
				var mode: String = example[2]
				if mode == "up":
					await _third_walk(700 if example[0] == 19 else 450)
				else:
					await _third_entry(example[0])
					if mode == "horizontal": await _third_walk(640)
					elif mode == "corner": await _third_walk(850)
				stage.rooms.get_child(example[0]).get_node(NodePath(example[1])).monitoring = false
				await _jump()
				await _step(gap)
				await _third_dash(aim)
				var bypass := false
				for frame in 300:
					_third_drive(1300 if mode in ["horizontal","corner"] else _third_x())
					await _step()
					if respawns > 0: break
					bypass = (mode == "horizontal" and _third_x() > 1040 and player.is_on_floor()) or (mode == "corner" and player.gravity_direction == 1) or (mode == "up" and player.gravity_direction == -1) or (mode == "down" and player.gravity_direction == 1)
					if bypass: break
				negatives += 1
				_check(not bypass and not stage.cleared.has(example[0]), "Eight finite single-Dash directions cannot omit %s in room %d (gap=%d aim=%s)" % [example[1],example[0]+1,gap,aim])
		print("GRAVITY_THIRD_OMISSION_ROOM_%d_%s_OK" % [example[0]+1,example[1]])
	if only >= 0 and only != 18: return
	for gap in [16,20,24]:
		await _fresh(18)
		await _third_walk(220)
		for target in [Vector2(275,900), Vector2(165,750), Vector2(275,600)]:
			if respawns > 0: break
			if target.y == 750: _third_drive(target.x)
			await _jump()
			await _step(gap)
			await _third_dash(Vector2.UP)
			_third_drive(target.x)
			for frame in 180:
				await _step()
				if respawns > 0 or player.gravity_direction == -1 or (player.is_on_floor() and absf(player.position.y+26-target.y)<5): break
		negatives += 1
		_check(respawns > 0 and not stage.cleared.has(18) and actions.get("wall_jump",0) == 0, "The reproduced no-wall-kick cap-stepping route now hits visible top spikes")
	for gap in [8,12,16,20]:
		await _fresh(18)
		await _third_entry(18)
		stage.rooms.get_child(18).get_node("DashCrystal").monitoring = false
		for frame in 180:
			_third_drive(1200,true)
			await _step()
			if respawns > 0 or (player.is_wall_grabbing() and player.position.y > 455): break
		if respawns == 0:
			_third_drive(700)
			await _jump()
			await _step(gap)
			await _third_dash(Vector2(1,1))
			for frame in 240:
				_third_drive(1200)
				await _step()
				if respawns > 0 or player.gravity_direction == 1: break
		negatives += 1
		_check(respawns > 0 or player.gravity_direction != 1, "The reproduced wall-jump dogleg cannot omit the corner Crystal")


func _recoveries() -> void:
	for index in [15,16,17,18,19,20]:
		await _fresh(index)
		if index in [19,20]:
			await _third_walk(700 if index == 19 else 450)
		else:
			await _third_entry(index)
			if index in [15,17]: await _third_walk(640)
			elif index == 18: await _third_walk(850)
		await _jump()
		await _step(20)
		await _third_dash(Vector2.UP if index in [19,20] else (Vector2.RIGHT if index in [15,17] else Vector2.DOWN))
		await _until(func(): return actions.get("dash_crystal",0) > 0, 90, "Actually spend the airborne refill before R")
		await _retry()
		for node in stage.rooms.get_child(index).get_children():
			if node.get_script() != null and node.get_script().resource_path == "res://scripts/refill_crystal.gd":
				_check(node._available, "R resets each actual native refill before its normal respawn timer")
		_check(player.is_dash_ready() and player.gravity_direction == 1 and not stage.cleared.has(index), "Midair R restores resources without earning arrival")
		await _confirmed_contact_death(index)
		await _third_course(index)
		if index in [17,19]: await _third_walk(72)
		_check(stage.cleared.has(index) and respawns == 1, "A real ceiling-spike death can retry the whole room and its opened physical return")
		await _retry()
		_check(stage.cleared.has(index) and player.gravity_direction == 1 and player.is_dash_ready(), "Cleared-room R restores resources while retaining only earned arrival")


func _roof_routes() -> void:
	var directions := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]
	for index in [15,16,17,18,19,20]:
		for aim in directions:
			await _fresh(index)
			_third_drive(2200,true)
			await _jump()
			await _step(20)
			await _third_dash(aim)
			for frame in 360:
				_third_drive(2200,true)
				await _step()
				if respawns > 0 or stage.cleared.has(index): break
			negatives += 1
			_check(not stage.cleared.has(index), "A representative entrance Jump and eight-way Dash cannot reach arrival through the roof or lower route")
	await _roof_guards()


func _roof_guards() -> void:
	for index in [15,17]:
		for gap in [0,8,16,24]:
			await _fresh(index)
			await _third_entry(index)
			stage.rooms.get_child(index).get_node("DashCrystal").monitoring = false
			var hits: Array[bool] = []
			stage.rooms.get_child(index).get_node("EntryEdgeSpikes").player_hit.connect(func():hits.append(true),CONNECT_ONE_SHOT)
			await _third_walk(640)
			_third_drive(690)
			await _jump()
			for frame in 120:
				_third_drive(690)
				await _step()
				if respawns > 0 or (player.velocity.y < 0 and player.position.y < 630 and _third_x()>680): break
			_third_drive(640,true)
			for frame in 120:
				await _step()
				if respawns > 0 or player.is_wall_grabbing(): break
			if respawns == 0:
				_third_drive(1300)
				await _jump()
				await _step(gap)
				await _third_dash(Vector2.RIGHT)
				for frame in 200:
					_third_drive(1400)
					await _step()
					if respawns > 0 or (player.is_on_floor() and _third_x()>1040): break
			negatives += 1
			_check(respawns > 0 and not hits.is_empty() and not stage.cleared.has(index), "The reproduced inverted Jump, edge re-grab and wall-kick now touches the visible vertical-edge spikes")
	for gap in [0,8,16,24]:
		await _fresh(18)
		await _third_shaft(490.0,false)
		var hits: Array[bool] = []
		stage.rooms.get_child(18).get_node("LeftGripTop").player_hit.connect(func():hits.append(true),CONNECT_ONE_SHOT)
		_third_drive(110,true)
		for frame in 180:
			await _step()
			if respawns > 0 or (player.is_wall_grabbing() and player.position.y<330): break
		if respawns == 0:
			await _third_dash(Vector2.UP)
			for frame in 180:
				_third_drive(118)
				await _step()
				if respawns > 0 or player.is_on_floor(): break
		if respawns == 0:
			_third_drive(600)
			await _jump()
			await _step(gap)
			await _third_dash(Vector2(1,-1))
			for frame in 240:
				_third_drive(2200,true)
				await _step()
				if respawns>0 or stage.cleared.has(18): break
		negatives += 1
		_check(respawns > 0 and not hits.is_empty() and not stage.cleared.has(18), "The reproduced left-wall top refill and roof route now touches its visible cap spikes")


func _third_capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots") or captured.has(name): return
	if name.ends_with("_arrival") and not name.begins_with("room_21"): return
	captured[name] = true
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/gravity-third")
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/screenshots/gravity-third/%s.png" % name)


func _seams() -> void:
	await _fresh(14)
	await _composite_course(14)
	await _reach_goal()
	_check(stage.cleared.has(14) and not stage.completed, "Actual old fifteenth arrival no longer finishes the stage")
	_reset_course()
	_drive("move_right")
	await _until(func(): return stage.room_index == 15, 180, "Physically cross the retired old final boundary into room sixteen")
	_release_inputs()
	_check(player.position.distance_to(stage.rooms.get_child(15).get_node("Spawn").global_position) < 10, "The new room receives its native left entrance")
	await _third_course(15)
	_third_drive(-50)
	await _until(func(): return stage.room_index == 14, 480, "Walk back across the newly opened room-sixteen return to old fifteen")
	_release_inputs()
	_check(stage.cleared.has(14) and stage.cleared.has(15) and player.gravity_direction == 1 and player.position.x > stage.rooms.get_child(14).position.x+2400, "Backward transfer uses old fifteen's physical right return and retains both arrivals")
	_reset_course()
	_drive("move_right")
	await _until(func(): return stage.room_index == 15, 120, "Revisit the sixteenth native entrance from the old room")
	_release_inputs()
	_check(stage.rooms.get_child(15).get_node("ReturnBridge").visible and not stage.completed, "The revisited room keeps its earned return bridge without premature completion")
	for index in [17,19]:
		await _fresh(index)
		await _third_course(index)
		await _third_walk(72)
		_third_drive(-50)
		await _until(func(): return stage.room_index == index+1, 180, "The left-going room returns physically right into its next native entrance")
		_release_inputs()
		await _step(25)
		var next_room: Node2D = stage.rooms.get_child(index+1)
		_check(player.position.distance_to(next_room.get_node("Spawn").global_position) < 10, "Forward transfer lands at the actual next checkpoint")
		_drive("move_left")
		await _until(func(): return stage.room_index == index, 180, "Immediately return from the next entrance into the actual left-facing room's right marker")
		_release_inputs()
		await _step(25)
		_check(stage.cleared.has(index) and player.position.distance_to(stage.rooms.get_child(index).get_node("Return").global_position) < 12 and player.gravity_direction == 1, "Re-entered left courses retain their real arrival and right-side return")
	for strength in [1.0,0.8]:
		third_strength = strength
		await _fresh(18)
		await _third_walk(60)
		_check(player.is_on_floor() and respawns == 0 and flips.is_empty(), "The new left-wall underpass permits ordinary backward walking before room-nineteen arrival")
		var hits: Array[bool] = []
		stage.rooms.get_child(18).get_node("LeftOuterSpikes").player_hit.connect(func():hits.append(true),CONNECT_ONE_SHOT)
		_third_drive(150,true)
		await _jump()
		await _until(func():return respawns>0,120,"The visible outer-wall spikes prevent turning the new entrance underpass into a shaft bypass")
		_release_inputs()
		_check(not hits.is_empty() and player.gravity_direction == 1 and player.is_dash_ready(), "Actual outer-wall contact resets the current native checkpoint safely")
