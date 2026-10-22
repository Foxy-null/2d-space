extends "res://tests/stage_3_test.gd"
var trials := 0
var intercepted := 0
var fell_out := 0
var before := 0

func _run() -> void:
	for wait in [0,12,24,36,48,60,72,84]:
		await _prepare(wait)
		_drive("move_right")
		await _until(func(): return player.is_on_floor() and player.is_on_wall() and _x()>930,180,"Reach the final floor wall")
		_drive("move_right",true)
		for frame in 180:
			if _stopped() or _x()>1020: break
			await _step()
		_release_inputs()
		if not _stopped():
			await _until(func(): return player.is_on_floor() and player.position.y>600,120,"Drop onto the exit floor")
		await _attempt("climb, phase=%d"%wait)
	for start in [830,860,890,920]:
		for direction in ["right","up","diagonal"]:
			for delay in [0,6,12,18,24,30]:
				await _prepare(0)
				_drive("move_right")
				await _until(func(): return player.is_on_floor() and _x()>800,180,"Land on the second floor")
				_release_inputs()
				await _step(12)
				if _x()>start+30:
					_drive("move_left")
					await _until(func(): return _x()<=start+30,60,"Approach the jump launch point from the right")
				elif _x()<start-30:
					_drive("move_right")
					await _until(func(): return _x()>=start-30,60,"Approach the jump launch point from the left")
				_release_inputs()
				await _step(12)
				_check(player.is_on_floor() and player.gravity_direction==1 and flips==[-1,1],"Jump starts from the floor after one gravity cycle")
				_drive("move_right")
				await _jump()
				await _step(delay)
				_release_inputs()
				if direction!="up": Input.action_press("move_right")
				if direction!="right": Input.action_press("move_up")
				Input.action_press("dash")
				await _step(10)
				await _attempt("jump + %s dash, start=%d delay=%d"%[direction,start,delay])
	_release_inputs()
	var room = stage.rooms.get_child(5)
	var wall = room.get_node("SecondLaunchWall")
	var half: Vector2 = wall.get_node("Collision").shape.size*0.5
	var gate = room.get_node("DownGate")
	var gate_half: Vector2 = gate.get_node("CollisionShape2D").shape.size*0.5
	for frame in 180:
		_check(is_equal_approx(gate.position.x-gate_half.x,wall.position.x+half.x) and gate.position.y-gate_half.y>=wall.position.y-half.y and gate.position.y+gate_half.y<=wall.position.y+half.y,"The moving Down gate stays on the right face of its wall")
		await _step()
	print("STAGE_3_ROOM_6_SHORTCUT_TEST_", "FAILED" if failed else "OK", " trials=",trials," intercepted=",intercepted," fell_out=",fell_out," checks=",checks)
	quit(1 if failed else 0)

func _prepare(wait: int) -> void:
	if failed:
		quit(1)
		return
	_release_inputs()
	change_scene_to_file("res://scenes/stage_3.tscn")
	await _step(3)
	stage = current_scene
	player = stage.player
	stage._set_room(5,false)
	player.respawn()
	await _step(3)
	flips.clear()
	player.gravity_changed.connect(func(inverted: bool): flips.append(-1 if inverted else 1))
	player.respawned.connect(func(): respawns += 1)
	before=respawns
	_check(player.gravity_direction==1 and stage.cleared.is_empty(),"Every trial starts at a fresh Room 6 entrance")
	await _step(wait)
	await _kick_gate(260,-1)
	await _kick_pair(true,-10,true)
	_drive("move_right")
	await _until(func(): return player.gravity_direction==1,180,"Reach the middle Down gate normally")
	_check(flips==[-1,1] and respawns==before,"The prefix reaches the lower route without a retry")

func _stopped() -> bool:
	return flips.count(-1)>=2 or respawns>before or stage.cleared.has(5)

func _attempt(label: String) -> void:
	trials+=1
	for frame in 240:
		if _stopped(): break
		_drive("move_right")
		if _x()>=1140: _release_inputs()
		elif player.is_on_floor() and player.is_on_wall(): Input.action_press("jump")
		await _step()
	_check(not stage.cleared.has(5),"No clear without the second Up gate: "+label)
	_check(flips.count(-1)>=2 or respawns>before,"Attempt actually hits Up gravity or falls: "+label)
	if flips.count(-1)>=2: intercepted+=1
	else: fell_out+=1
	if failed:
		print("STAGE_3_ROOM_6_SHORTCUT_TEST_FAILURE ",label," pos=",player.position," flips=",flips)
		_release_inputs()
		quit(1)
