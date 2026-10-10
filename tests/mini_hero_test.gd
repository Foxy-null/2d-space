extends SceneTree

const Battle = preload("res://games/mini_hero/battle.gd")
var checks := 0
var failed := false

class FixedBattle:
	extends "res://games/mini_hero/battle.gd"
	var roll := 0.5
	func _roll() -> float:
		return roll
	func _settle_action() -> void:
		pass


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error(message)


func _run() -> void:
	var cases = JSON.parse_string(FileAccess.get_file_as_string("res://tests/mini_hero_reference.json"))
	for fixture in cases:
		var battle = FixedBattle.new()
		battle.start()
		battle.party = fixture.initial.party.duplicate(true)
		battle.enemies = fixture.initial.enemies.duplicate(true)
		battle.active = int(fixture.initial.active)
		battle.roll = fixture.initial.roll
		var skill = fixture.command not in ["attack", "guard", "fire", "spark", "heal"]
		_check(battle.perform("skill" if skill else fixture.command, fixture.command if skill else ""), "Reference action executes: " + fixture.command)
		for i in range(3):
			for key in fixture.expected.party[i]:
				_check(battle.party[i].get(key, 0) == fixture.expected.party[i][key], "JS comparison party %s %s enhanced=%s" % [fixture.command, key, fixture.enhanced])
			for key in fixture.expected.enemies[i]:
				_check(battle.enemies[i].get(key, false) == fixture.expected.enemies[i][key], "JS comparison enemies %s %s enhanced=%s" % [fixture.command, key, fixture.enhanced])
	var game = Battle.new()
	game.start()
	game.actor().mp = 0
	var hp_before = game.enemies[0].hp
	_check(not game.perform("skill", "heroSlash") and game.active == 0 and game.enemies[0].hp == hp_before, "Insufficient MP consumes neither action nor health")
	game.actor().mp = 100
	_check(not game.perform("skill", "meteor") and game.actor().mp == 100 and game.active == 0, "Unavailable/foreign skills consume nothing")
	game.actor().level = 1
	_check(not game.perform("skill", "gigaSlash"), "Learning level is enforced")
	var attack_before = game.actor().attack
	_check(game.learn(0, "hero_atk_1") and game.actor().attack == attack_before + 2, "Learning applies permanent stats")
	_check(not game.learn(0, "hero_atk_1"), "No duplicate learning")
	_check(not game.learn(0, "hero_atk_3"), "Prerequisites enforced")
	game.party[0].sp = 0
	_check(not game.learn(0, "hero_guard_1"), "SP checked")
	_check(not game.equip(0, "not_owned") and not game.equip(0, "apprenticeStaff"), "Ownership and job checked")
	game.inventory.append("flameSword")
	_check(game.equip(0, "flameSword"), "Equip a compatible owned item")
	_check(game.actor().attack == attack_before + 4, "Equipment swaps subtract old stats")
	_check(not game.equip(0, "flameSword"), "No repeated stat stacking")
	_check(game.equip(0, "bronzeSword") and game.actor().attack == attack_before + 2, "Switching back preserves learned stats")
	var ore_before = game.materials.magicOre
	_check(game.craft("bronzeSword", true) and game.materials.magicOre == ore_before - 2, "Craft consumes exact recipe")
	var instance = game.inventory.back()
	_check(game.equipment_def(instance).has("affix"), "Crafted equipment has a random affix")
	game.materials.magicOre = 0
	var inventory_before = game.inventory.size()
	_check(not game.craft("bronzeSword", true) and game.inventory.size() == inventory_before, "Failed crafting changes no inventory")
	var herbs_before = game.items.herb
	_check(game.craft("herb", false) and game.items.herb == herbs_before + 2, "Consumable recipe yield retained")
	game.developer_supply()
	_check(game.party.all(func(m): return m.level >= 8 and m.sp >= 15), "Explicit developer support unlocks testing")
	game.party[0].hp = 0
	game.sel_ally = 0
	_check(game.use_item("reviveStone") and game.party[0].hp > 0, "Provisional revival works")
	game.start()
	for i in range(3):
		_check(game.perform("guard"), "Provisional turn advances")
	_check(game.turn == 2 and game.active == 0 and game.alive_party().size() > 0, "Enemy turn executes and returns control")
	game.start()
	game.actor().attack = 5000
	for enemy in game.enemies:
		enemy.hp = 1
	for i in range(3):
		game.perform("attack")
	_check(game.phase == "won" and game.party[0].sp > 3, "Victory grants provisional EXP and SP")
	_check(game.next_wave() and game.wave == 2 and game.phase == "party", "Next floor becomes playable")
	_check(not game.next_wave() and game.wave == 2, "No next-floor shortcut during battle")
	game.wave = 5
	var bosses = game.make_enemies()
	_check(bosses[0].isBoss and bosses.size() == 3, "Fifth floor has boss and two enemies")
	for member in game.party:
		member.hp = 0
	game._settle_action()
	_check(game.phase == "lost", "Defeat recognized")
	game.developer_supply()
	_check(game.phase == "party" and game.actor().hp > 0, "Developer recovery resumes a lost battle")
	game.start("hell")
	_check(game.difficulty == "hell" and game.enemies[0].maxHp == roundi(30 * 1.35 * 1.3), "Difficulty changes original enemy formula")
	print("MINI_HERO_TEST_%s (%d checks, %d JS reference cases)" % ["FAILED" if failed else "OK", checks, cases.size()])
	quit(1 if failed else 0)
