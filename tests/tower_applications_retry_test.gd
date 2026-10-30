extends "res://tests/tower_applications_route_test.gd"


func _run() -> void:
	upper_strength=0.8
	upper_jump_delay=20
	upper_dash_delay=20
	for section in [31,32,33]:
		await _fresh_fourth(section)
		stage.set_hints_visible(true)
		_assert_static_checkpoint()
		if section==31:
			await _application32_wall()
			await _more_grab("Application32Companion")
			await _upper_pulse("jump")
			await _step(16)
			await _upper_pulse("jump")
			_check(player.get_held_object()==stage.get_node("Items/Application32Companion"),"R preparation actually holds the same native Green after its extra jump")
		elif section==32:
			await _application33_refill()
			_check(not stage.get_node("Items/Application33Dash").visible,"R preparation actually consumes its refill")
		else:
			await _more_walk(150)
			await _upper_pulse("jump")
			await _step(20)
			await _upper_pulse("jump")
			_check(not stage.get_node("Items/Application34Boot").visible,"R preparation actually consumes its Boot")
		await _upper_pulse("reset")
		_release()
		await _step(8)
		_check(respawns==1 and stage.checkpoint_index==section and player.is_on_floor() and player.position.distance_to(player._spawn_position)<3,"Actual moving R restores the same native static checkpoint")
		_check(player.is_dash_ready() and player.get_wall_stamina()>2.9 and player.get_held_object()==null,"R restores resources and releases its held object")
		if section==32:_check(stage.get_node("Items/Application33Dash").visible,"Immediate R restores the consumed native refill")
		if section==33:_check(stage.get_node("Items/Application34Boot").visible,"Immediate R restores the consumed native Boot")
		_assert_static_checkpoint()
		Input.action_press("move_left",upper_strength)
		Input.action_press("move_down")
		await _upper_pulse("dash")
		for frame in 720:
			Input.action_press("move_left",upper_strength)
			await _step()
			if respawns>1:break
		_release()
		await _step(8)
		_check(respawns==2 and stage.checkpoint_index==section and player.is_on_floor() and player.position.distance_to(player._spawn_position)<3,"Actual leftward controls leave the native floor and fall back once")
		await _application_course(section)
		_check(respawns==2 and root.get_node("CollectionProgress").get_count("tower")==0,"The actual restored course replays without another fall or an optional collection")
		if failed:return
	monitor_view=false
	_release()
	current_scene.queue_free()
	await _step(18)
	print("TOWER_APPLICATION_RETRY_TEST_OK checks=",checks)
	quit(1 if failed else 0)


func _fifth_view(phase: String) -> void:
	await super._fifth_view(phase)
	if phase in ["32_wall","33_rest","34_rest","34_wall"]:
		var before:=respawns
		var stopped:=player.position
		await _step(180)
		_check(player.is_on_floor() and player.position.distance_to(stopped)<3 and respawns==before,"Each actual observation shelf supports a three-second rest")
