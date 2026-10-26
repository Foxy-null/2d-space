extends SceneTree

var checks := 0
var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var progress = root.get_node("CollectionProgress")
	var fixture := OS.get_environment("TOWER_FOURTH_FIXTURE")
	_check(not fixture.is_empty(),"Reload uses the preceding real-input process's dedicated save")
	if failed:
		quit(1)
		return
	progress.save_path = fixture
	progress._collected.clear()
	progress.load_progress()
	_check(progress.get_count("tower")==2 and progress.TOTALS.tower==8,"A separate process reloads both new collected scrolls out of eight")
	for id in ["reflection_left_07","updraft_return_08"]:
		_check(progress.has_scroll("tower",id),"The actual saved identity survives: "+id)
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(5)
	var card: Button=current_scene.get_node("Margin/Content/Stages/Stage2")
	_check(card.get_node("Content/Collection/Count").text=="2 / 8","Selection displays the real separate-process saved count")
	_check(card.accessibility_name.contains("巻物 2 / 8"),"Selection announces the same real count")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await process_frame
		RenderingServer.force_draw()
		DirAccess.make_dir_recursive_absolute("res://docs/screenshots/tower-fourth")
		_check(root.get_texture().get_image().save_png("res://docs/screenshots/tower-fourth/stage_selection_2.png")==OK,"The actual saved selection is captured natively")
	change_scene_to_file("res://scenes/stage_2.tscn")
	await _step(6)
	_check(current_scene.checkpoints.get_child_count()==34,"The separate process opens all thirty-four native sections")
	for name in ["FourthReflectionScroll","FourthUpdraftScroll"]:
		var scroll=current_scene.get_node("ScrollBranch/"+name)
		_check(scroll._secured and scroll._follower==null and scroll.modulate.a<1,"A saved native scroll remains a faint revisitable marker")
	current_scene.queue_free()
	await _step(5)
	progress._collected.clear()
	for path in [fixture,fixture+".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("TOWER_FOURTH_RELOAD_TEST_OK checks=",checks)
	quit(1 if failed else 0)

func _step(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failed=true
		push_error(message)
