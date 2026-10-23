extends "res://tests/tutorial_final_glide_test.gd"

# Ablate the actual wind force, never its telemetry: wind_lift can also mark a jump.
var trials := 0
var superdashes := 0
var furthest := 0.0
const DIRECTIONS := [Vector2.ZERO, Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(1, 1), Vector2.DOWN, Vector2.LEFT, Vector2(-1, -1), Vector2(-1, 1)]


func _run() -> void:
	await _new_world()
	player.movement_action.connect(func(action):
		if action == "superdash":
			superdashes += 1
	)
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or args.has("--basic"):
		await _basic_sweep()
	if args.is_empty() or args.has("--coyote"):
		await _coyote_sweep()
	if args.is_empty() or args.has("--footstool"):
		await _footstool_sweep()
	if args.is_empty() or args.has("--walls"):
		await _wall_sweep()
	_release()
	print("TUTORIAL_FINAL_GLIDE_BYPASS_%s trials=%d checks=%d superdashes=%d furthest=%.2f" % ["FAILED" if failed else "OK", trials, checks, superdashes, furthest])
	tutorial.queue_free()
	await _step(3)
	quit(1 if failed else 0)


func _basic_sweep() -> void:
	for held in [true, false]:
		for launch in [120, 180, 220, 250]:
			for delay in [0, 8, 16, 24, 36, 48]:
				for direction in DIRECTIONS:
					await _setup(held, launch)
					await _pulse("jump")
					await _step(delay)
					if respawns == 0 and not direction.is_zero_approx():
						_move(direction)
						await _pulse("dash")
					await _reject("held=%s launch=%d delay=%d direction=%s" % [held, launch, delay, direction])
			await _ground_dash_sweep(held, launch)
			print("FINAL_BASIC held=%s launch=%d trials=%d" % [held, launch, trials])


func _coyote_sweep() -> void:
	for launch in [270, 286, 300, 312, 318, 324]:
		for delay in [28, 32, 36, 40, 44, 48, 52, 56, 60, 64, 68, 72]:
			for direction in [Vector2.UP, Vector2(1, -1), Vector2.RIGHT]:
				await _setup(true, launch)
				await _pulse("jump")
				await _step(delay)
				if respawns == 0:
					_move(direction)
					await _pulse("dash")
				await _reject("late edge launch=%d delay=%d direction=%s" % [launch, delay, direction])
		await _ground_dash_sweep(true, launch)
		print("FINAL_COYOTE launch=%d trials=%d" % [launch, trials])


func _ground_dash_sweep(held: bool, launch: int) -> void:
	for delay in [0, 2, 4, 6, 8, 10, 12, 16]:
		for direction in [Vector2.RIGHT, Vector2.LEFT]:
			await _setup(held, launch)
			_move(direction)
			await _pulse("dash")
			await _step(delay)
			if respawns == 0:
				await _pulse("jump")
			await _reject("ground Dash / Superdash held=%s launch=%d delay=%d direction=%s" % [held, launch, delay, direction])


func _footstool_sweep() -> void:
	for placed in [false, true]:
		for approach in [false, true]:
			for wait in [4, 8]:
				for delay in [8, 16, 20, 24, 28, 32]:
					for direction in [Vector2.UP, Vector2(1, -1)]:
						await _enter()
						room.get_node("Wind").wind_acceleration = 0.0
						if placed:
							_grab(true)
							await _step(3)
							await _walk_to(200)
							_move(Vector2.ZERO)
							await _step(20)
							_grab(false)
							_move(Vector2.LEFT)
							await _step(18)
							_move(Vector2.ZERO)
							await _step(15)
							var x: float = room.get_node("Parachute").position.x
							_check(player.get_held_object() == null and x >= 200 and x <= 240, "Actually carry and place the parachute near x220 before the footstool attempt")
						_move(Vector2.RIGHT)
						await _pulse("jump")
						for frame in 100:
							await _step()
							if _local().x > room.get_node("Parachute").position.x - 55:
								_move(Vector2.ZERO)
							if player.is_on_floor() and _local().y < 580:
								break
						_check(player.is_on_floor() and _local().y < 580, "Actually stand on the unheld parachute before Grab+Jump")
						if approach:
							_move(Vector2.RIGHT)
							for frame in 50:
								await _step()
								if player.is_on_wall() or respawns > 0:
									break
						_move(Vector2.ZERO)
						_grab(true)
						await _pulse("jump")
						await _step(wait)
						_move(Vector2.RIGHT)
						await _step(delay)
						if respawns == 0:
							_move(direction)
							await _pulse("dash")
						await _reject("parachute footstool placed=%s approach=%s wait=%d delay=%d direction=%s" % [placed, approach, wait, delay, direction])
				print("FINAL_FOOTSTOOL placed=%s approach=%s wait=%d trials=%d" % [placed, approach, wait, trials])


func _wall_sweep() -> void:
	for launch in [250, 270, 286]:
		for dash_delay in [0, 8, 16, 24]:
			for kick in [false, true]:
				await _setup(false, launch)
				_grab(true)
				_move(Vector2(1, -1))
				await _pulse("jump")
				_check(player.get_held_object() == null, "The climbing attempt holds Grab after leaving the parked parachute behind")
				await _step(dash_delay)
				if respawns == 0:
					_move(Vector2(1, -1))
					await _pulse("dash")
				_move(Vector2(1, -1))
				for frame in 120:
					if respawns > 0:
						break
					await _step()
					if kick and player.is_on_wall():
						await _pulse("jump")
				await _reject("bare climbing / wall kick launch=%d delay=%d kick=%s" % [launch, dash_delay, kick])
	print("FINAL_WALLS trials=%d" % trials)


func _setup(held: bool, launch: int) -> void:
	await _enter()
	room.get_node("Wind").wind_acceleration = 0.0 if held else 4000.0
	if held:
		_grab(true)
	else:
		await _park_parachute()
	await _walk_to(launch)


func _reject(label: String) -> void:
	_move(Vector2.RIGHT)
	var reached: bool = tutorial.seen.has("up") or _at_exit() or tutorial.cleared.has(15)
	for frame in 280:
		if reached or respawns > 0:
			break
		await _step()
		furthest = maxf(furthest, _local().x)
		reached = reached or tutorial.seen.has("up") or _at_exit() or tutorial.cleared.has(15)
	trials += 1
	_check(not reached, "No-wind held / no-parachute shortcuts cannot reach even UpGate: " + label)
