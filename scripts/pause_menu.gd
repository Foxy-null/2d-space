extends CanvasLayer

@onready var stage = get_parent()
@onready var overlay: Control = $Overlay
@onready var menu: VBoxContainer = $Overlay/Center/Panel/Rows/Menu
@onready var confirmation: VBoxContainer = $Overlay/Center/Panel/Rows/Confirmation
var was_paused := false


func _ready() -> void:
	var skip := Button.new()
	skip.name = "SkipCinematic"
	skip.text = "演出をスキップ"
	skip.custom_minimum_size.y = 56
	menu.add_child(skip)
	menu.move_child(skip, 1)
	skip.hide()
	skip.pressed.connect(skip_cinematic)
	var settings := Button.new()
	settings.name = "InputSettings"
	settings.text = "操作設定"
	settings.custom_minimum_size.y = 56
	menu.add_child(settings)
	menu.move_child(settings, 4)
	settings.pressed.connect(InputSettings.open_settings)
	menu.get_node("Hints").visible = stage.has_method("set_hints_visible")
	DisplaySettings.bind_button(menu.get_node("Fullscreen"))
	_refresh_focus()


func _refresh_focus() -> void:
	for container in [menu, confirmation]:
		var buttons: Array = container.get_children().filter(func(child): return child is Button and child.visible and not child.disabled)
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
	was_paused = get_tree().paused
	menu.get_node("SkipCinematic").visible = stage.has_method("can_skip_cinematic") and stage.can_skip_cinematic()
	_refresh_focus()
	overlay.show()
	menu.show()
	confirmation.hide()
	_update_hints_button()
	get_tree().paused = true
	menu.get_node("Resume").grab_focus()


func resume() -> void:
	overlay.hide()
	get_viewport().gui_release_focus()
	get_tree().paused = was_paused


func toggle_hints() -> void:
	stage.set_hints_visible(not stage.hints_visible)
	_update_hints_button()


func _update_hints_button() -> void:
	if menu.get_node("Hints").visible:
		menu.get_node("Hints").text = "ヒントを隠す" if stage.hints_visible else "ヒントを表示"


func retry() -> void:
	resume()
	get_tree().paused = false
	stage.get_node("Player").respawn()


func skip_cinematic() -> void:
	if stage.has_method("can_skip_cinematic") and stage.can_skip_cinematic():
		resume()
		stage.skip_cinematic()


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
