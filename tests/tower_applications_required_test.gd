extends "res://tests/tower_fifth_required_test.gd"

const APPLICATION_KINDS:=["32_wall","32_companion","33_refill","33_spring","34_boot","34_bumper","34_wall","34_spring"]


func _run() -> void:
	var selected:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):selected=arg.trim_prefix("--only=")
	for kind in APPLICATION_KINDS:
		if selected!="" and not selected.split(",").has(kind):continue
		for timing in [16,24,40]:
			for direction in DIRECTIONS:
				await _missing_application(kind,direction,timing)
				if failed:return
		print("APPLICATION_REQUIRED kind=",kind," attempts=",attempts)
	if selected=="" or selected=="carried":
		for strength in [1.0,0.8]:
			upper_strength=strength
			await _fresh_fourth(31)
			monitor_view=false
			await _application32()
			var object: Grabbable=player.get_held_object()
			_check(object==stage.get_node("Items/Application32Companion") and stage.checkpoint_index==32,"The same native Green really reaches the next checkpoint")
			_off("Application33Dash")
			await _upper_pulse("jump")
			await _step(20)
			await _upper_pulse("jump")
			await _step(20)
			await _upper_dash()
			await _land_on(-150,-40306,360)
			_check(respawns==0 and player.get_held_object()==object,"The actual preceding Green is a legal alternative to the first refill")
			await _fourth_put_aside()
			await _fourth_spring(80,Vector2(200,-40880))
			await _more_walk(200)
			_check(stage.checkpoint_index==33 and respawns==0,"The legal carry alternative rejoins its real next checkpoint")
			actual_transports+=1
	monitor_view=false
	_release()
	current_scene.queue_free()
	await _step(18)
	print("TOWER_APPLICATION_REQUIRED_TEST_OK checks=",checks," attempts=",attempts," actual_transports=",actual_transports)
	quit(1 if failed else 0)


func _missing_application(kind: String,direction: Vector2,timing: int) -> void:
	var section:=int(kind.split("_")[0])-1
	await _fresh_fourth(section)
	monitor_view=false
	var target:=""
	match kind:
		"32_wall":
			player.wall_actions_enabled=false
			await _more_walk(80)
			target="Application32Rest"
		"32_companion":
			await _application32_wall()
			await _more_walk(250)
			target="Application33Checkpoint"
		"33_refill":
			_off("Application33Dash")
			target="Application33Rest"
		"33_spring":
			_off("Application33Spring")
			await _application33_refill()
			await _more_walk(80)
			target="Application34Checkpoint"
		"34_boot","34_bumper":
			_off("Application34Boot" if kind=="34_boot" else "Application34Bumper")
			await _more_walk(150)
			upper_bounces=0
			stage.get_node("Items/Application34Bumper").launched.connect(_on_upper_bounce)
			target="Application34Rest"
		"34_wall":
			await _application34_reflection()
			player.wall_actions_enabled=false
			await _more_walk(850)
			target="Application34UpperRest"
		"34_spring":
			_off("Application34Spring")
			await _application34_reflection()
			await _more_walk(850)
			await _more_climb("Application34Wall")
			await _more_walk(800)
			target="ApplicationSummit"
	await _fifth_flight(section,_world_floor(target),direction,timing,false,true,0.0 if kind in ["34_boot","34_bumper"] else NAN)
	attempts+=1
