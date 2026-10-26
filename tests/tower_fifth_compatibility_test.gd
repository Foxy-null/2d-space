extends SceneTree

const LEGACY_IDS := ["left_balcony_01","spring_turn_02","wind_rest_03","left_return_04","upper_wall_05","wind_glide_06","reflection_left_07","updraft_return_08"]
var checks:=0
var failed:=false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var progress=root.get_node("CollectionProgress")
	var fixture:=OS.get_environment("TOWER_FIFTH_FIXTURE")
	_check(not fixture.is_empty(),"Compatibility uses a dedicated save passed to both separate processes")
	if failed:
		quit(1)
		return
	progress.save_path=fixture
	progress._collected.clear()
	if not OS.get_cmdline_user_args().has("--reload"):
		# An old-format serialized fixture checks save compatibility; this is not a claim of physical pickups.
		var config:=ConfigFile.new()
		config.set_value("tower","scrolls",LEGACY_IDS)
		_check(config.save(fixture)==OK,"Write all eight original identities in the unchanged serialized format")
	progress.load_progress()
	_check(progress.get_count("tower")==8 and progress.TOTALS.tower==8,"The actual old eight-scroll save loads without changing its denominator")
	change_scene_to_file("res://scenes/stage_select.tscn")
	await _step(6)
	var card: Button=current_scene.get_node("Margin/Content/Stages/Stage2")
	_check(card.get_node("Content/Collection/Count").text=="8 / 8" and card.accessibility_name.contains("巻物 8 / 8"),"Selection displays and announces the same saved eight identities")
	change_scene_to_file("res://scenes/stage_2.tscn")
	await _step(6)
	_check(current_scene.checkpoints.get_child_count()==31,"The same saved data opens the thirty-one-section tower")
	var ids: Array[String]=[]
	for scroll in current_scene.get_node("ScrollBranch").get_children():
		if not scroll is Area2D:continue
		_check(LEGACY_IDS.has(scroll.scroll_id) and not ids.has(scroll.scroll_id),"Every old native identity remains unique and unchanged")
		_check(scroll._secured and scroll._follower==null and scroll.modulate.a<1,"Every old saved native scroll remains a faint revisitable marker")
		ids.append(scroll.scroll_id)
	_check(ids.size()==8,"All eight actual old placements are retained")
	current_scene.queue_free()
	await _step(18)
	if OS.get_cmdline_user_args().has("--reload"):
		for path in [fixture,fixture+".tmp"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("TOWER_FIFTH_COMPATIBILITY_TEST_OK checks=",checks," reload=",OS.get_cmdline_user_args().has("--reload"))
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
