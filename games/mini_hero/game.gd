extends Control

const Battle = preload("res://games/mini_hero/battle.gd")
const EMOJI = preload("res://games/mini_hero/fonts/NotoColorEmoji.ttf")
const COLORS = {"yellow":"#facc15","red":"#fca5a5","green":"#86efac","blue":"#93c5fd","purple":"#c4b5fd"}
var battle = Battle.new()
var main: VBoxContainer
var party_box: VBoxContainer
var enemy_box: HBoxContainer
var status_label: Label
var target_label: Label
var boss_label: Label
var result_label: Label
var resource_label: Label
var log_view: RichTextLabel
var route_area: VBoxContainer
var event_area: VBoxContainer
var attack_button: Button
var next_button: Button
var menu_button: Button
var action_buttons: Array[Button] = []
var party_cards: Array[Control] = []
var enemy_cards: Array[Control] = []
var popup: CenterContainer
var popup_panel: PanelContainer
var start_background: TextureRect
var popup_content: VBoxContainer
var popup_scroll: ScrollContainer
var close_button: Button
var banner_label: Label
var wash_layer: ColorRect
var popup_kind := ""
var chosen_difficulty := "normal"
var awaiting_start := true
var banner_tween: Tween


func _ready() -> void:
	_build()
	battle.clock = get_tree()
	battle.changed.connect(_render)
	battle.effect.connect(_effect)
	battle.banner.connect(_banner)
	battle.start()
	_show_start()


