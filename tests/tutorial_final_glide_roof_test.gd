extends "res://tests/tutorial_final_glide_test.gd"

var trials := 0
var roof_steps := 0
var through_roof := 0


func _run() -> void:
	for wait in [0, 2, 4, 6]:
		await _prepare_roof()
		for frame in 40:
			await _step()
			if respawns > 0 or (player.is_on_wall() and _local().x > 300):
				break
		if respawns == 0:
			_move(Vector2.ZERO)
			await _step(wait)
			await _drop_and_attempt()
		_release()
		_check(not tutorial.cleared.has(15), "The confirmed wall-stop / drop / up-dash / elevated Grab+Jump route cannot press the goal: wait %d" % wait)
		_check(respawns == 1 and _local().distance_to(Vector2(72, 614)) < 4 and player.gravity_direction == 1, "The confirmed route fails safely at the entrance without either gate")
		_check(player.get_held_object() == null and player.is_dash_ready() and room.get_node("Parachute").position.distance_to(Vector2(170, 593.4)) < 4, "Roof failure restores the free parachute and dash at the current checkpoint")
		trials += 1
	# The one-way ceiling removes the old wall stop. Also deliberately stop before it,
	# so failure cannot rely solely on the exact old script running into a spike.
	for stop in [252, 258, 264, 270, 276]:
		for wait in [0, 2, 4, 6]:
			await _prepare_roof()
			for frame in 40:
				await _step()
				if _local().x >= stop or respawns > 0:
					break
			_move(Vector2.ZERO)
			await _step(wait)
			_check(respawns == 0, "The adjusted roof-drop attempt actually reaches its release pose alive")
			if respawns == 0:
				await _drop_and_attempt()
			_release()
			_check(not tutorial.cleared.has(15) and roof_steps == 0, "Adjusted roof-edge drops cannot create an elevated dash-refill platform: x%d wait%d" % [stop, wait])
			trials += 1
	_check(through_roof > 0, "Actual released parachutes fall through the roof instead of being supported by its upper face")
	_release()
	print("TUTORIAL_FINAL_GLIDE_ROOF_%s trials=%d checks=%d roof_steps=%d through_roof=%d" % ["FAILED" if failed else "OK", trials, checks, roof_steps, through_roof])
	tutorial.queue_free()
	await _step(3)
	quit(1 if failed else 0)


func _prepare_roof() -> void:
	await _new_world()
	room.get_node("Wind").wind_acceleration = 0.0
	_grab(true)
	await _step(3)
	await _walk_to(140)
	_check(player.get_held_object() == room.get_node("Parachute"), "The roof attempt physically carries the actual parachute with wind acceleration zero")
	await _pulse("jump")


func _drop_and_attempt() -> void:
	_grab(false)
	await _step(2)
	var parachute: Grabbable = room.get_node("Parachute")
	var dropped := parachute.position
	var half := (parachute.collider.shape as RectangleShape2D).size * 0.5
	_check(player.get_held_object() == null, "The roof attempt really releases its parachute")
	_move(Vector2.UP)
	await _pulse("dash")
	await _step(10)
	_move(Vector2.ZERO)
	var stepped := false
	var passed := false
	var crossed_roof := false
	for frame in 160:
		if respawns > 0:
			break
		await _step()
		var overlaps_roof := parachute.position.x + half.x > 340 and parachute.position.x - half.x < 1200
		crossed_roof = crossed_roof or (overlaps_roof and parachute.position.y + half.y > 520 and parachute.position.y - half.y < 560)
		passed = passed or (dropped.y + half.y < 520 and crossed_roof and overlaps_roof and parachute.position.y - half.y > 560)
		if player.is_on_floor() and _local().y < 475:
			stepped = true
			roof_steps += 1
			var supported := false
			for index in player.get_slide_collision_count():
				supported = supported or player.get_slide_collision(index).get_collider() == parachute
			_check(supported and player.is_dash_ready(), "Any elevated step must be the actual free parachute and restore dash before testing its shortcut")
			break
	if passed:
		through_roof += 1
	if stepped:
		_grab(true)
		_move(Vector2.RIGHT)
		await _pulse("jump")
		await _step(20)
		_move(Vector2.UP)
		await _pulse("dash")
		_move(Vector2.RIGHT)
		for frame in 600:
			if respawns > 0 or tutorial.cleared.has(15):
				break
			await _step()
