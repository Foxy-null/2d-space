extends SceneTree

var failed := false
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/stage_2.tscn")
	await scene_changed
	if current_scene.has_node("StageIntro"):
		await current_scene.get_node("StageIntro").tree_exited
	await process_frame
	var stage := current_scene
	var backdrop := stage.get_node("Sky/Backdrop")
	var stars: Array = backdrop.stars.duplicate()
	_check(stars.size() == 46, "The sky uses a sparse fixed star field")
	var radii := {}
	var xs := {}
	for star in stars:
		radii[star.z] = true
		xs[star.x] = true
	_check(radii.size() > 35 and xs.size() > 40, "Positions and sizes vary independently rather than repeating a grid")
	stage.player.set_physics_process(false)
	var last := -1.0
	for index in [0, 1, 2, 3, 4, 5, 6]:
		stage._enter_room(index, Vector2(300, 400))
		backdrop._process(0)
		_check(backdrop.sky_progress >= last, "The sky darkens with the actual room altitude")
		last = backdrop.sky_progress
	stage._enter_room(0, Vector2(100, 614))
	backdrop._process(0)
	_check(backdrop.sky_progress < 0.01, "Returning downhill restores the bright low sky")
	_check(backdrop.stars == stars, "Movement does not regenerate or shuffle stars")
	stage.get_node("PauseMenu").open()
	var before: float = backdrop.elapsed
	for frame in 5:
		await process_frame
	_check(backdrop.elapsed == before, "Pausing freezes the background")
	stage.get_node("PauseMenu").resume()
	print("ASCENT_BACKDROP_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error(message)
