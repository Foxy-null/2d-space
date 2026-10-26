extends "res://tests/tower_fifth_required_test.gd"

func _run() -> void:
	for strength in [1.0,0.8]:
		upper_strength=strength
		await _held_wall()
		for delay in [0,12,24]:await _para31(delay)
	_release()
	current_scene.queue_free()
	await _step(18)
	print("TOWER_FIFTH_CARRIED_TEST_OK checks=",checks)
	quit(1 if failed else 0)

func _held_wall() -> void:
	await _fresh_fourth(25)
	monitor_view=false
	await _more_walk(-900)
	await _more_grab("Fifth26Companion")
	await _more_walk(-650)
	var object: Grabbable=player.get_held_object()
	actions.clear()
	await _upper_pulse("jump")
	var reached:=false
	for frame in 1200:
		if not player.is_dashing():
			Input.action_release("move_up")
			_horizontal(-570)
		if frame==20:await _upper_dash()
		if player.is_on_wall() and frame%12==0:await _upper_pulse("jump")
		await _step()
		if player.is_on_floor() and player.position.y< -32880:
			reached=true
			break
		if respawns>0:break
	_check(actions.get("wall_jump",0)>0 and not reached,"The finite actually-held wall-kick representative does not reach the native upper shelf")
	print("FIFTH_HELD_WALL axis=",upper_strength," reached=",reached," p=",player.position," actions=",actions," respawns=",respawns)

func _para31(delay: int) -> void:
	await _fresh_fourth(29)
	monitor_view=false
	await _fifth30()
	var object: Grabbable=player.get_held_object()
	_check(stage.checkpoint_index==30 and object==stage.get_node("Items/Fifth30Parachute") and respawns==0,"The same native parachute really travels through course30 to CP31")
	_off("Fifth31Boot")
	await _more_walk(-1450)
	await _upper_pulse("jump")
	Input.action_press("move_left",upper_strength)
	await _step(20)
	await _upper_pulse("dash")
	var wind=stage.get_node("Items/Fifth30Wind")
	var recontact:=false
	var top:=false
	for frame in 900:
		if not player.is_dashing():_horizontal(-2090)
		await _step()
		recontact=recontact or player._winds.has(wind.get_instance_id())
		if player.position.y< -37880 and absf(player.position.x+2090)<20:
			top=true
			break
		if respawns>0:break
	var bounced:=false
	if top:
		upper_bounces=0
		stage.get_node("Items/Fifth31Bumper").launched.connect(_on_upper_bounce)
		_horizontal(-1300)
		await _step(delay)
		Input.action_press("move_up")
		await _upper_pulse("dash")
		for frame in 600:
			if not player.is_dashing():
				Input.action_release("move_up")
				_horizontal(-1300)
			await _step()
			if upper_bounces>0:
				bounced=true
				break
			if respawns>0:break
	_check(recontact and top and player.get_held_object()==object and respawns==0,"The transported native parachute really returns to the previous updraft and reaches its top without resetting")
	_check(not bounced and not stage.completed,"These finite departures from the real wind do not replace the final Boot approach")
	print("FIFTH_CARRIED_PARA31 axis=",upper_strength," delay=",delay," wind_recontact=",recontact," top=",top," bounced=",bounced," completed=",stage.completed," p=",player.position," respawns=",respawns)
