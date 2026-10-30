extends SceneTree

var stage
var player: PlayerController
var origin := Vector2.ZERO
var deaths := 0
var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var progress := root.get_node("CollectionProgress")
	progress.save_path = "user://tower_route_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	progress._cleared.clear()
	change_scene_to_file("res://scenes/stage_2.tscn")
	await scene_changed
	if current_scene.has_node("StageIntro"):
		await current_scene.get_node("StageIntro").tree_exited
	stage = current_scene
	player = stage.player
	player.respawned.connect(func():
		if not player.room_transfer_in_progress:
			deaths += 1
	)
	for test_case in [[_a, 1], [_b, 2], [_c, 3], [_d, 4], [_e, 5], [_f, 6], [_g, 6]]:
		await test_case[0].call()
		release()
		_check(deaths == 0 and stage.room_index == test_case[1], "Each main room reaches its actual next room without death: " + str(test_case[1]))
		print("TOWER_MAIN_ROUTE ", test_case[1], " deaths=", deaths)
	_check(progress.get_count("tower") == 0, "The entire main route can be traversed without taking a scroll")
	_check(progress.is_cleared("tower"), "The continuous main route boards the real rocket and saves completion")
	await _b(true)
	_check(stage.room_index == 2 and deaths == 0 and progress.has_scroll("tower", "spring_alcove"), "The optional spring-room scroll rejoins the main route")
	for test_case in [[_x, 2, "crystal_cavern"], [_y, 3, "crumbling_cavern"], [_z, 5, "bumper_cavern"]]:
		await test_case[0].call()
		release()
		_check(deaths == 0 and stage.room_index == test_case[1] and progress.has_scroll("tower", test_case[2]), "Each detour secures its scroll and physically returns: " + test_case[2])
		print("TOWER_DETOUR_ROUTE ", test_case[2], " deaths=", deaths)
	_check(progress.get_count("tower") == 4, "All four real scroll routes save exactly four collectibles")
	for sound in root.get_node("GameAudio").get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
			sound.stream = null
	# Let the dummy audio driver release stopped playbacks before quitting.
	OS.delay_msec(120)
	current_scene = null
	stage.queue_free()
	await tick(3)
	print("STAGE_2_ROUTE_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func tick(count := 1) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func pos() -> Vector2:
	return player.position - origin


func release() -> void:
	for input in ["move_left", "move_right", "move_up", "move_down", "jump", "dash", "wall_grab"]:
		Input.action_release(input)


func action(input: String) -> void:
	Input.action_press(input)


func pulse(input: String) -> void:
	Input.action_press(input)
	await tick()
	Input.action_release(input)


func enter(index: int, spawn: Vector2) -> void:
	release()
	origin = TowerLandscape.origin(index)
	# Main rooms continue from the preceding room's actual transfer.
	if stage.room_index != index:
		stage._enter_room(index, spawn)
	deaths = 0
	await tick(8)


func steer(x: float) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	var difference := x - pos().x
	if absf(difference) > 3:
		Input.action_press("move_right" if difference > 0 else "move_left", minf(absf(difference) / 45, 1))


func flight_to(x: float, y: float, limit := 160) -> bool:
	for frame in limit:
		if not player.is_dashing():
			steer(x)
		await tick()
		if deaths > 0:
			break
		if player.is_on_floor() and absf(pos().y - y) < 4:
			_check(true, "The real flight lands on its intended platform")
			return true
	_check(false, "Flight missed its platform: " + str(Vector2(x, y)))
	return false


func dash(direction: Vector2) -> void:
	for input in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(input)
	if direction.x != 0:
		action("move_right" if direction.x > 0 else "move_left")
	if direction.y < 0:
		action("move_up")
	await pulse("dash")


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("TOWER_ROUTE: " + message)


func _a() -> void:
	await enter(0, Vector2(100, 614))
	Input.action_press("move_right");Input.action_press("move_up");Input.action_press("wall_grab");Input.action_press("jump")
	var dashed=false
	for f in 600:
		if stage.room_index!=0:break
		if f==24:Input.action_release("jump")
		if pos().x>650 and not dashed:
			dashed=true
			await dash(Vector2.RIGHT)
			Input.action_press("move_up")
		await tick()


func _b(collect := false) -> void:
	await enter(1, Vector2(260, 714))
	Input.action_press("move_right");Input.action_press("move_up");Input.action_press("wall_grab")
	Input.action_press("jump");await tick(24);Input.action_release("jump")
	var kicked=false
	var launched=false
	for f in 600:
		if stage.room_index!=1:break
		if not kicked and player.is_on_wall() and pos().y<610:
			kicked=true
			Input.action_press("jump"); await tick(12);Input.action_release("jump")
			await dash(Vector2(1,-1));await tick(10)
		if player.velocity.y < -1400:
			launched=true
		if launched:
			for i in 100:
				Input.action_release("move_left");Input.action_press("move_right")
				await tick()
				if pos().x>=1170 and pos().y<194:break
			await dash(Vector2.LEFT);await tick(10)
			release()
			for i in 100:
				var diff=940-pos().x
				Input.action_release("move_left");Input.action_release("move_right")
				if absf(diff)>4:Input.action_press("move_right" if diff>0 else "move_left",minf(absf(diff)/40.0,1.0))
				await tick()
				if player.is_on_floor() and pos().y<210:break
			release();await tick(5)
			if collect:
				for i in 60:
					steer(900)
					await tick()
					if absf(pos().x - 900) < 4: break
				release()
				await tick(20)
			Input.action_press("jump");await tick(8);Input.action_press("move_right");await tick(24);Input.action_release("jump");await tick(10)
			Input.action_press("move_up");Input.action_press("wall_grab")
			for i in 100:
				await tick()
				if player.is_on_floor() and pos().x>1120 and pos().y<130:break
			release();await tick(4)
			Input.action_press("jump")
			for i in 60:
				await tick()
				if stage.room_index!=1:break
			break
		await tick()


func _c() -> void:
	await enter(2, Vector2(350, 834))
	Input.action_press("move_right");Input.action_press("move_up");Input.action_press("wall_grab")
	var jumped=false
	var recovered=false
	for f in 700:
		if stage.room_index!=2:break
		if not recovered and pos().x>600 and pos().y<408:
			recovered=true
			Input.action_press("jump");await tick(12);Input.action_release("jump");await dash(Vector2(1,-1));await tick(10);jumped=true
		if not jumped and pos().x>580 and pos().y<520 and player.is_on_floor():
			jumped=true
			Input.action_press("jump");await tick(8)
			await dash(Vector2(1,-1));await tick(16);Input.action_release("jump")
		if pos().x>920:
			Input.action_release("wall_grab");Input.action_release("move_up")
		await tick()


func _d() -> void:
	await enter(3, Vector2(110, 1294))
	for i in 30:
		steer(180);await tick()
		if absf(pos().x-180)<4:break
	release();await tick(5)
	action("move_right");action("jump");await tick(20)
	action("move_up");await pulse("dash");await tick(10);action("wall_grab")
	await flight_to(520,1074)
	release()
	action("move_right");action("jump");await tick(20)
	action("move_up");await pulse("dash");await tick(10);action("wall_grab")
	await flight_to(800,874)
	release()
	action("move_right");action("jump");await tick(20)
	action("move_up");await pulse("dash");await tick(10);action("wall_grab")
	await flight_to(1190,594)
	release()
	action("move_right");action("jump");await tick(20)
	await pulse("dash");await tick(10);action("move_up");action("wall_grab")
	for i in 260:
		await tick()
		if deaths>0:break
		if player.is_on_wall() and pos().y<180:break
	release();action("move_left");action("jump")
	for i in 150:
		await tick()
		if player.is_on_floor() and pos().y<180:break
	release()
	action("jump")
	await tick(40)


func _e() -> void:
	await enter(4, Vector2(300, 914))
	action("move_right");action("wall_grab");action("move_up")
	for i in 200:
		await tick()
		if pos().x>=720:break
	release();await tick(8)
	steer(780)
	for i in 70:
		steer(780);await tick()
		if absf(pos().x-780)<3 and absf(player.velocity.x)<20:break
	release();await tick(8)
	action("move_right");action("jump")
	await tick(20)
	await pulse("dash")
	for i in 150:
		if not player.is_dashing():steer(1260)
		await tick()
		if deaths>0:break
		if player.is_on_floor() and pos().x>1180:break
	release();await tick(12)
	for i in 60:
		steer(1300);await tick()
		if absf(pos().x-1300)<3:break
	release();await tick(6)
	action("move_right");action("jump")
	await tick(20)
	action("move_up")
	await pulse("dash")
	await tick(10)
	action("wall_grab");action("move_up")
	for i in 180:
		await tick()
		if deaths>0:break
		if player.is_on_floor() and pos().x>1750:break
	action("move_right")
	for frame in 120:
		await tick()
		if stage.room_index == 5: break


func _f() -> void:
	await enter(5, Vector2(110, 814))
	action("move_right")
	await tick(17)
	action("jump")
	await tick(20)
	await pulse("dash")
	for i in 140:
		if not player.is_dashing():steer(540)
		await tick()
		if player.velocity.y < -1000:break
	release();action("move_right")
	await tick(38)
	await pulse("dash")
	await tick(10)
	action("wall_grab");action("move_up")
	for i in 200:
		if not player.is_dashing():steer(1240)
		await tick()
		if player.velocity.y < -1400:break
		if deaths>0:break
	release();action("move_right")
	await tick(48)
	action("move_up")
	await pulse("dash")
	await tick(11)
	action("wall_grab")
	for i in 180:
		await tick()
		if player.is_on_floor() and pos().y<300 and pos().x>1740:break
	release();await tick(15)
	if player.is_on_floor() and pos().y<300:
		for i in 120:
			steer(2240);await tick()
			if absf(pos().x-2240)<4:break
		release();await tick(5)
		action("jump");await tick(20);action("move_up");await pulse("dash")
		for i in 160:
			await tick()
			if stage.room_index==6:break


func _g() -> void:
	await enter(6, Vector2(280, 634))
	action("move_right")
	for frame in 220:
		await tick()
		if stage.phase == stage.Phase.WALK: break
	release()
	for frame in 260:
		await tick()
		if stage.phase == stage.Phase.CLEAR: break
	_check(stage.completed and stage.phase == stage.Phase.CLEAR, "The real final walk reaches the three-layer clear screen")


func _x() -> void:
	await enter(7, Vector2(1390, 714))
	var crystals=stage.rooms.get_child(7).get_children().filter(func(o):return o.get_script()==preload("res://scripts/refill_crystal.gd"))
	action("move_left")
	await tick(27)
	action("jump")
	await tick(18)
	action("move_up")
	await pulse("dash")
	await tick(12)
	Input.action_release("move_up")
	for i in 80:
		if not crystals[1]._available or deaths>0:break
		await tick()
	await tick(28)
	action("move_up")
	await pulse("dash")
	await tick(10)
	Input.action_release("move_up")
	for i in 90:
		if not crystals[0]._available or deaths>0:break
		await tick()
	await tick(12)
	action("move_up")
	await pulse("dash")
	await tick(10)
	action("wall_grab")
	for i in 120:
		if not player.is_dashing():steer(180)
		await tick()
		if deaths>0:break
		if player.is_on_floor() and pos().x<250 and absf(pos().y-404)<4:break
	release();await tick(15)
	action("jump");await tick(24);Input.action_release("jump")
	await tick(65)
	action("move_right");action("jump")
	await tick(24)
	action("move_up");await pulse("dash");await tick(12);Input.action_release("move_up")
	for i in 90:
		if not crystals[0]._available or deaths>0:break
		await tick()
	await tick(12)
	action("move_up");await pulse("dash");await tick(12);Input.action_release("move_up")
	for i in 90:
		if not crystals[1]._available or deaths>0:break
		await tick()
	await pulse("dash")
	for i in 150:
		await tick()
		if stage.room_index==2 or deaths>0:break


func _y() -> void:
	await enter(8, Vector2(120, 714))
	for i in 40:
		steer(200);await tick()
		if absf(pos().x-200)<4:break
	release();await tick(5)
	action("move_right");action("jump")
	await flight_to(430,714)
	release()
	action("move_right");action("jump");await tick(20)
	action("move_up");await pulse("dash");await tick(10);action("wall_grab")
	await flight_to(1000,714)
	release()
	action("move_right");action("jump");action("move_up");action("wall_grab")
	for i in 130:
		await tick()
		if deaths>0:break
		if player.is_on_wall() and pos().y<480:break
	release();action("move_right");action("jump")
	await tick(8)
	Input.action_release("move_right");action("move_up")
	await pulse("dash");await tick(10)
	var crystal=stage.rooms.get_child(8).get_children().filter(func(o):return o.get_script()==preload("res://scripts/refill_crystal.gd"))[0]
	for i in 80:
		steer(1000);await tick()
		if not crystal._available or deaths>0:break
	release();action("move_right");await pulse("dash");await tick(10)
	action("wall_grab");action("move_up")
	for i in 200:
		await tick()
		if deaths>0:break
		if player.is_on_floor() and pos().x>1380:break
	release();await tick(15)
	for i in 60:
		steer(1460);await tick()
		if absf(pos().x-1460)<4:break
	release();await tick(20)
	action("move_left")
	for i in 60:
		await tick()
		if pos().x<1360:break
	await pulse("dash");await tick(10)
	await flight_to(1000,714)
	for i in 30:
		steer(940);await tick()
		if absf(pos().x-940)<4:break
	release()
	action("move_left");action("jump");await tick(20)
	action("move_up");await pulse("dash");await tick(10);action("wall_grab")
	await flight_to(430,714)
	release();action("move_left");action("jump")
	await flight_to(140,714)
	release();action("move_left")
	for i in 90:
		await tick()
		if stage.room_index==3 or deaths>0:break


func _z() -> void:
	await enter(9, Vector2(140, 274))
	var launches=[0]
	stage.rooms.get_child(9).get_node("Bumper").launched.connect(func(_body):launches[0]+=1)
	for i in 30:
		steer(180);await tick()
		if absf(pos().x-180)<4:break
	release();await tick(5)
	action("move_right");action("jump");await tick(20);await pulse("dash")
	await flight_to(560,444)
	release();action("move_right");action("jump");action("wall_grab");action("move_up")
	for i in 240:
		await tick()
		if deaths>0:break
		if player.is_on_floor() and pos().x>900 and pos().y<300:break
	release();await tick(8)
	for i in 150:
		steer(1370);await tick()
		if launches[0]>0 or deaths>0:break
	release();action("move_right")
	await tick(30)
	await pulse("dash")
	await flight_to(1920,404)
	release();await tick(15)
	for i in 100:
		steer(1970);await tick()
		if absf(pos().x-1970)<4:break
	release();await tick(20)
	for i in 100:
		steer(1780);await tick()
		if absf(pos().x-1780)<4:break
	release()
	action("move_left");action("jump");await tick(20);await pulse("dash");await tick(10)
	for i in 150:
		if not player.is_dashing():steer(1348)
		await tick()
		if launches[0]>1 or deaths>0:break
	release();action("move_left");action("wall_grab");action("move_up")
	for i in 190:
		await tick()
		if deaths>0:break
		if player.is_on_floor() and pos().y<300:break
	release()
	for i in 100:
		steer(930);await tick()
		if absf(pos().x-930)<4:break
	release()
	action("move_left");action("jump");await tick(20);await pulse("dash")
	await flight_to(580,444)
	release();action("move_left");action("jump");await tick(20);action("move_up");await pulse("dash");await tick(10);action("wall_grab")
	await flight_to(140,274)
	release();action("move_left")
	for i in 100:
		await tick()
		if stage.room_index==5 or deaths>0:break
	_check(launches[0] == 2, "The detour uses the actual bumper for both outbound and return flights")
