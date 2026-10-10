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
	await _step(45)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/screenshots/mini-hero/" + name + ".png")


func _run() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/game_select.tscn", "Boot uses game selection")
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await _step()
	_check(root.gui_get_focus_owner() == _button(current_scene, "ActionGame"), "Legacy game initially focused")
	await _screenshot("game-selection")
	await _key(KEY_RIGHT)
	_check(root.gui_get_focus_owner() == _button(current_scene, "MiniHero"), "Keyboard selects RPG")
	await _key(KEY_ENTER)
	_check(current_scene.scene_file_path == "res://games/mini_hero/game.tscn", "Enter opens native RPG")
	var game = current_scene
	_check(game.popup.visible and game.awaiting_start, "Difficulty selection is initially modal")
	await _click(_button(game.popup, "hard"))
	_check(game.chosen_difficulty == "hard", "Difficulty selection responds to click")
	await _click(_button(game.popup, "StartAdventure"))
	_check(not game.popup.visible and game.battle.difficulty == "hard", "Starting applies selected difficulty")
	_check(game.main.get_global_rect().end.y <= root.get_visible_rect().size.y + 1, "Main UI fits viewport vertically")
	_check(game.main.get_global_rect().end.x <= root.get_visible_rect().size.x + 1, "Main UI fits viewport horizontally")
	var enemy_hp = game.battle.enemies[0].hp
	await _click(game.attack_button)
	_check(game.battle.enemies[0].hp < enemy_hp and game.battle.active == 1, "Attack damages selected enemy and advances actor")
	await _click(_button(game, "Skills"))
	_check(game.popup.visible, "Skills menu opens")
	_check(_button(game.popup, "meteor").disabled, "Unreceived effects remain visible and disabled")
	await _click(_button(game.popup, "iceDance"))
	_check(not game.popup.visible and game.battle.active == 2, "Skill action executes and closes popup")
	await _click(_button(game, "Skills"))
	_check(root.gui_get_focus_owner() == game.close_button, "Unavailable priest skills focus the close button")
	_check(_button(game.popup, "partyHeal").disabled, "Priest effects without received code remain disabled")
	await _key(KEY_ESCAPE)
	await _click(_button(game, "Magic"))
	await _click(_button(game.popup, "heal"))
	_check(game.battle.turn == 2 and game.battle.active == 0, "Three actions execute enemy turn")
	await _screenshot("battle")
	await _click(_button(game, "DeveloperSupply"))
	_check(game.battle.party[0].level >= 8 and game.battle.inventory.size() == 31, "Developer support opens full data testing")
	await _click(_button(game, "Menu"))
	await _click(_button(game.popup, "Equipment"))
	var old_attack = game.battle.party[0].attack
	await _click(_button(game.popup, "Equip_flameSword"))
	_check(game.battle.party[0].attack == old_attack + 2, "Equipment UI replaces weapon without stacking")
	await _screenshot("equipment")
	await _key(KEY_ESCAPE)
	_check(not game.popup.visible and current_scene == game, "Esc closes a menu without exiting")
	await _click(_button(game, "Menu"))
	await _click(_button(game.popup, "Talents"))
	var sp_before = game.battle.party[0].sp
	await _click(_button(game.popup, "hero_atk_1"))
	_check(game.battle.party[0].sp == sp_before - 1 and game.battle.party[0].attack == old_attack + 4, "Talent UI learns skill and updates stats")
	await _screenshot("talents")
	await _key(KEY_ESCAPE)
	await _click(_button(game, "Menu"))
	await _click(_button(game.popup, "Craft"))
	var ore_before = game.battle.materials.magicOre
	await _click(_button(game.popup, "Craft_bronzeSword"))
	_check(game.battle.materials.magicOre == ore_before - 2 and game.battle.inventory.size() == 32, "Craft UI consumes materials and adds item")
	await _key(KEY_ESCAPE)
	await _click(_button(game, "Restart"))
	await _click(_button(game.popup, "StartAdventure"))
	_check(game.battle.party[0].level == 1 and game.battle.inventory.size() == 6 and game.battle.party[0].talents.is_empty(), "Restart resets inventory, growth and learned skills")
	await _click(_button(game, "ReturnToGames"))
	_check(current_scene.scene_file_path == "res://scenes/game_select.tscn", "RPG returns to game selection")
	await _key(KEY_ENTER)
	_check(current_scene.scene_file_path == "res://scenes/stage_select.tscn", "Existing game still starts at original stage selection")
	await _click(_button(current_scene, "ReturnToGames"))
	_check(current_scene.scene_file_path == "res://scenes/game_select.tscn", "Legacy menu can return by mouse")
	await _key(KEY_ENTER)
	await _key(KEY_ESCAPE)
	_check(current_scene.scene_file_path == "res://scenes/game_select.tscn", "Legacy menu can return by Esc")
	await _key(KEY_RIGHT)
	await _key(KEY_ENTER)
	await _key(KEY_ESCAPE)
	_check(current_scene.scene_file_path == "res://scenes/game_select.tscn", "Esc exits initial RPG start screen")
	print("GAME_SELECT_TEST_%s (%d checks)" % ["FAILED" if failed else "OK", checks])
	quit(1 if failed else 0)
