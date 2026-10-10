extends SceneTree

var checks := 0
var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error(message)


func _step(count: int = 3) -> void:
	for i in range(count):
		await process_frame


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	await _step()
	event.pressed = false
	root.push_input(event, true)
	await _step()


func _click(button: Button) -> void:
	_check(button != null and not button.disabled, "Clicked button must exist and be enabled")
	if button == null or button.disabled:
		return
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await _step()
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = motion.position
	event.pressed = true
	root.push_input(event, true)
	await _step()
	event.pressed = false
	root.push_input(event, true)
	await _step()


func _button(node: Node, name: String) -> Button:
	return node.find_child(name, true, false) as Button


func _screenshot(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"):
		return
	if name == "battle":
		current_scene.find_child("GameScroll", true, false).scroll_vertical = 0
	await _step(75)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/screenshots/mini-hero/" + name + ".png")


func _settled(game: Node) -> void:
	var frames = 0
	while game.battle.busy and frames < 300:
		await _step(1)
		frames += 1
	_check(not game.battle.busy, "Source turn completes within animation time")
	await _step()


func _run() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/game_select.tscn", "Boot uses game selection")
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await _step()
	_check(root.gui_get_focus_owner() == _button(current_scene, "ActionGame"), "Legacy game initially focused")
	await _screenshot("game-selection")
	await _key(KEY_RIGHT)
	await _key(KEY_ENTER)
	_check(current_scene.scene_file_path == "res://games/mini_hero/game.tscn", "Enter opens native RPG")
	var game = current_scene
	_check(game.popup.visible and game.awaiting_start, "Original difficulty screen is initially modal")
	await _click(_button(game.popup, "normal"))
	await _click(_button(game.popup, "StartAdventure"))
	_check(not game.popup.visible and game.battle.difficulty == "normal", "Starting applies selected difficulty")
	_check(game.find_child("DeveloperSupply", true, false) == null, "No invented developer supply")
	_check(game.battle.party[0].attack == 12 and game.battle.party[0].sp == 0, "Original base stats and zero SP")
	_check(game.battle.inventory.size() == 6 and game.battle.party[0].equip.weapon == null, "Initial random equipment is owned but not equipped")
	for i in range(3):
		var glyphs = game.enemy_cards[i].find_children("*", "Label", true, false).filter(func(l): return l.text == game.battle.enemies[i].emoji)
		_check(glyphs.size() == 1 and glyphs[0].get_theme_font("font") == game.EMOJI, "Exact source enemy emoji and explicit color font")
	_check(game.main.get_global_rect().end.x <= root.get_visible_rect().size.x + 1, "Native columns fit viewport horizontally")
	game.battle.rng.seed = 17
	game.battle.assign_enemy_intents()
	await _click(_button(game, "Menu"))
	await _click(_button(game.popup, "Equipment"))
	var sword = game.battle.equipment.filter(func(e): return e.get("baseId", "") == "bronzeSword")[0]
	await _click(_button(game.popup, "Equip_" + sword.id))
	_check(game.battle.party[0].equip.weapon == sword.id and game.battle.party[0].attack == 12 + sword.stats.attack, "Equipment UI equips original random item")
	await _screenshot("equipment")
	await _key(KEY_ESCAPE)
	await _click(_button(game, "Items"))
	await _click(_button(game.popup, "trainingBook"))
	await _settled(game)
	_check(game.battle.party[0].sp == 1 and game.battle.active == 1, "Training book grants source SP and consumes an action")
	await _click(_button(game, "Menu"))
	await _click(_button(game.popup, "Talents"))
	await _click(_button(game, "Ally0"))
	_check(game.battle.sel_ally == 0 and game.popup_kind == "talent", "Ally selection outside popup updates talent target like HTML")
	await _click(_button(game.popup, "hero_atk_1"))
	_check(game.battle.party[0].sp == 0 and game.battle.party[0].talents.has("hero_atk_1"), "Talent learning consumes source SP")
	await _screenshot("talents")
	await _key(KEY_ESCAPE)
	await _click(_button(game, "Skills"))
	_check(_button(game.popup, "meteor").disabled, "Source level requirement disables meteor at level one")
	await _click(_button(game.popup, "iceDance"))
	await _settled(game)
	_check(game.battle.active == 2, "Mage skill advances to priest")
	await _click(_button(game, "Skills"))
	_check(not _button(game.popup, "partyHeal").disabled, "Original priest effect is available")
	await _click(_button(game.popup, "partyHeal"))
	await _settled(game)
	_check(game.battle.active == 0 and game.battle.phase == "party", "Original enemy phase returns control")
	await _screenshot("battle")
	var attempts = 0
	while game.battle.phase == "party" and attempts < 18:
		var a = game.battle.actor()
		if a.role == "hero" and a.mp >= game.battle.mp_cost(a, 5):
			await _click(_button(game, "Skills"))
			await _click(_button(game.popup, "heroSlash"))
		elif a.role == "mage" and a.mp >= game.battle.mp_cost(a, 8):
			await _click(_button(game, "Skills"))
			await _click(_button(game.popup, "iceDance"))
		elif a.role == "priest" and a.mp >= game.battle.mp_cost(a, 3):
			await _click(_button(game, "Magic"))
			await _click(_button(game.popup, "fire"))
		else:
			await _click(game.attack_button)
		await _settled(game)
		attempts += 1
	_check(game.battle.phase == "won", "Actual UI actions win the first battle")
	if game.battle.phase != "won":
		print("GAME_SELECT_TEST_FAILED (%d checks)" % checks)
		quit(1)
		return
	_check(game.next_button.disabled and game.battle.event_kind == "starter", "Victory requires original route choice and offers starter reward")
	await _click(_button(game, "Starter_craft"))
	_check(game.battle.stats.starterRewardChosen and game.battle.event_kind.is_empty(), "Original starter choice grants a single reward")
	await _click(_button(game, "Menu"))
	await _click(_button(game.popup, "Quests"))
	var herbs = game.battle.items.herb
	await _click(_button(game.popup, "Quest_firstKill"))
	_check(game.battle.quests.firstKill and game.battle.items.herb == herbs + 2, "Quest UI claims original reward exactly once")
	await _key(KEY_ESCAPE)
	await _click(_button(game, "Menu"))
	await _click(_button(game.popup, "Book"))
	_check(game.battle.bestiary.size() == 3, "Original bestiary records defeated enemies")
	await _key(KEY_ESCAPE)
	await _click(_button(game, "Menu"))
	await _click(_button(game.popup, "Craft"))
	var flowers = game.battle.materials.herbFlower
	await _click(_button(game.popup, "Craft_herb"))
	_check(game.battle.materials.herbFlower == flowers - 1, "Item craft uses source recipe")
	await _key(KEY_ESCAPE)
	await _click(_button(game, "Route_safe"))
	_check(game.battle.route_chosen and not game.next_button.disabled, "Original route choice unlocks next floor")
	await _click(game.next_button)
	_check(game.battle.wave == 2 and game.battle.phase == "party", "Next floor uses chosen route")
	await _click(_button(game, "Restart"))
	_check(game.battle.wave == 1 and game.battle.party[0].sp == 0 and game.battle.inventory.size() == 6 and game.battle.quests.is_empty(), "Source restart resets state without invented grants")
	# LIMITの表示条件だけを試験内で設定し、通常の画面操作から発動する。
	for i in range(3):
		await _click(_button(game, "Restart"))
		game.battle.active = i
		game.battle.party[i].limit = 100
		game._render()
		await _click(_button(game, "Skills"))
		var limits = game.battle.data.limits[game.battle.party[i].role]
		for li in limits:
			_check(_button(game.popup, li.id) != null and not _button(game.popup, li.id).disabled, "All original LIMIT choices appear at full gauge")
		await _click(_button(game.popup, limits[0].id))
		await _settled(game)
		_check(game.battle.stats.limit == 1, "LIMIT UI executes the original command")
	await _click(_button(game, "Restart"))
	await _click(game.attack_button)
	_check(game.battle.busy, "Departure is exercised during a live animated turn")
	await _click(_button(game, "ReturnToGames"))
	await _step(100)
	_check(current_scene.scene_file_path == "res://scenes/game_select.tscn", "RPG returns to game selection")
	await _key(KEY_ENTER)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Existing game starts at original stage selection")
	await _click(_button(current_scene, "ReturnToGames"))
	_check(current_scene.scene_file_path == "res://scenes/game_select.tscn", "Existing game can return")
	await _key(KEY_RIGHT)
	await _key(KEY_ENTER)
	await _key(KEY_ESCAPE)
	_check(current_scene.scene_file_path == "res://scenes/game_select.tscn", "Esc exits initial RPG screen")
	print("GAME_SELECT_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)
