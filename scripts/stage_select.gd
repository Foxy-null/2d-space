extends Control


func _ready() -> void:
	var first_stage: Button = $Margin/Content/Stages/Stage1
	var launcher: Button = InputSettings.launcher
	$ReturnTitle.focus_neighbor_left = $ReturnTitle.get_path_to(launcher)
	launcher.focus_neighbor_right = launcher.get_path_to($ReturnTitle)
	launcher.focus_neighbor_top = launcher.get_path_to($Margin/Content/Preview)
	launcher.focus_neighbor_bottom = launcher.get_path_to(first_stage)
	$ReturnTitle.focus_next = $ReturnTitle.get_path_to(launcher)
	launcher.focus_previous = launcher.get_path_to($ReturnTitle)
	launcher.focus_next = launcher.get_path_to(first_stage)
	first_stage.focus_previous = first_stage.get_path_to(launcher)
	first_stage.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_return_to_title()


func _return_to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


func _start_tutorial() -> void:
	get_tree().change_scene_to_file("res://scenes/tutorial.tscn")


func _start_stage_two() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_2.tscn")


func _preview_environments() -> void:
	get_tree().change_scene_to_file("res://scenes/environment_preview.tscn")


func _start_stage_three() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_3.tscn")


func _start_stage_four() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_4.tscn")


func _start_stage_five() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_5.tscn")
