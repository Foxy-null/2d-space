extends CanvasLayer
## Independent of stage contents. Only gameplay actions are persisted.
const SAVE_PATH := "user://input_settings.cfg"
var save_path := SAVE_PATH
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "jump", "jump_up", "dash", "wall_grab", "reset", "toggle_stage_hints", "return_to_stage_select"]
const LABELS := ["左へ", "右へ", "上へ / 登る", "下へ / 降りる", "ジャンプ", "上入力ジャンプ", "ダッシュ", "つかむ / 持つ", "やり直し", "ヒント表示", "ステージ選択へ"]
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
	var first := _button("キーボード", tabs, func(): keyboard = true; _refresh())
	_button("コントローラー", tabs, func(): keyboard = false; _refresh())
	_label("Esc: 入力待ちをキャンセル / 閉じる   F10: 設定を開く・閉じる（予約キー）", body)
	status = _label("キー欄を選んでキーを押してください。同じキーを複数の操作に設定できます。" if keyboard else "ボタンごとに操作を選択。左スティック・トリガーは初期操作のまま使えます。", body)
	if waiting_action != "":
		status.text = "入力待ち：%s — キーを押してください / Escでキャンセル" % LABELS[ACTIONS.find(waiting_action)]
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
				var text := keys[slot].as_text_physical_keycode() if slot < keys.size() else "未設定"
				var button := _button(text, grid, _wait.bind(action, slot))
				button.disabled = waiting_action != ""
				button.tooltip_text = "クリックで変更 / 右クリックで解除"
				button.gui_input.connect(_key_cell_input.bind(action, slot))
	else:
		for index in PAD_NAMES.size():
			_label(PAD_NAMES[index], grid).custom_minimum_size.x = 390
			var choice := OptionButton.new()
			choice.add_item("未設定")
			for label in LABELS:
				choice.add_item(label)
			for i in ACTIONS.size():
				for event in InputMap.action_get_events(ACTIONS[i]):
					if event is InputEventJoypadButton and event.button_index == index:
						choice.select(i + 1)
			grid.add_child(choice)
			choice.item_selected.connect(_assign_pad.bind(index))
	_label("変更は自動保存されます。ゲーム内の操作説明は初期配置の表記です。", body)
	var footer := HBoxContainer.new()
	body.add_child(footer)
	_button("このタブを初期設定に戻す", footer, reset_current_device)
	_button("閉じる", footer, close_settings)
	if panel.visible and waiting_action == "":
		_focus_if_present.call_deferred(first)

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

func keyboard_events(action: String) -> Array[InputEventKey]:
	var keys: Array[InputEventKey] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			keys.append(event)
	return keys

func set_keyboard_binding(action: String, slot: int, event: InputEventKey) -> void:
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

func reset_current_device() -> void:
	waiting_action = ""
	for action in ACTIONS:
		for event in InputMap.action_get_events(action):
			if (event is InputEventKey) == keyboard:
				InputMap.action_erase_event(action, event)
		for event in defaults[action]:
			if (event is InputEventKey) == keyboard:
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
		var events = config.get_value("bindings", action, null)
		if not events is Array:
			continue
		var valid := true
		for event in events:
			if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
				valid = false
		if valid:
			InputMap.action_erase_events(action)
			for event in events:
				InputMap.action_add_event(action, event)
