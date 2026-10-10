extends SceneTree

const Battle = preload("res://games/mini_hero/battle.gd")
var checks := 0
var failures := 0

class FixedBattle:
	extends "res://games/mini_hero/battle.gd"
	var roll := 0.5
	var calls := 0
	func _roll() -> float:
		calls += 1
		return roll


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		if failures < 40:
			push_error(message)


func _compare(actual: Variant, expected: Variant, path: String) -> void:
	if expected is Dictionary:
		_check(actual is Dictionary, path + " dictionary")
		if actual is not Dictionary:
			return
		_check(actual.size() == expected.size(), path + " key count actual=" + str(actual.keys()) + " expected=" + str(expected.keys()))
		for key in expected:
			_check(actual.has(key), path + " missing " + key)
			if actual.has(key):
				_compare(actual[key], expected[key], path + "." + key)
	elif expected is Array:
		_check(actual is Array and actual.size() == expected.size(), path + " array size")
		if actual is Array and actual.size() == expected.size():
			for i in range(expected.size()):
				_compare(actual[i], expected[i], path + "[%d]" % i)
	else:
		_check(actual == expected, "%s actual=%s expected=%s" % [path, str(actual), str(expected)])


func _restore(b: FixedBattle, fixture: Dictionary) -> void:
	var s = fixture.initial
	b.party = s.party.duplicate(true)
	b.enemies = s.enemies.duplicate(true)
	b.last_enemies = s.lastEnemies.duplicate(true)
	b.equipment = s.equipDefs.duplicate(true)
	b.inventory = s.equips.duplicate(true)
	b.items = s.items.duplicate(true)
	b.materials = s.materials.duplicate(true)
	b.quests = s.quest.duplicate(true)
	b.stats = s.stats.duplicate(true)
	b.bestiary = s.bestiary.duplicate(true)
	b.wave = int(s.wave)
	b.active = int(s.active)
	b.sel_enemy = int(s.selE)
	b.sel_ally = int(s.selA)
	b.busy = s.busy
	b.phase = ("won" if s.preparing else "lost") if s.finished else "party"
	b.preparing = s.preparing
	b.route = s.route.duplicate(true)
	b.route_chosen = s.routeChosen
	b.difficulty = s.curDiff
	b.skill_mode = s.skillMode
	b.instance_counter = int(s.stamp)
	b.messages = s.logs.duplicate(true)
	b.roll = fixture.roll
	b.calls = 0
	b.event_kind = "starter" if s.eventHtml.contains("冒険者への支給品") else ""


func _snapshot(b: FixedBattle) -> Dictionary:
	var ids: Dictionary = {}
	var definitions: Array = []
	for i in range(b.equipment.size()):
		var e = b.equipment[i]
		ids[e.id] = "eq:%d" % i if e.has("baseId") else e.id
		definitions.append({"id":ids[e.id],"baseId":e.get("baseId",""),"name":e.name,"slot":e.slot,"jobs":e.jobs,"rarity":e.rarity,"stats":e.stats,"effects":e.effects,"affix":e.get("affix", "")})
	var party = b.party.duplicate(true)
	for m in party:
		m.charge = m.get("charge", 0)
		for key in m.equip:
			m.equip[key] = ids.get(m.equip[key], null)
	var enemies = b.enemies.duplicate(true)
	for e in enemies:
		e.erase("intentFlash")
		e.enraged = e.get("enraged", false)
		e.shielded = e.get("shielded", false)
	var inventory: Dictionary = {}
	for id in b.inventory:
		inventory[ids[id]] = b.inventory[id]
	return {"party":party,"enemies":enemies,"equipDefs":definitions,"equips":inventory,"items":b.items,"materials":b.materials,"quest":b.quests,"stats":b.stats,"bestiary":b.bestiary,"wave":b.wave,"active":b.active,"selE":b.sel_enemy,"selA":b.sel_ally,"busy":b.busy,"preparing":b.preparing,"route":b.route,"routeChosen":b.route_chosen,"skillMode":b.skill_mode,"logs":b.messages,"phase":b.phase,"event_kind":b.event_kind,"calls":b.calls}


func _run() -> void:
	var payload = JSON.parse_string(FileAccess.get_file_as_string("res://tests/mini_hero_reference.json"))
	var fixtures = payload.cases
	for fixture in fixtures:
		fixture = fixture.duplicate(true)
		fixture.initial = _patch(payload.initial_base, fixture.initial)
		fixture.expected = _patch(payload.expected_base, fixture.expected)
		var b = FixedBattle.new()
		_restore(b, fixture)
		var id = fixture.id
		var result := true
		match fixture.kind:
			"start": b.start(id)
			"command": result = b.command_effect(id)
			"skill": result = b.use_skill(id if id != "noRevive" else "revive")
			"limit": result = b.use_limit(id)
			"item": result = b.use_item(id if id != "noRevive" else "reviveStone")
			"enemy", "pattern": b.execute_intent(b.enemies[0])
			"quest": b.claim_quest(id)
			"route": b.choose_route(id)
			"win": b.win()
			"next": b.next_wave()
			"starter": b.choose_starter_reward(id)
			"talent": b.learn(b.sel_ally, id)
			"craft": b.craft(id)
			"craftEq": b.craft(id, true)
			"equip":
				var matches = b.equipment.filter(func(e): return e.get("baseId", "") == id)
				b.equip(0, matches[0].id)
			"unequip": b.unequip(0, b.equipment_def(id).slot)
			"turn": result = await b.perform("fire" if id == "noMP" else "guard" if id == "lose" else id)
		if fixture.kind != "turn":
			_check(result == fixture.result, "%s %s returns expected success" % [fixture.kind, id])
		_compare(_snapshot(b), fixture.expected, "%s %s roll=%s" % [fixture.kind, id, fixture.roll])
	var edge = FixedBattle.new()
	edge.start()
	for m in edge.party:
		m.hp = 0
	edge.party[0].hp = 1
	edge.enemies[0].skill = "doubleAttack"
	edge.enemies[0].attack = 99
	edge.enemy_skill(edge.enemies[0])
	_check(edge.alive_party().is_empty(), "Source doubleAttack edge safely ends after last survivor falls")
	print("MINI_HERO_TEST_%s (%d checks, %d full-source cases, %d failures)" % ["OK" if failures == 0 else "FAILED", checks, fixtures.size(), failures])
	quit(0 if failures == 0 else 1)


func _patch(base: Dictionary, operations: Array) -> Dictionary:
	var value = base.duplicate(true)
	for op in operations:
		var current: Variant = value
		var path: Array = op[1]
		for key in path.slice(0, -1):
			current = current[int(key)] if current is Array else current[key]
		var key = path.back()
		if current is Array:
			var index = int(key)
			if op[0] == "remove":
				current.remove_at(index)
			elif index == current.size():
				current.append(op[2])
			else:
				current[index] = op[2]
		elif op[0] == "remove":
			current.erase(key)
		else:
			current[key] = op[2]
	return value
