extends Node

signal mode_changed(label: String)

var save_path := "user://display_settings.cfg"
var available := not Engine.is_embedded_in_editor() and DisplayServer.get_name() != "headless"
var windowed_size := Vector2i(1280, 720)
var save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not available:
		return
	windowed_size = get_window().size
	load_settings()
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = 0.3
	save_timer.timeout.connect(save_settings)
	add_child(save_timer)
	get_window().size_changed.connect(_on_size_changed)
	get_window().close_requested.connect(save_settings)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event.keycode == KEY_F11 or event.physical_keycode == KEY_F11):
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo:
			toggle_fullscreen()


func bind_button(button: Button) -> void:
	button.text = _button_text()
	button.disabled = not available
	if not available:
		button.tooltip_text = "埋め込み実行では、GodotのGame画面で表示サイズを変更してください。"
	button.pressed.connect(toggle_fullscreen)
	mode_changed.connect(button.set_text)


func _button_text() -> String:
	return "ウィンドウ表示 [F11]" if is_fullscreen() else "全画面 [F11]"


func is_fullscreen() -> bool:
	return get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]


func toggle_fullscreen() -> void:
	if not available:
		return
	if is_fullscreen():
		_restore_window()
	else:
		if get_window().mode == Window.MODE_WINDOWED:
			windowed_size = get_window().size
		get_window().mode = Window.MODE_FULLSCREEN
	mode_changed.emit(_button_text())
	save_settings()


func _restore_window() -> void:
	var window := get_window()
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	windowed_size = windowed_size.min(usable.size)
	if window.mode != Window.MODE_WINDOWED:
		window.mode = Window.MODE_WINDOWED
	window.size = windowed_size
	window.position = usable.position + (usable.size - windowed_size) / 2


func _on_size_changed() -> void:
	mode_changed.emit(_button_text())
	save_timer.start()


func save_settings() -> Error:
	if not available or get_window().mode == Window.MODE_MINIMIZED:
		return OK
	if get_window().mode == Window.MODE_WINDOWED:
		windowed_size = get_window().size
	var config := ConfigFile.new()
	config.set_value("display", "windowed_size", windowed_size)
	config.set_value("display", "fullscreen", is_fullscreen())
	var result := config.save(save_path)
	if result != OK:
		push_warning("表示設定を保存できませんでした。今回の起動中のみ適用されます。")
	return result


func load_settings() -> void:
	if not available:
		return
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	var saved_size = config.get_value("display", "windowed_size", windowed_size)
	if saved_size is Vector2i and saved_size.x > 0 and saved_size.y > 0:
		windowed_size = saved_size
	_restore_window()
	var fullscreen = config.get_value("display", "fullscreen", false)
	if fullscreen is bool and fullscreen:
		get_window().mode = Window.MODE_FULLSCREEN
	mode_changed.emit(_button_text())
