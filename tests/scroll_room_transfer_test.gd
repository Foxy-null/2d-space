extends SceneTree

var failed := false
var checks := 0
var progress: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	progress = root.get_node("CollectionProgress")
	progress.save_path = "user://scroll_room_transfer_test_%d.cfg" % OS.get_process_id()
	progress._collected.clear()
	for scene in ["stage_3", "stage_4", "stage_5"]:
		await _transfer(scene, false)
		await _transfer(scene, true)
	for scene in ["stage_3"]:
		await _backtrack(scene)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("SCROLL_ROOM_TRANSFER_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)


func _transfer(scene: String, retry: bool) -> void:
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	await _step(4)
	var stage := current_scene
	var player: PlayerController = stage.player
	var id := scene + ("_retry" if retry else "_transfer")
	var scroll := _pickup(stage, player, id)
	await _step(3)
	_check(scroll._follower == player and not progress.has_scroll("gravity", id), scene + ": actual overlap starts a pending follower")
	if scene in ["tutorial", "stage_3"]:
		stage.call("_transition_to", 1)
	else:
		stage.call("_transition_to_next")
	_check(stage.transitioning and not player.controls_enabled and scroll._follower == player, scene + ": normal scene transition preserves the pending follower")
	_check(player.gravity_direction == 1 and player.is_dash_ready() and not player.room_transfer_in_progress, scene + ": transfer retains the normal resource reset")
	if retry:
		stage.get_node("PauseMenu").retry()
		_check(scroll._follower == null and not progress.has_scroll("gravity", id), scene + ": pause retry during the transition cancels the pending follower")
	await _step(80)
	_check(not stage.transitioning and player.controls_enabled, scene + ": controls resume normally")
	_check(not progress.has_scroll("gravity", id) if retry else progress.has_scroll("gravity", id), scene + ": only a normal transfer secures the scroll after the next safe landing")


func _backtrack(scene: String) -> void:
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	await _step(4)
	var stage := current_scene
	stage.call("_on_arrival", 0)
	await _step(2)
	stage.call("_transition_to", 1)
	await _step(25)
	var player: PlayerController = stage.player
	var id := scene + "_backtrack"
	var scroll := _pickup(stage, player, id)
	await _step(3)
	stage.call("_transition_to", 0)
	_check(scroll._follower == player and stage.transitioning, scene + ": leftward room transfer also preserves the follower")
	await _step(80)
	_check(stage.room_index == 0, scene + ": backtracking reaches the preceding room after its transition")
	_check(progress.has_scroll("gravity", id), scene + ": the right-side return entrance secures the carried scroll")


func _pickup(stage: Node, player: PlayerController, id: String) -> Area2D:
	var scroll: Area2D = load("res://scenes/scroll_collectible.tscn").instantiate()
	scroll.stage_id = "gravity"
	scroll.scroll_id = id
	scroll.position = player.position
	stage.add_child(scroll)
	return scroll


func _step(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error(message)
