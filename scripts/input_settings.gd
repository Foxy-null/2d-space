extends CanvasLayer
## Independent of stage contents. Only gameplay actions are persisted.
const SAVE_PATH := "user://input_settings.cfg"
var save_path := SAVE_PATH
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "jump", "jump_up", "dash", "wall_grab", "reset", "pause_game"]
const LABELS := ["左へ", "右へ", "上へ / 登る", "下へ / 降りる", "ジャンプ", "上入力ジャンプ", "ダッシュ", "つかむ / 持つ", "やり直し", "ポーズメニュー"]
const PAD_NAMES := ["下ボタン (A / ×)", "右ボタン (B / ○)", "左ボタン (X / □)", "上ボタン (Y / △)", "Back / −", "Guide", "Start / +", "左スティック押込", "右スティック押込", "L / LB", "R / RB", "十字キー 上", "十字キー 下", "十字キー 左", "十字キー 右"]
var defaults: Dictionary = {}
var panel: PanelContainer
var body: VBoxContainer
var status: Label
var launcher: Button
var waiting_action := ""
var waiting_slot := 0
var keyboard := true
var was_paused := false
var previous_focus: Control

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in ACTIONS:
		defaults[action] = InputMap.action_get_events(action).duplicate(true)
	load_settings()
	launcher = Button.new()
	launcher.text = "操作設定  [F10]"
	launcher.position = Vector2(1050, 20)
	launcher.size = Vector2(200, 40)
	launcher.pressed.connect(open_settings)
	add_child(launcher)
	panel = PanelContainer.new()
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.055, 0.07, 0.12, 1.0)
	background.border_color = Color(0.3, 0.4, 0.58, 1.0)
	background.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", background)
	panel.position = Vector2(100, 35)
	panel.size = Vector2(1080, 650)
	add_child(panel)
	panel.hide()
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	body = VBoxContainer.new()
	margin.add_child(body)
	_refresh()

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	launcher.visible = not panel.visible and scene != null and scene.scene_file_path == "res://scenes/stage_select.tscn"

func open_settings() -> void:
	if panel.visible:
		return
	previous_focus = get_viewport().gui_get_focus_owner()
	was_paused = get_tree().paused
	get_tree().paused = true
	panel.show()
	launcher.hide()
	_refresh()

func close_settings() -> void:
	waiting_action = ""
	panel.hide()
	get_tree().paused = was_paused
	if is_instance_valid(previous_focus):
		previous_focus.grab_focus()

func _input(event: InputEvent) -> void:
	if panel.visible and waiting_action != "" and event is InputEventMouseButton and event.pressed:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = event.button_index
		set_keyboard_binding(waiting_action, waiting_slot, mouse)
		waiting_action = ""
		_refresh()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and panel.visible:
			if waiting_action != "":
				waiting_action = ""
				_refresh()
			else:
				close_settings()
			get_viewport().set_input_as_handled()
			return
		if waiting_action != "":
			if event.keycode == KEY_F10:
				return
			var key := InputEventKey.new()
			key.physical_keycode = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			set_keyboard_binding(waiting_action, waiting_slot, key)
			waiting_action = ""
			_refresh()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F10:
			if panel.visible:
				close_settings()
			else:
				open_settings()
			get_viewport().set_input_as_handled()
	if panel.visible and waiting_action != "":
		get_viewport().set_input_as_handled()

func _label(text: String, parent: Node) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label