func _style(background: Color = Color.BLACK, border: Color = Color.WHITE, width: int = 2, radius: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _label(parent: Node, text: String, size: int = 14) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	if size >= 18:
		label.add_theme_font_override("font", get_theme_font("font", "Button"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, callback: Callable, node_name: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.clip_text = true
	button.tooltip_text = text
	button.custom_minimum_size.y = 36
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not node_name.is_empty():
		button.name = node_name
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _panel(parent: Node, ratio: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)
	return box


func _build() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["monospace", "Yu Gothic"])
	font.fallbacks = [EMOJI]
	var skin := Theme.new()
	skin.default_font = font
	skin.default_font_size = 14
	var bold := SystemFont.new()
	bold.font_names = font.font_names
	bold.font_weight = 700
	bold.fallbacks = [EMOJI]
	skin.set_font("font", "Button", bold)
	skin.set_stylebox("panel", "PanelContainer", _style())
	for state in ["normal", "hover", "pressed", "disabled"]:
		skin.set_stylebox(state, "Button", _style(Color("#222222") if state == "pressed" else Color.BLACK, Color.WHITE, 2, 12))
	skin.set_stylebox("focus", "Button", _style(Color.TRANSPARENT, Color("#facc15"), 2, 12))
	skin.set_color("font_color", "Button", Color.WHITE)
	skin.set_color("font_disabled_color", "Button", Color("#777777"))
	theme = skin
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.name = "GameScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 14)
	scroll.add_child(margin)
	main = VBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	margin.add_child(main)
	var header := PanelContainer.new()
	header.custom_minimum_size.y = 133
	main.add_child(header)
	var head_box := VBoxContainer.new()
	head_box.add_theme_constant_override("separation", 16)
	header.add_child(head_box)
	var head_row := HBoxContainer.new()
	head_box.add_child(head_row)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 170
	head_row.add_child(spacer)
	var title = _label(head_row, "ミニ勇者バトル", 26)
	title.custom_minimum_size.y = 67
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var back = _button(head_row, "ゲーム選択へ戻る", _return_to_games, "ReturnToGames")
	back.size_flags_horizontal = Control.SIZE_FILL
	back.custom_minimum_size.x = 170
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tags := HBoxContainer.new()
	tags.alignment = BoxContainer.ALIGNMENT_CENTER
	tags.add_theme_constant_override("separation", 4)
	head_box.add_child(tags)
	for text in ["全部入り", "クエスト解放", "ランダム装備", "敵予告", "LIMIT選択"]:
		var tag := PanelContainer.new()
		var tag_style = _style(Color.BLACK, Color("#facc15"), 1, 99)
		tag_style.content_margin_left = 7
		tag_style.content_margin_right = 7
		tag_style.content_margin_top = 2
		tag_style.content_margin_bottom = 2
		tag.add_theme_stylebox_override("panel", tag_style)
		tags.add_child(tag)
		var tag_label = _label(tag, text, 13)
		tag_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		tag_label.add_theme_color_override("font_color", Color("#fde68a"))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.custom_minimum_size.y = 565
	main.add_child(body)
	var left = _panel(body, 0.92)
	_label(left, "パーティ", 22)
	party_box = VBoxContainer.new()
	party_box.add_theme_constant_override("separation", 9)
	left.add_child(party_box)
	var center = _panel(body, 1.22)
	status_label = _label(center, "", 14)
	boss_label = _label(center, "", 14)
	boss_label.add_theme_color_override("font_color", Color(COLORS.red))
	enemy_box = HBoxContainer.new()
	enemy_box.add_theme_constant_override("separation", 9)
	center.add_child(enemy_box)
	target_label = _label(center, "", 13)
	route_area = VBoxContainer.new()
	center.add_child(route_area)
	event_area = VBoxContainer.new()
	center.add_child(event_area)
	var commands := GridContainer.new()
	commands.columns = 2
	commands.add_theme_constant_override("h_separation", 6)
	commands.add_theme_constant_override("v_separation", 6)
	center.add_child(commands)
	attack_button = _button(commands, "攻撃", _act.bind("attack", ""), "Attack")
	action_buttons.append(attack_button)
	action_buttons.append(_button(commands, "技", _open_popup.bind("skill"), "Skills"))
	action_buttons.append(_button(commands, "魔法", _open_popup.bind("magic"), "Magic"))
	action_buttons.append(_button(commands, "防御", _act.bind("guard", ""), "Guard"))
	action_buttons.append(_button(commands, "道具", _open_popup.bind("item"), "Items"))
	menu_button = _button(commands, "メニュー", _open_popup.bind("menu"), "Menu")
	next_button = _button(center, "次の階層", _next_wave, "NextWave")
	result_label = _label(center, "", 18)
	result_label.add_theme_color_override("font_color", Color(COLORS.yellow))
	var right = _panel(body, 1)
	_label(right, "ログ", 22)
	resource_label = _label(right, "", 13)
	log_view = RichTextLabel.new()
	log_view.custom_minimum_size.y = 216
	log_view.add_theme_stylebox_override("normal", _style(Color.BLACK, Color.WHITE, 2, 12))
	log_view.scroll_following = true
	log_view.add_theme_font_size_override("normal_font_size", 14)
	right.add_child(log_view)
	_button(right, "最初から", _restart, "Restart").alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_background = TextureRect.new()
	start_background.z_index = 2
	start_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#7c2d12fa"), Color("#050505")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.25)
	texture.fill_to = Vector2(1, 1)
	start_background.texture = texture
	start_background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(start_background)
	popup = CenterContainer.new()
	popup.z_index = 3
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(popup)
	var panel := PanelContainer.new()
	popup_panel = panel
	panel.custom_minimum_size = Vector2(520, 100)
	popup.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	close_button = _button(box, "× 閉じる", _dismiss_popup, "ClosePopup")
	close_button.add_theme_stylebox_override("normal", _style(Color("#330000"), Color("#ff8888"), 2, 12))
	popup_scroll = ScrollContainer.new()
	popup_scroll.custom_minimum_size = Vector2(496, 480)
	popup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(popup_scroll)
	popup_content = VBoxContainer.new()
	popup_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_content.add_theme_constant_override("separation", 6)
	popup_scroll.add_child(popup_content)
	popup.hide()
	wash_layer = ColorRect.new()
	wash_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash_layer.color = Color.TRANSPARENT
	add_child(wash_layer)
	banner_label = _label(self, "", 26)
	banner_label.z_index = 1
	banner_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner_label.offset_top = 100
	banner_label.offset_bottom = 145
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.add_theme_color_override("font_color", Color(COLORS.yellow))
	var banner_style = _style(Color("#451a03ee"), Color(COLORS.yellow))
	banner_style.set_corner_radius_all(18)
	banner_label.add_theme_stylebox_override("normal", banner_style)
	banner_label.offset_left = 180
	banner_label.offset_right = -180
	banner_label.hide()


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _bar(parent: Node, name_text: String, value: float, maximum: float, color: Color) -> void:
	if not name_text.is_empty():
		_label(parent, "%s　%d/%d" % [name_text, maxf(0, value), maximum], 12)
	var bar := ProgressBar.new()
	bar.max_value = maximum
	bar.value = maxf(0, value)
	bar.show_percentage = false
	bar.custom_minimum_size.y = 13
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background = _style(Color("#1c1917"), Color("#78716c"), 1)
	background.content_margin_top = 0
	background.content_margin_bottom = 0
	background.set_corner_radius_all(6)
	var fill = _style(color, color, 0)
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)


func _card_input(event: InputEvent, target: String, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select(target, index)


func _select(target: String, index: int) -> void:
	if battle.busy:
		return
	if target == "ally":
		battle.sel_ally = index
	elif battle.enemies[index].hp > 0:
		battle.sel_enemy = index
	_render()


func _set_text(m: Dictionary) -> String:
	var sets = [["hero","flameSword","ironArmor","炎騎士:攻撃+2"],["hero","thunderSword","crystalArmor","雷光騎士:雷+12%"],["mage","flameStaff","magicRobe","火炎研究:炎+10%"],["mage","iceStaff","magicRobe","氷晶研究:氷+10%"],["mage","stormStaff","sageRobe","嵐の賢者:雷+12%"],["priest","prayerStaff","saintRobe","聖者:回復+10%"],["priest","saintStaff","oracleVestment","神託者:回復+15%"]]
	var found: Array[String] = []
	for entry in sets:
		if m.role == entry[0] and battle.has_equipment(m, entry[1]) and battle.has_equipment(m, entry[2]):
			found.append(entry[3])
	return " / ".join(found)


func _render() -> void:
	_clear(party_box)
	_clear(enemy_box)
	party_cards.clear()
	enemy_cards.clear()
	for i in range(battle.party.size()):
		var m = battle.party[i]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(Color.BLACK, Color.WHITE, 1, 16))
		card.gui_input.connect(_card_input.bind("ally", i))
		party_box.add_child(card)
		party_cards.append(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		card.add_child(box)
		var row := HBoxContainer.new()
		box.add_child(row)
		var choose = _button(row, "%s %s" % [m.emoji, m.name], _select.bind("ally", i), "Ally%d" % i)
		choose.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choose.add_theme_font_size_override("font_size", 19)
		var level_label = _label(row, "Lv.%d" % m.level, 13)
		level_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		choose.disabled = battle.busy
		var name_style = _style(Color.BLACK, Color.BLACK, 0)
		name_style.content_margin_top = 0
		name_style.content_margin_bottom = 0
		name_style.content_margin_left = 0
		name_style.content_margin_right = 0
		choose.custom_minimum_size.y = 0
		for state in ["normal", "disabled", "hover", "pressed"]:
			choose.add_theme_stylebox_override(state, name_style)
		_label(box, "EXP %d/%d / SP %d / 攻撃 %d / 防御 %d%s" % [m.exp, m.nextExp, m.sp, m.attack, m.defense, " / 毒%d" % m.poison if m.poison > 0 else ""], 12)
		_bar(box, "HP", m.hp, m.maxHp, Color("#86efac"))
		_bar(box, "MP", m.mp, m.maxMp, Color("#7dd3fc"))
		_bar(box, "", m.limit, 100, Color("#fde047"))
		var eq: Array[String] = []
		for id in m.equip.values():
			if id != null:
				eq.append(battle.equipment_def(id).name)
		var set_text = _set_text(m)
		_label(box, "装備:%s%s" % ["なし" if eq.is_empty() else " / ".join(eq), " / セット:" + set_text if not set_text.is_empty() else ""], 12)
		_label(box, "防御:%s / LIMIT:%d/100%s" % ["有効" if m.guarding else "なし", m.limit, " / 対象" if i == battle.sel_ally else ""], 12)
		if m.hp <= 0:
			card.modulate.a = 0.42
	for i in range(battle.enemies.size()):
		var e = battle.enemies[i]
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _style(Color("#222222") if i == battle.sel_enemy else Color.BLACK, Color.WHITE, 1, 16))
		card.gui_input.connect(_card_input.bind("enemy", i))
		enemy_box.add_child(card)
		enemy_cards.append(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 5)
		card.add_child(box)
		var choose = _button(box, e.name, _select.bind("enemy", i), "Enemy%d" % i)
		choose.disabled = battle.busy or e.hp <= 0
		choose.custom_minimum_size.y = 0
		choose.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var enemy_name_style = _style(Color.TRANSPARENT, Color.TRANSPARENT, 0)
		for edge in ["left", "right", "top", "bottom"]:
			enemy_name_style.set("content_margin_" + edge, 0)
		for state in ["normal", "disabled", "hover", "pressed"]:
			choose.add_theme_stylebox_override(state, enemy_name_style)
		_bar(box, "HP", e.hp, e.maxHp, Color("#fb7185"))
		_label(box, "攻撃 %d / 防御 %d / %s / 弱点:%s / 耐性:%s" % [e.attack,e.defense,e.note,battle.data.ename.get(e.weak,"-"),battle.data.ename.get(e.resist,"-")], 12)
		if e.hp > 0:
			var intent_panel := PanelContainer.new()
			var warning = e.intent != null and e.intent.warn
			var intent_style = _style(Color("#451a03cc" if warning else "#1e293bcc"), Color("#facc15" if warning else "#93c5fd"), 1, 10)
			intent_style.content_margin_left = 8
			intent_style.content_margin_right = 8
			intent_style.content_margin_top = 6
			intent_style.content_margin_bottom = 6
			intent_panel.add_theme_stylebox_override("panel", intent_style)
			box.add_child(intent_panel)
			var intent = _label(intent_panel, "次の行動：" + (e.intent.label if e.intent != null else "?"), 13)
			intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			intent.add_theme_color_override("font_color", Color(COLORS.yellow if e.intent != null and e.intent.warn else "#bfdbfe"))
		var emoji = _label(box, e.emoji if e.hp > 0 else "💀", 82)
		emoji.add_theme_font_override("font", EMOJI)
		emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if e.hp <= 0:
			card.modulate.a = 0.42
	var acting = battle.actor()
	status_label.text = "洞窟 第%d階層 / 難易度:%s / 道:%s\n%s" % [battle.wave,battle.data.diffs[battle.difficulty].label,battle.route.name,"終了" if battle.phase != "party" else "行動中" if battle.busy else acting.name + "のターン"]
	boss_label.text = "⚠ ボス部屋：危険行動予告に注意" if battle.wave % 5 == 0 else ""
	boss_label.visible = not boss_label.text.is_empty()
	target_label.text = "バトル終了" if battle.phase != "party" else "攻撃対象:%s / 味方対象:%s" % [battle.enemy_target().name,battle.party[battle.sel_ally].name]
	resource_label.text = "素材：" + _cost_text(battle.materials, ":")
	log_view.clear()
	for entry in battle.messages:
		log_view.push_color(Color(COLORS.get(entry.color, "#ffffff")))
		log_view.add_text(entry.text + "\n")
		log_view.pop()
	result_label.text = "勝利！ 次は第%d階層" % (battle.wave + 1) if battle.phase == "won" else "敗北..." if battle.phase == "lost" else ""
	next_button.visible = battle.phase == "won"
	_render_routes()
	_render_event()
	if popup.visible and not awaiting_start:
		_render_popup()
	_locks()


func _locks() -> void:
	for button in action_buttons:
		button.disabled = battle.busy or battle.phase != "party" or popup.visible
	menu_button.disabled = battle.busy or popup.visible
	next_button.disabled = battle.phase != "won" or not battle.preparing or battle.busy or popup.visible or not battle.route_chosen


func _render_routes() -> void:
	_clear(route_area)
	if not battle.preparing or battle.route_chosen:
		if battle.preparing and battle.next_is_boss_floor():
			_label(route_area, "⚠ 次はボス部屋", 16).add_theme_color_override("font_color", Color(COLORS.red))
			_label(route_area, "ボス部屋の前では道を選べません。準備を整えて「次の階層」へ進んでください。", 13)
		return
	_label(route_area, "次の道", 16)
	for id in Battle.ROUTES:
		var r = Battle.ROUTES[id]
		_button(route_area, "%s\n%s" % [r.name,r.desc], _choose_route.bind(id), "Route_" + id)


func _render_event() -> void:
	_clear(event_area)
	match battle.event_kind:
		"starter":
			_label(event_area, "冒険者への支給品", 16)
			_label(event_area, "序盤の方針に合わせて、報酬を1つ選べます。", 13)
			for entry in [["herb","薬草セット","薬草x3"],["mana","魔法セット","魔力水x2"],["sp","成長セット","修練の書x1"],["craft","鍛冶セット","魔鉱石x3"]]:
				_button(event_area, "%s\n%s" % [entry[1],entry[2]], _starter.bind(entry[0]), "Starter_" + entry[0])
		"spring", "treasure", "shrine":
			var text = {"spring":["泉イベント","全員HP回復"],"treasure":["宝箱","開ける"],"shrine":["小さな祠","祈る"]}[battle.event_kind]
			_label(event_area, text[0], 16)
			_button(event_area, text[1], _resolve_event, "ResolveEvent")


func _act(command: String, id: String) -> void:
	_close_popup()
	await battle.perform(command, id)
	if not attack_button.disabled:
		attack_button.grab_focus()


func _restart() -> void:
	_close_popup()
	battle.start(chosen_difficulty)


func _next_wave() -> void:
	battle.next_wave()


func _choose_route(id: String) -> void:
	battle.choose_route(id)


func _starter(id: String) -> void:
	battle.choose_starter_reward(id)


func _resolve_event() -> void:
	battle.resolve_event()


func _open_popup(kind: String) -> void:
	popup_kind = kind
	popup_scroll.scroll_vertical = 0
	popup.show()
	_render_popup()
	_locks()
	_focus_popup()


func _close_popup() -> void:
	popup.hide()
	popup_kind = ""
	_locks()


func _dismiss_popup() -> void:
	if awaiting_start:
		_return_to_games()
	else:
		_close_popup()
		if not attack_button.disabled:
			attack_button.grab_focus()


func _focus_popup() -> void:
	for button in popup_content.find_children("*", "Button", true, false):
		if not button.disabled:
			button.grab_focus.call_deferred()
			return
	close_button.grab_focus.call_deferred()


func _grid(title: String) -> GridContainer:
	if not title.is_empty():
		_label(popup_content, title, 16)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	popup_content.add_child(grid)
	return grid


func _render_popup() -> void:
	_clear(popup_content)
	var a = battle.actor()
	var m = battle.party[battle.sel_ally]
	match popup_kind:
		"menu":
			var grid = _grid("")
			for entry in [["craft","クラフト","Craft"],["equip","装備","Equipment"],["quest","クエスト","Quests"],["talent","スキルツリー","Talents"],["book","図鑑","Book"]]:
				_button(grid, entry[1], _open_popup.bind(entry[0]), entry[2])
		"skill":
			var grid = _grid("技")
			if a.limit >= 100:
				for li in battle.data.limits[a.role]:
					_button(grid, "必殺 %s\n%s" % [li.name,li.desc], _act.bind("limit", li.id), li.id).disabled = battle.busy or battle.phase != "party"
			for sk in battle.data.skills[a.role]:
				var cost = battle.mp_cost(a, sk.mp)
				var b = _button(grid, "%s MP%d\nLv.%d %s" % [sk.name,cost,sk.lv,sk.desc], _act.bind("skill", sk.id), sk.id)
				b.disabled = battle.busy or battle.phase != "party" or a.level < sk.lv or a.mp < cost
		"magic":
			var grid = _grid("魔法")
			for entry in [["fire","火球",3,""],["spark","稲妻",6,"\n全体"],["heal","癒し",4,""]]:
				var cost = battle.mp_cost(a, entry[2])
				_button(grid, "%s MP%d%s" % [entry[1],cost,entry[3]], _act.bind(entry[0], ""), entry[0]).disabled = battle.busy or battle.phase != "party" or a.mp < cost
		"item":
			var grid = _grid("道具")
			var any_item = false
			for id in battle.items:
				if battle.items[id] > 0:
					any_item = true
					_button(grid, "%s x%d" % [battle.data.itemNames[id],battle.items[id]], _act.bind("item", id), id).disabled = battle.busy or battle.phase != "party"
			if not any_item:
				_label(popup_content, "使える道具がありません", 13)
		"craft":
			var grid = _grid("アイテムクラフト")
			for recipe in battle.data.recipes:
				_button(grid, "%s\n%s" % [recipe.name,_cost_text(recipe.cost)], _craft.bind(recipe.id, false), "Craft_" + recipe.id).disabled = not battle.can_craft(recipe) or battle.busy
		"equip":
			_label(popup_content, "装備", 16)
			_label(popup_content, "現在の対象：%s %s\n味方カードをクリックすると装備対象を変更できます。\n各装備に「装備可能」を表示します。" % [m.emoji,m.name], 13)
			var grid = _grid("")
			for slot in ["weapon","armor","accessory"]:
				_button(grid, "%sを外す" % {"weapon":"武器","armor":"防具","accessory":"アクセサリー"}[slot], _unequip.bind(slot), "Unequip_" + slot).disabled = m.equip[slot] == null
			grid = _grid("所持装備")
			var owned = false
			for e in battle.equipment:
				if battle.inventory.get(e.id, 0) <= 0:
					continue
				owned = true
				var can = e.jobs.has(m.role)
				var jobs = e.jobs.map(func(j): return {"hero":"勇者","mage":"魔法使い","priest":"僧侶"}[j])
				var text = "%s[%s] %s x%d\n種類:%s / 装備可能:%s%s\n%s" % ["" if can else "🚫 ",e.rarity,e.name,battle.inventory[e.id],{"weapon":"武器","armor":"防具","accessory":"アクセサリー"}[e.slot]," / ".join(jobs),"" if can else "\n現在選択中の仲間は装備できません",_equipment_text(e)]
				_button(grid, text, _equip.bind(e.id), "Equip_" + e.id).disabled = not can
			if not owned:
				_label(popup_content, "所持装備がありません", 13)
			grid = _grid("装備クラフト")
			for recipe in battle.data.equipRecipes:
				var e = battle.equipment_def(recipe.id)
				var jobs = e.jobs.map(func(j): return {"hero":"勇者","mage":"魔法使い","priest":"僧侶"}[j])
				_button(grid, "%s\n種類:%s / 装備可能:%s\n%s\n完成品にランダム追加効果" % [e.name,{"weapon":"武器","armor":"防具","accessory":"アクセサリー"}[e.slot]," / ".join(jobs),_cost_text(recipe.cost)], _craft.bind(recipe.id, true), "CraftEq_" + recipe.id).disabled = not battle.can_craft(recipe)
		"quest":
			_label(popup_content, "クエスト", 16)
			var categories: Array = []
			for q in battle.unlocked_quests():
				if not categories.has(q.cat):
					categories.append(q.cat)
			for category in categories:
				var grid = _grid("◆ " + category)
				for q in battle.unlocked_quests():
					if q.cat != category:
						continue
					var done = battle.quests.get(q.id, false)
					var now = battle.quest_progress(q)
					var text = "%s%s\n%d/%d 報酬:%s" % ["✅ " if done else "⭐ " if now >= q.goal else "□ ",q.name,mini(now,q.goal),q.goal,"ランダム報酬" if q.has("randomReward") else q.reward]
					_button(grid, text, _quest.bind(q.id), "Quest_" + q.id).disabled = done or now < q.goal
		"book":
			_label(popup_content, "敵図鑑", 16)
			if battle.bestiary.is_empty():
				_label(popup_content, "まだ記録なし", 13)
			for r in battle.bestiary.values():
				_label(popup_content, "%s 討伐:%d\n弱点:%s / 耐性:%s / 種別:%s" % [r.name,r.kills,battle.data.ename.get(r.weak,"-"),battle.data.ename.get(r.resist,"-"),r.drops], 13)
		"talent":
			_label(popup_content, "スキルツリー：%s %s\n所持SP：%d / 味方カードをクリックして対象変更" % [m.emoji,m.name,m.sp], 16)
			var branches: Array = []
			for t in battle.data.talentDefs[m.role]:
				if not branches.has(t.branch):
					branches.append(t.branch)
			for branch in branches:
				var grid = _grid("◆ " + branch)
				for t in battle.data.talentDefs[m.role]:
					if t.branch != branch:
						continue
					var learned = m.talents.has(t.id)
					var required = not t.has("require") or m.talents.has(t.require)
					var suffix = "\n前提スキルが必要" if not required else "\nSPが足りません" if m.sp < t.cost and not learned else ""
					var b = _button(grid, "%s%s SP%d\n%s%s" % ["✅ " if learned else "□ " if required else "🔒 ",t.name,t.cost,t.desc,suffix], _learn.bind(t.id), t.id)
					b.disabled = not battle.can_learn(battle.sel_ally, t) or battle.busy
					if learned:
						b.add_theme_color_override("font_disabled_color", Color(COLORS.green))
	_fit_popup.call_deferred()


func _fit_popup() -> void:
	if not awaiting_start:
		popup_scroll.custom_minimum_size.y = minf(popup_content.get_combined_minimum_size().y, 480)


func _cost_text(cost: Dictionary, separator: String = "x") -> String:
	var entries: Array[String] = []
	for key in cost:
		entries.append("%s%s%d" % [battle.data.mat.get(key, key),separator,cost[key]])
	return " / ".join(entries)


func _equipment_text(e: Dictionary) -> String:
	var names = {"attack":"攻撃","defense":"防御","maxHp":"最大HP","maxMp":"最大MP","fireBoost":"炎強化","iceBoost":"氷強化","thunderBoost":"雷強化","windBoost":"風強化","holyBoost":"聖強化","healBoost":"回復強化","dropBoost":"ドロップ率","mpCostDown":"MP消費軽減","fireAttack":"通常炎化","breathResist":"ブレス軽減"}
	var parts: Array[String] = []
	for key in e.stats:
		parts.append("%s+%d" % [names.get(key,key),e.stats[key]])
	for key in e.effects:
		parts.append("%s%s%d%s" % [names.get(key,key),"-" if key == "mpCostDown" else "+",e.effects[key] if key == "mpCostDown" else roundi(e.effects[key]*100),"" if key == "mpCostDown" else "%"])
	return ("特殊効果" if parts.is_empty() else " / ".join(parts)) + ("\n追加効果:" + e.affix if e.has("affix") else "")


func _equip(id: String) -> void:
	battle.equip(battle.sel_ally, id)


func _unequip(slot: String) -> void:
	battle.unequip(battle.sel_ally, slot)


func _craft(id: String, equipment: bool) -> void:
	battle.craft(id, equipment)


func _learn(id: String) -> void:
	battle.learn(battle.sel_ally, id)


func _quest(id: String) -> void:
	battle.claim_quest(id)


func _show_start() -> void:
	awaiting_start = true
	start_background.show()
	close_button.hide()
	popup_panel.custom_minimum_size.x = 920
	var start_style = _style(Color("#0c0a09e8"), Color("#facc15"), 3, 26)
	for edge in ["left", "right", "top", "bottom"]:
		start_style.set("content_margin_" + edge, 26)
	popup_panel.add_theme_stylebox_override("panel", start_style)
	popup_scroll.custom_minimum_size = Vector2(862, 240)
	popup.show()
	popup_kind = "start"
	_clear(popup_content)
	_label(popup_content, "ミニ勇者バトル 全部入り完成版", 26).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(popup_content, "敵予告・予告アニメーション・敵行動パターン・味方技・LIMIT複数化・装備追加・ランダム追加効果・クエスト大量追加・クエスト解放・ランダム報酬を統合。", 13).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grid = _grid("")
	grid.columns = 4
	for key in ["easy","normal","hard","hell"]:
		var descriptions = {"easy":"敵弱め","normal":"標準","hard":"報酬多め","hell":"高難度"}
		var b = _button(grid, "%s\n%s" % [battle.data.diffs[key].label,descriptions[key]], _choose_difficulty.bind(key), key)
		b.toggle_mode = true
		b.button_pressed = key == chosen_difficulty
		b.add_theme_stylebox_override("pressed", _style(Color("#451a0380"), Color("#facc15"), 2, 16))
	_button(popup_content, "冒険を始める", _begin, "StartAdventure").alignment = HORIZONTAL_ALIGNMENT_CENTER
	_locks()
	popup_content.find_child(chosen_difficulty, true, false).grab_focus.call_deferred()


func _choose_difficulty(key: String) -> void:
	chosen_difficulty = key
	for button in popup_content.find_children("*", "Button", true, false):
		if battle.data.diffs.has(button.name):
			button.button_pressed = button.name == key


func _begin() -> void:
	awaiting_start = false
	start_background.hide()
	close_button.show()
	popup_panel.custom_minimum_size.x = 520
	popup_panel.remove_theme_stylebox_override("panel")
	popup_scroll.custom_minimum_size = Vector2(496, 480)
	_close_popup()
	battle.start(chosen_difficulty)
	attack_button.grab_focus()


func _banner(text: String) -> void:
	if not is_inside_tree():
		return
	if banner_tween != null:
		banner_tween.kill()
	banner_label.text = text
	banner_label.modulate.a = 1
	banner_label.show()
	banner_tween = banner_label.create_tween()
	banner_tween.tween_interval(0.7)
	banner_tween.tween_property(banner_label, "modulate:a", 0.0, 0.3)
	banner_tween.tween_callback(banner_label.hide)


func _effect(target: String, index: int, text: String, kind: String) -> void:
	if target == "screen":
		if kind == "shake":
			var tween = main.create_tween()
			for offset in [Vector2(-7,3),Vector2(6,-3),Vector2(-5,-4),Vector2(4,4),Vector2(-2,2),Vector2.ZERO]:
				tween.tween_property(main, "position", main.position + offset, 0.06)
		else:
			wash_layer.color = Color("#facc1530") if kind in ["holyWash","victoryBurst"] else Color("#1d4ed830")
			var tween = wash_layer.create_tween()
			tween.tween_property(wash_layer, "color:a", 0.0, 0.7 if kind == "holyWash" else 1.1 if kind == "victoryBurst" else 0.55)
		return
	var cards = party_cards if target == "ally" else enemy_cards
	if index < 0 or index >= cards.size():
		return
	var card: Control = cards[index]
	if not text.is_empty():
		var floating = _label(self, text, 34 if kind == "crit" else 28)
		floating.position = card.get_global_rect().get_center() - Vector2(28, 16)
		floating.add_theme_color_override("font_color", Color(COLORS.green if kind == "heal" else COLORS.yellow if kind == "crit" else COLORS.red))
		var tween = floating.create_tween().set_parallel(true)
		tween.tween_property(floating, "position:y", floating.position.y - 70, 1.0)
		tween.tween_property(floating, "modulate:a", 0.0, 1.0)
		tween.chain().tween_callback(floating.queue_free)
	card.pivot_offset = card.size / 2
	var tween = card.create_tween()
	tween.tween_property(card, "scale", Vector2.ONE * (1.08 if kind == "crit" else 1.04), 0.15)
	tween.tween_property(card, "scale", Vector2.ONE, 0.2)


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
