extends Label
## Shared completion notice. The stage owns completion and retry state.

var card: PanelContainer
var return_button: Button


func _ready() -> void:
	# Keep the existing completion label available to stage scripts.
	add_theme_color_override("font_color", Color.TRANSPARENT)
	add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	card = PanelContainer.new()
	card.position = Vector2(960, 112)
	card.size = Vector2(296, 104)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14243bf5")
	style.border_color = Color("8ef0bd")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style)
	layer.add_child(card)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	card.add_child(rows)
	var title := Label.new()
	title.text = "ステージクリア！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("a2ffd0"))
	rows.add_child(title)
	return_button = Button.new()
	return_button.name = "ReturnToStageSelect"
	return_button.focus_mode = Control.FOCUS_NONE
	return_button.text = "選択へ戻る [Enter / Y・△]"
	return_button.custom_minimum_size.y = 44
	return_button.add_theme_font_size_override("font_size", 17)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("244f65")
	button_style.border_color = Color("80cde8")
	button_style.set_border_width_all(2)
	button_style.set_corner_radius_all(6)
	return_button.add_theme_stylebox_override("normal", button_style)
	var hover_style := button_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color("326d86")
	return_button.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := button_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color("16384d")
	return_button.add_theme_stylebox_override("pressed", pressed_style)
	return_button.pressed.connect(_return_to_select)
	rows.add_child(return_button)
	visibility_changed.connect(_sync_visibility)
	_sync_visibility()


func _sync_visibility() -> void:
	if not is_instance_valid(card):
		return
	card.visible = is_visible_in_tree()
	if card.visible:
		GameAudio.play_clear()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or event.is_echo():
		return
	# Space and A/× remain jump inputs for practice after completion.
	if event is InputEventKey and event.pressed and (event.keycode in [KEY_ENTER, KEY_KP_ENTER] or event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]):
		get_viewport().set_input_as_handled()
		_return_to_select()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y:
		get_viewport().set_input_as_handled()
		_return_to_select()


func _return_to_select() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")
