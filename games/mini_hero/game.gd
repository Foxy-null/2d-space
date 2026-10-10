extends Control

const Battle = preload("res://games/mini_hero/battle.gd")
var battle = Battle.new()
var main: VBoxContainer
var party_box: VBoxContainer
var enemy_box: HBoxContainer
var status_label: Label
var target_label: Label
var resource_label: Label
var log_view: RichTextLabel
var attack_button: Button
var next_button: Button
var action_buttons: Array[Button] = []
var popup: Control
var popup_content: VBoxContainer
var popup_title: Label
var popup_scroll: ScrollContainer
var close_button: Button
var party_cards: Array[Control] = []
var enemy_cards: Array[Control] = []
var awaiting_start := true
var chosen_difficulty := "normal"

class Portrait:
	extends Control
	var kind := "slime"
	func _draw() -> void:
		var colors = {"slime": "#629cec", "ghost": "#ed9b5b", "golem": "#a2a6b4", "crystal": "#86cbe1", "bat": "#b694d7", "mushroom": "#d880bc", "wolf": "#a9b9ce", "mimic": "#d4a75c", "warlock": "#b28dcf", "dragon": "#75b99b"}
		var color = Color(colors.get(kind.replace("boss_", ""), "#cfa760"))
		var middle = size / 2
		if kind in ["golem", "mimic", "boss_mimic"]:
			draw_style_box(_body(color), Rect2(middle - Vector2(25, 20), Vector2(50, 40)))
		else:
			draw_circle(middle + Vector2(0, 3), 22, color)
			if kind in ["ghost", "crystal", "mushroom"] or kind.contains("dragon"):
				draw_colored_polygon(PackedVector2Array([middle + Vector2(-22, 0), middle + Vector2(0, -25), middle + Vector2(22, 0)]), color)
		draw_circle(middle + Vector2(-8, -1), 4, Color("#1b2330"))
		draw_circle(middle + Vector2(8, -1), 4, Color("#1b2330"))
		draw_line(middle + Vector2(-6, 11), middle + Vector2(6, 11), Color("#1b2330"), 2)
	func _body(color: Color) -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(6)
		return style


func _ready() -> void:
	_build()
	battle.start()
	_render()
	_show_start()


