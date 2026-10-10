extends Control


func _ready() -> void:
	# ステージ選択を起動せず、既存のテーマだけ共有する。
	var action_menu = preload("res://scenes/stage_select.tscn").instantiate()
	theme = action_menu.theme
	action_menu.free()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 64)
	add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	margin.add_child(content)
	var title := Label.new()
	title.text = "ゲーム選択"
	title.add_theme_font_size_override("font_size", 42)
	content.add_child(title)
	var description := Label.new()
	description.text = "遊びたいゲームを選んでください。"
	content.add_child(description)
	var games := HBoxContainer.new()
	games.name = "Games"
	games.size_flags_vertical = Control.SIZE_EXPAND_FILL
	games.add_theme_constant_override("separation", 24)
	content.add_child(games)
	for entry in [
		["ActionGame", "忍者ぶっとびくん Galaxy\n\n重力反転と壁キック\nステージ1・2", "res://scenes/stage_select.tscn"],
		["MiniHero", "ミニ勇者バトル\n\nコマンド式RPG・開発版\n戦闘 / 装備 / スキル", "res://games/mini_hero/game.tscn"]]:
		var button := Button.new()
		button.name = entry[0]
		button.text = entry[1]
		button.custom_minimum_size = Vector2(420, 260)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_start.bind(entry[2]))
		games.add_child(button)
	var controls := Label.new()
	controls.text = "選択：方向キー / 十字キー / スティック　決定：Enter / A・×　クリックでも選べます"
	content.add_child(controls)
	games.get_child(0).grab_focus.call_deferred()


func _start(path: String) -> void:
	get_tree().change_scene_to_file(path)
