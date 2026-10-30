extends CanvasLayer

signal mode_changed(enabled: bool)
signal warning_shown
signal warning_dismissed
signal timed_out_to_title

const THEME := preload("res://assets/ui/menu-theme.tres")
const DEFAULT_IDLE_TIMEOUT := 30.0
const DEFAULT_WARNING_DURATION := 20.0
const GAMEPLAY_ACTIONS := [
	"move_left",
	"move_right",
	"move_up",
	"move_down",
	"jump",
	"jump_up",
	"dash",
	"wall_grab",
	"reset",
	"pause_game",
]

var enabled := false
var idle_timeout := DEFAULT_IDLE_TIMEOUT
var warning_duration := DEFAULT_WARNING_DURATION
var idle_elapsed := 0.0
var warning_active := false
var warning_remaining := DEFAULT_WARNING_DURATION

var overlay: Control
var panel: PanelContainer
var title_label: Label
var message_label: Label
var hint_label: Label
var continue_button: Button
var previous_focus: Control
var was_paused := false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _build_ui() -> void:
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.theme = THEME
	overlay.hide()
	add_child(overlay)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(640, 320)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.08, 0.14, 0.98)
	style.border_color = Color(1.0, 0.84, 0.38, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.content_margin_left = 36.0
	style.content_margin_right = 36.0
	style.content_margin_top = 32.0
	style.content_margin_bottom = 32.0
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "Rows"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "まだ操作していますか？"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 1.0))
	vbox.add_child(title_label)

	message_label = Label.new()
	message_label.name = "Message"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 24)
	message_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
	vbox.add_child(message_label)

	hint_label = Label.new()
	hint_label.name = "Hint"
	hint_label.text = "何かボタンを押すか操作すると、そのまま続けられます"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.add_theme_color_override("font_color", Color(0.68, 0.82, 0.95, 1.0))
	vbox.add_child(hint_label)

	continue_button = Button.new()
	continue_button.name = "Continue"
	continue_button.text = "プレイを続ける"
	continue_button.custom_minimum_size = Vector2(280, 56)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.pressed.connect(record_activity)
	vbox.add_child(continue_button)
	_update_warning_text()


func bind_button(button: Button) -> void:
	_apply_button_state(button)
	if not button.pressed.is_connected(toggle):
		button.pressed.connect(toggle)
	mode_changed.connect(func(_is_enabled: bool):
		if is_instance_valid(button):
			_apply_button_state(button)
	)


func _apply_button_state(button: Button) -> void:
	button.text = _button_text()
	button.accessibility_name = button.text
	if enabled:
		button.add_theme_color_override("font_color", Color("a2ffd0"))
		button.add_theme_color_override("font_focus_color", Color("a2ffd0"))
		button.add_theme_color_override("font_hover_color", Color("c4ffe2"))
	else:
		button.remove_theme_color_override("font_color")
		button.remove_theme_color_override("font_focus_color")
		button.remove_theme_color_override("font_hover_color")


func _button_text() -> String:
	return "体験モード: ON" if enabled else "体験モード: OFF"


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	idle_elapsed = 0.0
	warning_remaining = warning_duration
	if warning_active:
		_hide_warning()
	mode_changed.emit(enabled)


func toggle() -> void:
	set_enabled(not enabled)


func record_activity() -> void:
	idle_elapsed = 0.0
	warning_remaining = warning_duration
	if warning_active:
		_hide_warning()


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if _is_activity_event(event):
		var was_warning := warning_active
		record_activity()
		if was_warning:
			get_viewport().set_input_as_handled()


func _is_activity_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventMouseMotion:
		return warning_active or not event.relative.is_zero_approx()
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) > 0.25
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventAction:
		return event.pressed
	return false


func _has_held_input() -> bool:
	for action in GAMEPLAY_ACTIONS:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			return true
	return false


func _should_track_idle() -> bool:
	if not enabled:
		return false
	var scene := get_tree().current_scene
	if scene == null:
		return false
	if scene.scene_file_path == "res://scenes/start_screen.tscn":
		var settings := get_node_or_null("/root/InputSettings")
		var settings_open: bool = settings != null and settings.panel != null and settings.panel.visible
		var dialog_open: bool = "_new_game_dialog" in scene and scene._new_game_dialog != null and scene._new_game_dialog.visible
		return settings_open or dialog_open
	return true


func _process(delta: float) -> void:
	if not _should_track_idle():
		idle_elapsed = 0.0
		if warning_active:
			_hide_warning()
		return
	if not warning_active:
		if _has_held_input():
			idle_elapsed = 0.0
			return
		idle_elapsed += delta
		if idle_elapsed >= idle_timeout:
			_show_warning()
	else:
		warning_remaining = maxf(0.0, warning_remaining - delta)
		_update_warning_text()
		if warning_remaining <= 0.0:
			_timeout_to_title()


func _show_warning() -> void:
	warning_active = true
	warning_remaining = warning_duration
	previous_focus = get_viewport().gui_get_focus_owner()
	was_paused = get_tree().paused
	get_tree().paused = true
	_update_warning_text()
	overlay.show()
	continue_button.grab_focus.call_deferred()
	warning_shown.emit()


func _hide_warning() -> void:
	if not warning_active:
		return
	warning_active = false
	warning_remaining = warning_duration
	overlay.hide()
	get_tree().paused = was_paused
	if is_instance_valid(previous_focus) and previous_focus.is_inside_tree():
		previous_focus.grab_focus.call_deferred()
	warning_dismissed.emit()


func _update_warning_text() -> void:
	if message_label != null:
		var seconds := maxi(1, ceili(warning_remaining))
		message_label.text = "操作がない状態が続いています。\nあと %d 秒でタイトル画面に戻ります。" % seconds


func _timeout_to_title() -> void:
	warning_active = false
	idle_elapsed = 0.0
	warning_remaining = warning_duration
	overlay.hide()
	for action in GAMEPLAY_ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)
	var settings := get_node_or_null("/root/InputSettings")
	if settings != null and settings.panel != null and settings.panel.visible:
		settings.close_settings()
	Engine.time_scale = 1.0
	get_tree().paused = false
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path == "res://scenes/start_screen.tscn":
		if "_new_game_dialog" in scene and scene._new_game_dialog != null and scene._new_game_dialog.visible:
			scene._new_game_dialog.hide()
	else:
		get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
	timed_out_to_title.emit()