func _button(text: String, parent: Node, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(170, 32)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func _refresh() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	_label("操作設定", body).add_theme_font_size_override("font_size", 28)
	var tabs := HBoxContainer.new()
	body.add_child(tabs)
	var first := _button("キーボード・マウス", tabs, func(): keyboard = true; _refresh())
	_button("コントローラー", tabs, func(): keyboard = false; _refresh())
	_label("Esc: 入力待ちをキャンセル / 閉じる   F10: 設定を開く・閉じる（予約キー）", body)
	status = _label("割り当て欄を選び、キーまたはマウスボタンを押してください。" if keyboard else "ボタンごとに操作を選択。左スティック・トリガーは初期操作のまま使えます。", body)
	if waiting_action != "":
		status.text = "入力待ち：%s — キーまたはマウスボタンを押してください / Escでキャンセル" % LABELS[ACTIONS.find(waiting_action)]
	if keyboard:
		var presets := HBoxContainer.new()
		body.add_child(presets)
		_label("サンプル配置", presets)
		_button("サンプル1（デフォルト）", presets, apply_keyboard_sample.bind(false))
		_button("サンプル2（ダッシュ：右クリック）", presets, apply_keyboard_sample.bind(true))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3 if keyboard else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	if keyboard:
		for heading in ["操作", "キー 1", "キー 2"]:
			_label(heading, grid)
		for i in ACTIONS.size():
			var action: String = ACTIONS[i]
			_label(LABELS[i], grid).custom_minimum_size.x = 300
			var keys := keyboard_events(action)
			for slot in 2:
				var text := _binding_text(keys[slot]) if slot < keys.size() else "未設定"
				var button := _button(text, grid, _wait.bind(action, slot))
				button.disabled = waiting_action != ""
				button.tooltip_text = "クリックで変更 / 右クリックで解除"
				button.gui_input.connect(_key_cell_input.bind(action, slot))
	else:
		body.remove_child(scroll)
		scroll.queue_free()
		_build_controller_layout()
	_label("変更は自動保存されます。ゲーム内の操作説明は初期配置の表記です。", body)
	var footer := HBoxContainer.new()
	body.add_child(footer)
	_button("このタブを初期設定に戻す", footer, reset_current_device)
	_button("閉じる", footer, close_settings)
	if panel.visible and waiting_action == "":
		_focus_if_present.call_deferred(first)

func _build_controller_layout() -> void:
	var diagram := preload("res://scripts/controller_diagram.gd").new()
	diagram.custom_minimum_size = Vector2(1040, 370)
	diagram.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(diagram)
	var left := [9, 4, 5, 7, 11, 13, 12, 14]
	var right := [10, 6, 3, 2, 1, 0, 8]
	for side in 2:
		var indices: Array = left if side == 0 else right
		for row in indices.size():
			var index: int = indices[row]
			var card := HBoxContainer.new()
			card.position = Vector2(0 if side == 0 else 738, row * 44)
			card.size = Vector2(302, 38)
			diagram.add_child(card)
			var name_label := _label(diagram.SHORT_NAMES[index], card)
			name_label.custom_minimum_size = Vector2(100, 38)
			name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			name_label.add_theme_color_override("font_color", Color("65e4e9"))
			name_label.tooltip_text = PAD_NAMES[index]
			var choice := OptionButton.new()
			choice.name = "PadBinding%d" % index
			choice.custom_minimum_size = Vector2(198, 38)
			choice.add_item("未設定")
			for action_label in LABELS:
				choice.add_item(action_label)
			for i in ACTIONS.size():
				for event in InputMap.action_get_events(ACTIONS[i]):
					if event is InputEventJoypadButton and event.button_index == index:
						choice.select(i + 1)
			card.add_child(choice)
			choice.item_selected.connect(_assign_pad.bind(index))
			choice.focus_entered.connect(diagram.highlight.bind(index))
			choice.mouse_entered.connect(diagram.highlight.bind(index))
			diagram.connections.append([Vector2(302 if side == 0 else 738, row * 44 + 19), index])

func _focus_if_present(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and panel.visible:
		control.grab_focus()

func _wait(action: String, slot: int) -> void:
	waiting_action = action
	waiting_slot = slot
	_refresh()

func _key_cell_input(event: InputEvent, action: String, slot: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var keys := keyboard_events(action)
		if slot < keys.size():
			InputMap.action_erase_event(action, keys[slot])
			save_settings()
			_refresh()

func _binding_text(event: InputEvent) -> String:
	if event is InputEventKey:
		return event.as_text_physical_keycode()
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT: return "マウス 左"
			MOUSE_BUTTON_RIGHT: return "マウス 右"
			MOUSE_BUTTON_MIDDLE: return "マウス 中央"
			MOUSE_BUTTON_WHEEL_UP: return "ホイール 上"
			MOUSE_BUTTON_WHEEL_DOWN: return "ホイール 下"
			MOUSE_BUTTON_WHEEL_LEFT: return "ホイール 左"
			MOUSE_BUTTON_WHEEL_RIGHT: return "ホイール 右"
			MOUSE_BUTTON_XBUTTON1: return "マウス サイド 1"
			MOUSE_BUTTON_XBUTTON2: return "マウス サイド 2"
		return "マウス %d" % event.button_index
	return event.as_text()

func keyboard_events(action: String) -> Array[InputEvent]:
	var keys: Array[InputEvent] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			keys.append(event)
	return keys

func set_keyboard_binding(action: String, slot: int, event: InputEvent) -> void:
	var keys := keyboard_events(action)
	if slot < keys.size():
		InputMap.action_erase_event(action, keys[slot])
	InputMap.action_add_event(action, event)
	# Preserve slot order when replacing the first of two keys.
	if slot < keys.size():
		keys[slot] = event
		for key in keyboard_events(action):
			InputMap.action_erase_event(action, key)
		for key in keys:
			InputMap.action_add_event(action, key)
	save_settings()

func _assign_pad(selection: int, index: int) -> void:
	for action in ACTIONS:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and event.button_index == index:
				InputMap.action_erase_event(action, event)
	if selection > 0:
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = index
		InputMap.action_add_event(ACTIONS[selection - 1], event)
	save_settings()

func apply_keyboard_sample(mouse_dash: bool) -> void:
	waiting_action = ""
	for action in ACTIONS:
		for event in keyboard_events(action):
			InputMap.action_erase_event(action, event)
		for event in defaults[action]:
			if event is InputEventKey or event is InputEventMouseButton:
				InputMap.action_add_event(action, event)
	if mouse_dash:
		for event in keyboard_events("dash"):
			InputMap.action_erase_event("dash", event)
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("dash", mouse)
	save_settings()
	_refresh()

func reset_current_device() -> void:
	waiting_action = ""
	for action in ACTIONS:
		for event in InputMap.action_get_events(action):
			if (event is InputEventKey or event is InputEventMouseButton) == keyboard:
				InputMap.action_erase_event(action, event)
		for event in defaults[action]:
			if (event is InputEventKey or event is InputEventMouseButton) == keyboard:
				InputMap.action_add_event(action, event)
	save_settings()
	_refresh()

func save_settings() -> Error:
	var config := ConfigFile.new()
	for action in ACTIONS:
		config.set_value("bindings", action, InputMap.action_get_events(action))
	var result := config.save(save_path)
	if result != OK and is_instance_valid(status):
		status.text = "設定を保存できませんでした。今回の起動中のみ適用されます。"
	return result

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	for action in ACTIONS:
		if not config.has_section_key("bindings", action):
			continue
		var events = config.get_value("bindings", action)
		if not events is Array:
			continue
		var valid := true
		for event in events:
			if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion):
				valid = false
		if valid:
			InputMap.action_erase_events(action)
			for event in events:
				InputMap.action_add_event(action, event)
