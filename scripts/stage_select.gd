extends Control


func _ready() -> void:
	$Margin/Content/Stages/Stage1.grab_focus.call_deferred()


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


func _start_stage_six() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_6.tscn")