func _style(background: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _label(parent: Node, text: String, size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, callback: Callable, node_name: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.clip_text = true
	button.tooltip_text = text
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not node_name.is_empty():
		button.name = node_name
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _panel(parent: Node, width: int = 0) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return box


func _build() -> void:
	var skin := Theme.new()
	skin.default_font_size = 17
	skin.set_stylebox("panel", "PanelContainer", _style(Color("#11131b"), Color("#747780")))
	skin.set_stylebox("normal", "Button", _style(Color("#1b202b"), Color("#9b9fa9")))
	skin.set_stylebox("hover", "Button", _style(Color("#2b3543"), Color("#efd59b")))
	skin.set_stylebox("pressed", "Button", _style(Color("#39445a"), Color("#efd59b")))
	skin.set_stylebox("disabled", "Button", _style(Color("#15171d"), Color("#444852")))
	skin.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), Color("#75d4ee")))
	skin.set_color("font_disabled_color", "Button", Color("#777c87"))
	skin.set_stylebox("background", "ProgressBar", _style(Color("#252937"), Color("#404553"), 4))
	skin.set_stylebox("fill", "ProgressBar", _style(Color("#6abf8b"), Color("#6abf8b"), 4))
	theme = skin
	var background := ColorRect.new()
	background.color = Color("#080b12")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	add_child(margin)
	main = VBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	margin.add_child(main)
	var header := HBoxContainer.new()
	main.add_child(header)
	var title = _label(header, "ミニ勇者バトル", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var badge = _label(header, "開発版", 18)
	badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	var return_button = _button(header, "ゲーム選択へ戻る", _return_to_games, "ReturnToGames")
	return_button.custom_minimum_size.x = 200
	return_button.size_flags_horizontal = Control.SIZE_FILL
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	main.add_child(body)
	var left = _panel(body, 270)
	left.size_flags_horizontal = Control.SIZE_FILL
	_label(left, "パーティ", 22)
	party_box = VBoxContainer.new()
	party_box.add_theme_constant_override("separation", 10)
	left.add_child(party_box)
	_label(left, "味方を選ぶと回復・装備・スキルの対象が変わります。", 15)
	var center = _panel(body, 530)
	center.add_theme_constant_override("separation", 6)
	status_label = _label(center, "", 20)
	enemy_box = HBoxContainer.new()
	enemy_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_box.add_theme_constant_override("separation", 8)
	center.add_child(enemy_box)
	target_label = _label(center, "", 16)
	var commands := GridContainer.new()
	commands.columns = 2
	commands.add_theme_constant_override("h_separation", 8)
	commands.add_theme_constant_override("v_separation", 8)
	center.add_child(commands)
	attack_button = _button(commands, "攻撃", _act.bind("attack", ""), "Attack")
	action_buttons.append(attack_button)
	action_buttons.append(_button(commands, "技", _show_skills, "Skills"))
	action_buttons.append(_button(commands, "魔法", _show_magic, "Magic"))
	action_buttons.append(_button(commands, "防御", _act.bind("guard", ""), "Guard"))
	action_buttons.append(_button(commands, "道具", _show_items, "Items"))
	_button(commands, "メニュー", _show_menu, "Menu")
	next_button = _button(center, "次の階層", _next_wave, "NextWave")
	_label(center, "敵の実行・報酬・成長・所持品操作は仮処理です。", 14)
	var right = _panel(body, 310)
	_label(right, "冒険ログ", 22)
	resource_label = _label(right, "", 14)
	log_view = RichTextLabel.new()
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_view.scroll_following = true
	log_view.add_theme_font_size_override("normal_font_size", 16)
	right.add_child(log_view)
	_button(right, "開発用補給（仮）", _supply, "DeveloperSupply")
	_button(right, "最初から", _show_start, "Restart")
	popup = Control.new()
	popup.name = "Popup"
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(popup)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(dim)
	var center_popup := CenterContainer.new()
	center_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(center_popup)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 570)
	center_popup.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	popup_title = _label(top, "", 24)
	popup_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = _button(top, "閉じる", _dismiss_popup, "ClosePopup")
	close_button.custom_minimum_size.x = 96
	close_button.size_flags_horizontal = Control.SIZE_FILL
	popup_scroll = ScrollContainer.new()
	popup_scroll.custom_minimum_size.y = 460
	popup_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(popup_scroll)
	popup_content = VBoxContainer.new()
	popup_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_content.add_theme_constant_override("separation", 10)
	popup_scroll.add_child(popup_content)
	popup.hide()


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _bar(parent: Node, text: String, value: float, maximum: float, color: Color) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	_label(row, "%s %d / %d" % [text, maxf(0, value), maximum], 14).custom_minimum_size.x = 102
	var bar := ProgressBar.new()
	bar.max_value = maximum
	bar.value = maxf(0, value)
	bar.show_percentage = false
	bar.custom_minimum_size.y = 12
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("fill", _style(color, color, 4))
	row.add_child(bar)


