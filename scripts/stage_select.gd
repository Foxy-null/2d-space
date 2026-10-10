extends Control


func _ready() -> void:
	$Margin/Content/Stages/Stage1.grab_focus.call_deferred()


func _start_tutorial() -> void:
	get_tree().change_scene_to_file("res://scenes/tutorial.tscn")


func _start_stage_two() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_2.tscn")


func _return_to_games() -> void:
	get_tree().change_scene_to_file("res://scenes/game_select.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("return_to_stage_select"):
		get_viewport().set_input_as_handled()
		_return_to_games()
