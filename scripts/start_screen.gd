extends Control


func _ready() -> void:
	$Center/Content/Start.grab_focus.call_deferred()


func _start() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")