func _render() -> void:
	_clear(party_box)
	_clear(enemy_box)
	party_cards.clear()
	enemy_cards.clear()
	for i in range(battle.party.size()):
		var member = battle.party[i]
		var card := PanelContainer.new()
		var color = Color("#efd59b") if i == battle.active else (Color("#75d4ee") if i == battle.sel_ally else Color("#555b68"))
		card.add_theme_stylebox_override("panel", _style(Color("#151923"), color))
		party_box.add_child(card)
		party_cards.append(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		card.add_child(box)
		var name_text = "%s Lv.%d%s" % [member.name, member.level, "  行動中" if i == battle.active and battle.phase == "party" else ""]
		_button(box, name_text, _select_ally.bind(i), "Ally%d" % i)
		_bar(box, "HP", member.hp, member.maxHp, Color("#6abf8b"))
		_bar(box, "MP", member.mp, member.maxMp, Color("#6c9feb"))
		_bar(box, "LIMIT", member.limit, 100, Color("#e2b769"))
		_label(box, "攻 %d　守 %d　SP %d%s%s" % [member.attack, member.defense, member.sp, "　防御" if member.guarding else "", "　毒" if member.poison else ""], 14)
	for i in range(battle.enemies.size()):
		var enemy = battle.enemies[i]
		var card := PanelContainer.new()
		card.custom_minimum_size.x = 150
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _style(Color("#1c1720"), Color("#efd59b") if i == battle.sel_enemy else Color("#645763")))
		enemy_box.add_child(card)
		enemy_cards.append(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		card.add_child(box)
		_label(box, "BOSS" if enemy.isBoss else "ENEMY", 14)
		var target_button = _button(box, enemy.base + "\nLv.%d" % battle.wave, _select_enemy.bind(i), "Enemy%d" % i)
		target_button.disabled = enemy.hp <= 0
		var portrait := Portrait.new()
		portrait.kind = enemy.type
		portrait.custom_minimum_size = Vector2(60, 48)
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(portrait)
		_bar(box, "HP", enemy.hp, enemy.maxHp, Color("#e68c94"))
		_label(box, "弱点：%s\n耐性：%s" % [battle.data.ename.get(enemy.weak, "なし"), battle.data.ename.get(enemy.resist, "なし")], 15)
		var preview = _label(box, "予告\n" + (enemy.intent.label if enemy.hp > 0 else "撃破"), 16)
		preview.add_theme_color_override("font_color", Color("#efd59b") if enemy.intent.warn else Color("#b4cae7"))
	status_label.text = "第%d階層  /  %s  /  ターン%d" % [battle.wave, battle.data.diffs[battle.difficulty].label, battle.turn]
	if battle.phase == "won":
		status_label.text += "  勝利！"
	elif battle.phase == "lost":
		status_label.text += "  全滅"
	target_label.text = "敵の対象：%s　　味方の対象：%s" % [battle.enemies[battle.sel_enemy].base, battle.party[battle.sel_ally].name]
	for button in action_buttons:
		button.disabled = battle.phase != "party"
	next_button.disabled = battle.phase != "won"
	resource_label.text = _cost_text(battle.materials)
	log_view.clear()
	log_view.add_text("\n".join(battle.messages))
	if popup.visible:
		_main_focus(main, false)


func _select_ally(index: int) -> void:
	battle.sel_ally = index
	_render()


func _select_enemy(index: int) -> void:
	battle.sel_enemy = index
	_render()


func _act(command: String, id: String) -> void:
	var before_party = battle.party.map(func(m): return m.hp)
	var before_enemies = battle.enemies.map(func(e): return e.hp)
	if not battle.perform(command, id):
		_render()
		return
	_close_popup()
	_render()
	_show_changes.call_deferred(before_party, before_enemies)
	if not attack_button.disabled:
		attack_button.grab_focus()


func _show_changes(before_party: Array, before_enemies: Array) -> void:
	for i in range(party_cards.size()):
		_float(party_cards[i], battle.party[i].hp - before_party[i])
	for i in range(enemy_cards.size()):
		_float(enemy_cards[i], battle.enemies[i].hp - before_enemies[i])


func _float(card: Control, amount: float) -> void:
	if is_zero_approx(amount):
		return
	var text := Label.new()
	text.text = "%+d" % amount
	text.add_theme_font_size_override("font_size", 30)
	text.modulate = Color("#91e5b2") if amount > 0 else Color("#ffabb2")
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(text)
	text.position = card.get_global_rect().get_center() - Vector2(22, 10)
	var tween = text.create_tween().set_parallel(true)
	tween.tween_property(text, "position:y", text.position.y - 40, 0.65)
	tween.tween_property(text, "modulate:a", 0.0, 0.65)
	tween.chain().tween_callback(text.queue_free)


func _main_focus(node: Node, enabled: bool) -> void:
	if node is Button:
		node.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	for child in node.get_children():
		_main_focus(child, enabled)


func _open_popup(title: String) -> void:
	_clear(popup_content)
	popup_title.text = title
	popup_scroll.scroll_vertical = 0
	popup.show()
	_main_focus(main, false)


func _focus_popup() -> void:
	for child in popup_content.find_children("*", "Button", true, false):
		if not child.disabled:
			child.grab_focus.call_deferred()
			return
	close_button.grab_focus.call_deferred()


func _close_popup() -> void:
	popup.hide()
	_main_focus(main, true)
	if not attack_button.disabled:
		attack_button.grab_focus.call_deferred()


func _dismiss_popup() -> void:
	if awaiting_start:
		_return_to_games()
	else:
		_close_popup()


func _show_start() -> void:
	awaiting_start = true
	_open_popup("ミニ勇者バトル  /  開発版")
	_label(popup_content, "受領した4.htmlの処理を移植した開発版です。\n不足部分は仮処理で補い、冒険を試せるようにしています。", 20)
	var difficulties := GridContainer.new()
	difficulties.columns = 2
	popup_content.add_child(difficulties)
	for key in ["easy", "normal", "hard", "hell"]:
		var button = _button(difficulties, battle.data.diffs[key].label, _choose_difficulty.bind(key), key)
		button.toggle_mode = true
		button.button_pressed = key == chosen_difficulty
		button.set_meta("difficulty", key)
	_label(popup_content, "選択中：%s\n敵HP・攻撃・報酬倍率は原資料の定義を使用します。\n未受領の技は一覧に残し、使用できる技を明示します。" % battle.data.diffs[chosen_difficulty].label, 18).name = "DifficultyDescription"
	_button(popup_content, "冒険を始める", _begin, "StartAdventure")
	_focus_popup()


func _choose_difficulty(key: String) -> void:
	chosen_difficulty = key
	for button in popup_content.find_children("*", "Button", true, false):
		if button.has_meta("difficulty"):
			button.button_pressed = button.get_meta("difficulty") == key
	popup_content.get_node("DifficultyDescription").text = "選択中：%s\n敵HP・攻撃・報酬倍率は原資料の定義を使用します。" % battle.data.diffs[key].label


func _begin() -> void:
	battle.start(chosen_difficulty)
	awaiting_start = false
	_close_popup()
	_render()
	attack_button.grab_focus.call_deferred()


func _show_skills() -> void:
	_open_popup("%sの技" % battle.actor().name)
	_label(popup_content, "MP %d / %d  ・  行動する仲間の技を選択" % [battle.actor().mp, battle.actor().maxMp])
	var grid := GridContainer.new()
	grid.columns = 2
	popup_content.add_child(grid)
	for skill in battle.data.skills[battle.actor().role]:
		var supported = skill.id in Battle.AVAILABLE_SKILLS
		var suffix = "（末尾を仮補完）" if skill.id == "frostPrison" else ("" if supported else "（効果処理未受領）")
		var cost = battle.mp_cost(battle.actor(), skill.mp)
		var button = _button(grid, "%s%s\nLv.%d / MP %d\n%s" % [skill.name, suffix, skill.lv, cost, skill.desc], _act.bind("skill", skill.id), skill.id)
		button.disabled = not supported or battle.actor().level < skill.lv or battle.actor().mp < cost or battle.phase != "party"
	_focus_popup()


func _show_magic() -> void:
	_open_popup("%sの魔法" % battle.actor().name)
	for entry in [["fire", "火球：単体炎", 3], ["spark", "雷：敵全体", 6], ["heal", "回復：選択した味方", 4]]:
		var cost = battle.mp_cost(battle.actor(), entry[2])
		_button(popup_content, "%s  /  MP %d" % [entry[1], cost], _act.bind(entry[0], ""), entry[0]).disabled = battle.actor().mp < cost or battle.phase != "party"
	_focus_popup()


func _show_items() -> void:
	_open_popup("道具  /  対象：%s" % battle.party[battle.sel_ally].name)
	_label(popup_content, "使用効果は仮実装です。選択した味方に使用します。", 16)
	for id in battle.data.itemNames:
		var supported = id in ["herb", "hiHerb", "manaWater", "panacea", "reviveStone"]
		var valid_target = battle.party[battle.sel_ally].hp <= 0 if id == "reviveStone" else battle.party[battle.sel_ally].hp > 0
		var button = _button(popup_content, "%s ×%d%s" % [battle.data.itemNames[id], battle.items.get(id, 0), "（仮効果）" if supported else "（効果処理未受領）"], _act.bind("item", id), id)
		button.disabled = not supported or not valid_target or battle.items.get(id, 0) <= 0 or battle.phase != "party"
	_focus_popup()


func _show_menu() -> void:
	_open_popup("メニュー")
	_button(popup_content, "装備", _show_equipment, "Equipment")
	_button(popup_content, "スキルツリー", _show_talents, "Talents")
	_button(popup_content, "クラフト", _show_craft, "Craft")
	_button(popup_content, "開発状況・未受領の機能", _show_status, "DevelopmentStatus")
	_focus_popup()


func _cost_text(cost: Dictionary) -> String:
	var entries: Array[String] = []
	for key in cost:
		entries.append("%s %d" % [battle.data.mat.get(key, key), cost[key]])
	return " / ".join(entries)


func _equipment_text(definition: Dictionary) -> String:
	var names = {"attack": "攻撃", "defense": "防御", "maxHp": "HP上限", "maxMp": "MP上限", "fireBoost": "炎強化", "iceBoost": "氷強化", "thunderBoost": "雷強化", "windBoost": "風強化", "holyBoost": "聖強化", "healBoost": "回復強化", "dropBoost": "ドロップ", "mpCostDown": "MP軽減", "fireAttack": "炎化", "breathResist": "ブレス軽減"}
	var entries: Array[String] = []
	for key in definition.stats:
		entries.append("%s+%d" % [names.get(key, key), definition.stats[key]])
	for key in definition.effects:
		entries.append("%s %s" % [names.get(key, key), str(definition.effects[key]) if key == "mpCostDown" else "%d%%" % roundi(definition.effects[key] * 100)])
	return " / ".join(entries)


func _show_equipment() -> void:
	var member = battle.party[battle.sel_ally]
	_open_popup("装備  /  %s" % member.name)
	_label(popup_content, "攻撃 %d / 防御 %d　　装備交換は仮処理です。" % [member.attack, member.defense])
	for slot in ["weapon", "armor", "accessory"]:
		var definition = battle.equipment_def(member.equip.get(slot, ""))
		_label(popup_content, "%s：%s" % [{"weapon": "武器", "armor": "防具", "accessory": "装飾"}[slot], definition.get("name", "なし")], 16)
	var grid := GridContainer.new()
	grid.columns = 2
	popup_content.add_child(grid)
	for id in battle.inventory:
		var definition = battle.equipment_def(id)
		if not definition.jobs.has(member.role):
			continue
		var owner = ""
		for other in battle.party:
			if other.equip.values().has(id):
				owner = other.name
		var button = _button(grid, "%s [%s]%s\n%s" % [definition.name, definition.rarity, "  " + owner + "が装備中" if not owner.is_empty() else "", _equipment_text(definition)], _equip.bind(id), "Equip_" + id)
		button.disabled = not owner.is_empty()
	_focus_popup()


func _equip(id: String) -> void:
	battle.equip(battle.sel_ally, id)
	_render()
	_show_equipment()


func _show_talents() -> void:
	var member = battle.party[battle.sel_ally]
	_open_popup("スキルツリー  /  %s  /  SP %d" % [member.name, member.sp])
	_label(popup_content, "習得条件・消費SP・能力上昇は原資料。SP獲得は仮処理。\n対応する技が未受領の強化も表示し、後から実装できるように残しています。", 16)
	var grid := GridContainer.new()
	grid.columns = 2
	popup_content.add_child(grid)
	for talent in battle.data.talentDefs[member.role]:
		var learned = member.talents.has(talent.id)
		var button = _button(grid, "%s / %s  SP %d%s\n%s" % [talent.branch, talent.name, talent.cost, "  習得済み" if learned else "", talent.desc], _learn.bind(talent.id), talent.id)
		button.disabled = not battle.can_learn(battle.sel_ally, talent)
	_focus_popup()


func _learn(id: String) -> void:
	battle.learn(battle.sel_ally, id)
	_render()
	_show_talents()


func _show_craft() -> void:
	_open_popup("クラフト")
	_label(popup_content, "素材消費と製作数は原資料。製作操作・所持品管理は仮処理。\n" + _cost_text(battle.materials), 16)
	var grid := GridContainer.new()
	grid.columns = 2
	popup_content.add_child(grid)
	for is_equipment in [false, true]:
		for recipe in (battle.data.equipRecipes if is_equipment else battle.data.recipes):
			var title = battle.equipment_def(recipe.id).name if is_equipment else recipe.name
			var button = _button(grid, "%s\n%s" % [title, _cost_text(recipe.cost)], _craft.bind(recipe.id, is_equipment), "Craft_" + recipe.id)
			for key in recipe.cost:
				if battle.materials.get(key, 0) < recipe.cost[key]:
					button.disabled = true
	_focus_popup()


func _craft(id: String, is_equipment: bool) -> void:
	battle.craft(id, is_equipment)
	_render()
	_show_craft()


func _show_status() -> void:
	_open_popup("開発状況")
	_label(popup_content, "実装済み：データ定義、戦闘計算、16種類の技効果、基本魔法、装備生成・効果、習得条件。\n\n仮実装：氷牢の終端、開始・ターン進行、敵行動、勝敗、報酬・成長、道具効果、装備交換・製作、開発用補給。\n\nこのGodot版で未実装：メテオ・僧侶9種類の技、LIMIT技、経路・イベント・クエスト・図鑑登録、セーブ・最終クリア。\n\n動作未確認：元HTML全体との一致、未受領の効果処理。一部スキルの強化・装備の効果は対応機能を待ちます。\n\n原資料と対応表：docs/mini-hero-port.md", 20)
	_focus_popup()


func _supply() -> void:
	battle.developer_supply()
	_render()


func _next_wave() -> void:
	battle.next_wave()
	_render()
	attack_button.grab_focus.call_deferred()


func _return_to_games() -> void:
	get_tree().change_scene_to_file("res://scenes/game_select.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("return_to_stage_select"):
		get_viewport().set_input_as_handled()
		if popup.visible:
			_dismiss_popup()
		else:
			_return_to_games()
	elif popup.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_dismiss_popup()
