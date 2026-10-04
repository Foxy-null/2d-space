extends Control


func _ready() -> void:
	$Margin/Content/Stages/Stage1.grab_focus.call_deferred()


func _start_tutorial() -> void:
	get_tree().change_scene_to_file("res://scenes/tutorial.tscn")


func _start_stage_two() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_two.tscn")
