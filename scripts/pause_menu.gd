extends CanvasLayer

@onready var stage = get_parent()
@onready var overlay: Control = $Overlay
@onready var menu: VBoxContainer = $Overlay/Center/Panel/Rows/Menu
@onready var confirmation: VBoxContainer = $Overlay/Center/Panel/Rows/Confirmation


func _ready() -> void:
	menu.get_node("Hints").visible = stage.has_method("set_hints_visible")
	for container in [menu, confirmation]:
		var buttons: Array = container.get_children().filter(func(child): return child is Button and child.visible)
		for index in buttons.size():
			var button: Button = buttons[index]
			button.focus_neighbor_top = button.get_path_to(buttons[index - 1])
			button.focus_neighbor_bottom = button.get_path_to(buttons[(index + 1) % buttons.size()])
			button.focus_previous = button.focus_neighbor_top
			button.focus_next = button.focus_neighbor_bottom
			button.focus_neighbor_left = NodePath(".")
			button.focus_neighbor_right = NodePath(".")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		var settings = get_node_or_null("/root/InputSettings")
		if settings != null and settings.panel.visible:
			return
		get_viewport().set_input_as_handled()
		if event.is_echo():
			return
		if not overlay.visible:
			open()
		elif confirmation.visible:
			cancel_return()
		else:
			resume()


func open() -> void:
	overlay.show()
	menu.show()
	confirmation.hide()
	_update_hints_button()
	get_tree().paused = true
	menu.get_node("Resume").grab_focus()


func resume() -> void:
	overlay.hide()
	get_viewport().gui_release_focus()
	get_tree().paused = false


func toggle_hints() -> void:
	stage.set_hints_visible(not stage.hints_visible)
	_update_hints_button()


func _update_hints_button() -> void:
	if menu.get_node("Hints").visible:
		menu.get_node("Hints").text = "ヒントを隠す" if stage.hints_visible else "ヒントを表示"


func retry() -> void:
	resume()
	stage.get_node("Player").respawn()


func confirm_return() -> void:
	menu.hide()
	confirmation.show()
	confirmation.get_node("Cancel").grab_focus()


func cancel_return() -> void:
	confirmation.hide()
	menu.show()
	menu.get_node("Return").grab_focus()


func return_to_select() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")


func _exit_tree() -> void:
	if overlay.visible:
		get_tree().paused = false
