extends RefCounted

signal logged(text: String)

# shortcut: 効果処理を受領していない技は無効化し、仕様を確認できた時点で追加する。
const AVAILABLE_SKILLS = ["heroSlash", "quickSlash", "guardStrike", "cover", "shieldBash", "windSlash", "rally", "braveStrike", "gigaSlash", "iceDance", "sparkShot", "chillNeedle", "focus", "thunderBolt", "fireStorm", "manaBurst", "frostPrison"]
var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://games/mini_hero/data.json"))
var rng := RandomNumberGenerator.new()
var party: Array = []
var enemies: Array = []
var equipment: Array = []
var inventory: Array = []
var items: Dictionary = {}
var materials: Dictionary = {}
var stats: Dictionary = {}
var messages: Array[String] = []
var difficulty := "normal"
var wave := 1
var turn := 1
var active := 0
var sel_enemy := 0
var sel_ally := 0
var phase := "party"
var skill_mode := false
var instance_counter := 0


func start(diff: String = "normal") -> void:
	difficulty = diff if data.diffs.has(diff) else "normal"
	rng.randomize()
	party = data.members.duplicate(true)
	equipment = data.equipDefs.duplicate(true)
	inventory.clear()
	items = {"herb": 4, "manaWater": 3, "reviveStone": 1}
	materials.clear()
	for key in data.mat:
		materials[key] = 6
	stats.clear()
	messages.clear()
	wave = 1
	turn = 1
	active = 0
	sel_ally = 0
	sel_enemy = 0
	instance_counter = 0
	skill_mode = false
	phase = "party"
	# 仮実装: 初期所持品・SPは未受領。開発版で戦闘と成長を試せる初期値。
	var starting = [["bronzeSword", "ironArmor"], ["apprenticeStaff", "magicRobe"], ["prayerStaff", "monkRobe"]]
	for member in party:
		member.equip = {}
		member.talents = {}
		member.sp = 3
	for i in range(party.size()):
		for id in starting[i]:
			inventory.append(id)
			equip(i, id)
		party[i].hp = party[i].maxHp
		party[i].mp = party[i].maxMp
	enemies = []
	enemies = make_enemies()
	say("冒険を開始。敵・報酬・進行は仮実装です。")


func say(text: String) -> void:
	messages.append(text)
	if messages.size() > 160:
		messages.pop_front()
	logged.emit(text)


func _roll() -> float:
	return rng.randf()


func random_int(low: int, high: int) -> int:
	return mini(high, low + int(floor(_roll() * (high - low + 1))))


func alive_party() -> Array:
	return party.filter(func(m): return m.hp > 0)


func alive_enemies() -> Array:
	return enemies.filter(func(e): return e.hp > 0)


func actor() -> Dictionary:
	return party[active]


func enemy_target() -> Dictionary:
	if enemies[sel_enemy].hp > 0:
		return enemies[sel_enemy]
	for i in range(enemies.size()):
		if enemies[i].hp > 0:
			sel_enemy = i
			return enemies[i]
	return {}


func talent_effect(m: Dictionary, key: String) -> float:
	var total := 0.0
	for talent in data.talentDefs[m.role]:
		if m.get("talents", {}).has(talent.id):
			total += talent.effect.get(key, 0)
	return total


func party_talent(role: String, key: String) -> float:
	var total := 0.0
	for m in alive_party():
		if role.is_empty() or m.role == role:
			total += talent_effect(m, key)
	return total


func equipment_def(id: String) -> Dictionary:
	for definition in equipment:
		if definition.id == id:
			return definition
	return {}


func equipment_effect(m: Dictionary, key: String) -> float:
	var total := 0.0
	for id in m.get("equip", {}).values():
		total += equipment_def(id).get("effects", {}).get(key, 0)
	return total


func has_equipment(m: Dictionary, base_id: String) -> bool:
	for id in m.get("equip", {}).values():
		if id == base_id or equipment_def(id).get("baseId", "") == base_id:
			return true
	return false


func set_bonus(m: Dictionary, key: String) -> float:
	var sets = [
		["hero", "flameSword", "ironArmor", "attack", 2],
		["hero", "thunderSword", "crystalArmor", "thunderBoost", 0.12],
		["mage", "flameStaff", "magicRobe", "fireBoost", 0.1],
		["mage", "iceStaff", "magicRobe", "iceBoost", 0.1],
		["mage", "stormStaff", "sageRobe", "thunderBoost", 0.12],
		["priest", "prayerStaff", "saintRobe", "healBoost", 0.1],
		["priest", "saintStaff", "oracleVestment", "healBoost", 0.15]]
	var total := 0.0
	for entry in sets:
		if m.role == entry[0] and key == entry[3] and has_equipment(m, entry[1]) and has_equipment(m, entry[2]):
			total += entry[4]
	return total


func mp_cost(m: Dictionary, base: float) -> int:
	return maxi(0, int(base - equipment_effect(m, "mpCostDown") - talent_effect(m, "mpCostDown")))


func can_learn(index: int, talent: Dictionary) -> bool:
	if index < 0 or index >= party.size():
		return false
	var m = party[index]
	return not m.talents.has(talent.id) and m.sp >= talent.cost and (not talent.has("require") or m.talents.has(talent.require))


func learn(index: int, id: String) -> bool:
	if index < 0 or index >= party.size():
		return false
	for talent in data.talentDefs[party[index].role]:
		if talent.id != id:
			continue
		if not can_learn(index, talent):
			return false
		var m = party[index]
		m.sp -= talent.cost
		m.talents[id] = true
		for key in ["attack", "defense", "maxHp", "maxMp"]:
			var amount = talent.effect.get(key, 0)
			m[key] += amount
			if key == "maxHp":
				m.hp += amount
			if key == "maxMp":
				m.mp += amount
		say("%sは「%s」を習得。" % [m.name, talent.name])
		return true
	return false


func equip(index: int, id: String) -> bool:
	# 仮実装: 装備交換本体は未受領。所持・職業・重複装備を検証して差分を反映。
	if index < 0 or index >= party.size() or not inventory.has(id):
		return false
	var definition = equipment_def(id)
	if definition.is_empty() or not definition.jobs.has(party[index].role):
		return false
	for m in party:
		if m.equip.values().has(id):
			return false
	var member = party[index]
	var old = equipment_def(member.equip.get(definition.slot, ""))
	for key in ["attack", "defense", "maxHp", "maxMp"]:
		member[key] += definition.stats.get(key, 0) - old.get("stats", {}).get(key, 0)
	member.hp = minf(member.hp, member.maxHp)
	member.mp = minf(member.mp, member.maxMp)
	member.equip[definition.slot] = id
	say("%sが%sを装備。" % [member.name, definition.name])
	return true


func make_equipment(id: String) -> String:
	var base = equipment_def(id)
	if base.is_empty():
		return ""
	var ranks = ["N", "R", "SR"]
	var rank = ranks.find(base.rarity) + 1
	var pool = data.affixDefs.filter(func(a): return a.slots.has(base.slot) and ranks.find(a.rarity) + 1 <= rank + 1)
	var affix = pool[random_int(0, pool.size() - 1)]
	var definition = base.duplicate(true)
	for key in affix.get("stats", {}):
		definition.stats[key] = definition.stats.get(key, 0) + affix.stats[key]
	for key in affix.get("effects", {}):
		definition.effects[key] = definition.effects.get(key, 0) + affix.effects[key]
	instance_counter += 1
	definition.id = "%s__%d" % [id, instance_counter]
	definition.baseId = id
	definition.name = "%s【%s】" % [base.name, affix.name]
	definition.affix = affix.name
	definition.rarity = base.rarity + ("+" if affix.rarity == "SR" else "")
	equipment.append(definition)
	return definition.id


func craft(id: String, is_equipment: bool) -> bool:
	# 仮実装: レシピの消費量・製作数は原資料、製作操作・所持品への追加は補完。
	var recipes = data.equipRecipes if is_equipment else data.recipes
	for recipe in recipes:
		if recipe.id != id:
			continue
		for key in recipe.cost:
			if materials.get(key, 0) < recipe.cost[key]:
				return false
		if is_equipment and equipment_def(id).is_empty():
			return false
		for key in recipe.cost:
			materials[key] -= recipe.cost[key]
		if is_equipment:
			var instance = make_equipment(id)
			inventory.append(instance)
			say("%sを製作。" % equipment_def(instance).name)
		else:
			items[id] = items.get(id, 0) + recipe.make
			say("%sを製作。" % recipe.name)
		return true
	return false


func make_enemies() -> Array:
	var pool = data.enemyBase.duplicate(true)
	var bases: Array = []
	if wave == 1:
		for kind in ["slime", "ghost", "golem"]:
			bases.append(pool.filter(func(e): return e.type == kind)[0])
	else:
		if wave % 5 == 0:
			bases.append(data.bossBase[mini(int(wave / 5) - 1, 3)])
		while bases.size() < 3:
			bases.append(pool.pop_at(random_int(0, pool.size() - 1)))
	var result: Array = []
	var diff = data.diffs[difficulty]
	for i in range(bases.size()):
		var e = bases[i].duplicate(true)
		var boss = e.type.begins_with("boss")
		e.weak = data.profiles[e.type][0]
		e.resist = data.profiles[e.type][1]
		e.isBoss = boss
		e.name = "%s%s Lv.%d" % [e.base, "" if boss else " " + char(65 + i), wave]
		e.maxHp = roundi((e.hp + (wave - 1) * 8 + (wave * 8 if boss else 0)) * diff.hp * data.enemyPower)
		e.hp = e.maxHp
		e.attack = roundi((e.attack + (wave - 1) * 1.4) * diff.atk * data.enemyPower)
		e.defense += floor(wave / 4.0)
		e.stun = 0
		for key in ["guarded", "reflect", "howled", "charged", "enraged", "shielded"]:
			e[key] = false
		result.append(e)
	for e in result:
		e.intent = decide_intent(e)
	return result


func decide_intent(e: Dictionary) -> Dictionary:
	var patterns: Array = []
	var labels = {"powerHit": "渾身の一撃", "snipe": "弱った相手を狙う", "lifeDrain": "生命吸収", "enemyHeal": "仲間を回復", "shieldAll": "敵全体を守る", "enrage": "怒りで攻撃UP", "curse": "呪いの波動", "bossCharge": "力をためる", "bossSmash": "溜め大技"}
	if e.stun > 0:
		return {"kind": "stun", "label": "行動不能", "warn": false}
	if e.charged:
		return {"kind": "pattern", "pattern": "bossSmash", "label": labels.bossSmash, "warn": true}
	if e.isBoss:
		patterns.append("bossCharge")
	if e.hp < e.maxHp * 0.45 and not e.enraged:
		patterns.append("enrage")
	if alive_enemies().any(func(x): return x.hp < x.maxHp * 0.55):
		patterns.append("enemyHeal")
	if not e.shielded and alive_enemies().size() >= 2:
		patterns.append("shieldAll")
	if alive_party().any(func(m): return m.hp / m.maxHp < 0.45):
		patterns.append("snipe")
	if e.type in ["warlock", "ghost", "boss_demon"]:
		patterns.append_array(["curse", "lifeDrain"])
	if e.type in ["wolf", "mimic", "boss_mimic", "dragon", "boss_dragon", "boss_star_dragon"]:
		patterns.append("powerHit")
	if not patterns.is_empty() and _roll() < (0.32 if e.isBoss else 0.22):
		var pattern = patterns[random_int(0, patterns.size() - 1)]
		return {"kind": "pattern", "pattern": pattern, "label": labels[pattern], "warn": pattern in ["powerHit", "snipe", "lifeDrain", "curse", "bossCharge", "bossSmash"]}
	var special := true
	match e.skill:
		"regen": special = e.hp < e.maxHp * 0.7
		"stoneGuard": special = not e.guarded
		"reflect": special = not e.reflect
		"poison": special = alive_party().any(func(m): return m.poison <= 0)
		"howl": special = not e.howled
		"manaDrain": special = alive_party().any(func(m): return m.mp > 0)
	if special and _roll() < (0.45 if e.isBoss else 0.30):
		return {"kind": "skill", "label": e.note, "warn": e.isBoss or e.skill in ["dragonBreath", "ember", "doubleAttack", "poison"]}
	var living = alive_party()
	var target = living[random_int(0, living.size() - 1)].name if not living.is_empty() else ""
	return {"kind": "attack", "target": target, "label": "%sを攻撃" % target, "warn": false}


func element_damage(e: Dictionary, element: String, amount: float, a: Dictionary) -> int:
	var damage_value = amount
	damage_value *= 1 + equipment_effect(a, element + "Boost") + set_bonus(a, element + "Boost") + talent_effect(a, element + "Boost")
	if element == "fire":
		damage_value *= 1 + talent_effect(a, "fireSpellBoost")
	if a.get("charge", 0):
		damage_value *= 1 + talent_effect(a, "focusBoost")
	if element == "ice" and talent_effect(a, "iceWall"):
		for m in alive_party():
			m.guarding = true
	if element == "ice" and talent_effect(a, "iceChase"):
		e.hp -= maxi(3, roundi(damage_value * 0.12))
	if e.weak == element:
		damage_value *= 1.5
		stats.weak = stats.get("weak", 0) + 1
		if a.role == "mage":
			a.mp = minf(a.maxMp, a.mp + 2 + talent_effect(a, "weakMpGain"))
		if talent_effect(a, "weakChase"):
			e.hp -= maxi(3, roundi(damage_value * 0.15))
	if e.resist == element:
		damage_value *= 0.6
	return maxi(1, roundi(damage_value))


func add_limit(m: Dictionary, amount: float) -> void:
	m.limit = minf(100, m.limit + roundi(amount * (1 + talent_effect(m, "limitGain"))))


func damage(e: Dictionary, amount: float, a: Dictionary, element: String = "physical") -> int:
	if a.role == "hero":
		amount += set_bonus(a, "attack")
	if skill_mode:
		amount *= 1 + party_talent("hero", "skillDamageBoost")
	var value = element_damage(e, element, amount, a)
	if _roll() < talent_effect(a, "critRate"):
		value = roundi(value * 1.5)
		say("会心！")
	if e.reflect:
		e.reflect = false
		hit(a, maxi(1, roundi(value * 0.35)))
	e.hp -= value
	add_limit(a, 8)
	if element == "thunder" and _roll() < talent_effect(a, "thunderStun"):
		stun(e)
	if element == "holy" and _roll() < talent_effect(a, "purify"):
		for key in ["guarded", "reflect", "shielded", "enraged"]:
			e[key] = false
	say("%s → %s：%d%sダメージ%s" % [a.name, e.name, value, data.ename[element], "（弱点）" if e.weak == element else ""])
	return value


func hit(m: Dictionary, amount: float) -> void:
	if m.role == "hero" and m.hp / m.maxHp <= 0.3:
		amount = ceil(amount * (0.55 if talent_effect(m, "unyieldingBoost") else 0.75))
	if m.guarding:
		amount = ceil(amount * (0.4 if party_talent("priest", "guardSupport") else 0.5))
		m.guarding = false
		m.limit = minf(100, m.limit + party_talent("hero", "guardLimitBoost"))
	amount = ceil(amount * (1 - talent_effect(m, "damageResist")))
	amount = maxi(1, roundi(amount - m.defense * 0.25))
	m.hp -= amount
	add_limit(m, 12)
	say("%sは%dダメージ。" % [m.name, amount])


func heal_member(m: Dictionary, amount: float) -> void:
	m.hp = minf(m.maxHp, m.hp + roundi(amount))
	m.limit = minf(100, m.limit + 4)
	say("%sが%d回復。" % [m.name, roundi(amount)])


func stun(e: Dictionary) -> void:
	e.stun = maxi(int(e.stun), 1)
	e.intent = {"kind": "stun", "label": "行動不能", "warn": false}


func consume_charge(a: Dictionary) -> void:
	a.charge = 0


func need_mp(a: Dictionary, amount: int) -> bool:
	# 仮実装: needMp()の定義は未受領。失敗時はMPも行動も消費しない。
	if a.mp < amount:
		say("MPが足りません。")
		return false
	return true


func use_skill(id: String) -> bool:
	var a = actor()
	var definition: Dictionary = {}
	for candidate in data.skills[a.role]:
		if candidate.id == id:
			definition = candidate
	if definition.is_empty() or id not in AVAILABLE_SKILLS:
		return false
	# 仮実装: レベル制限の接続は未受領。原資料のlvを使用条件にする。
	if a.level < definition.lv:
		return false
	var cost = mp_cost(a, definition.mp)
	if not need_mp(a, cost):
		return false
	var e = enemy_target()
	a.mp -= cost
	skill_mode = true
	say("%sの%s！" % [a.name, definition.name])
	match id:
		"heroSlash":
			damage(e, roundi((a.attack + random_int(12, 18) + a.level * 2 - e.defense) * (1 + talent_effect(a, "heroSlashBoost"))), a, "holy")
			a.guarding = true
		"quickSlash":
			damage(e, a.attack + random_int(5, 10) + a.level - e.defense, a)
			add_limit(a, 5)
		"guardStrike":
			damage(e, a.attack + random_int(7, 12) + a.level - e.defense, a)
			heal_member(a, random_int(10, 18) + a.level * 2)
		"cover":
			for m in alive_party():
				m.guarding = true
				if talent_effect(a, "coverBoost"):
					m.limit = minf(100, m.limit + 6)
		"shieldBash":
			damage(e, a.attack + random_int(8, 14) + a.level - e.defense, a)
			if _roll() < 0.35:
				stun(e)
		"windSlash":
			for target in alive_enemies():
				damage(target, a.attack + random_int(5, 10) + a.level - target.defense, a, "wind")
		"rally":
			for m in alive_party():
				m.limit = minf(100, m.limit + 20 + talent_effect(a, "rallyBoost"))
				m.guarding = true
		"braveStrike":
			damage(e, a.attack + random_int(18, 28) + roundi(maxf(0, 1 - a.hp / a.maxHp) * 32) + a.level * 2 - e.defense, a, "holy")
		"gigaSlash":
			damage(e, roundi((a.attack + random_int(28, 38) + a.level * 3 - e.defense) * (1 + talent_effect(a, "gigaSlashBoost"))), a, "holy")
		"iceDance":
			for target in alive_enemies():
				damage(target, random_int(13, 20) + a.level * 2, a, "ice")
		"sparkShot":
			damage(e, random_int(12, 18) + a.level, a, "thunder")
		"chillNeedle":
			damage(e, random_int(11, 17) + a.level, a, "ice")
			if _roll() < 0.22:
				stun(e)
		"focus":
			a.charge = 1
		"thunderBolt":
			damage(e, random_int(18, 28) + a.level * 2, a, "thunder")
			if _roll() < 0.30:
				stun(e)
		"fireStorm":
			var bonus = 10 if a.get("charge", 0) else 0
			a.charge = 0
			for target in alive_enemies():
				damage(target, random_int(18, 26) + bonus + a.level, a, "fire")
		"manaBurst":
			for target in alive_enemies():
				damage(target, random_int(16, 24) + a.level * 2, a, "thunder")
			a.mp = minf(a.maxMp, a.mp + 2)
		"frostPrison":
			# 仮補完: 原資料の末尾で途切れたログ・関数終端を補い、確認できる式を使う。
			damage(e, random_int(24, 36) + a.level * 2, a, "ice")
			if _roll() < 0.45 + talent_effect(a, "frostPrisonBoost"):
				stun(e)
	skill_mode = false
	return true


func perform(command: String, id: String = "") -> bool:
	if phase != "party" or alive_party().is_empty() or alive_enemies().is_empty():
		return false
	var a = actor()
	if a.hp <= 0:
		return false
	var e = enemy_target()
	match command:
		"attack":
			var element = "fire" if equipment_effect(a, "fireAttack") and _roll() < equipment_effect(a, "fireAttack") else "physical"
			damage(e, a.attack + random_int(-2, 4) - e.defense, a, element)
		"guard":
			stats.guard = stats.get("guard", 0) + 1
			a.guarding = true
			say("%sは身を守っている。" % a.name)
		"skill":
			if not use_skill(id):
				return false
		"fire", "spark", "heal":
			var base_cost = {"fire": 3, "spark": 6, "heal": 4}[command]
			var cost = mp_cost(a, base_cost)
			if not need_mp(a, cost):
				return false
			a.mp -= cost
			if command == "fire":
				damage(e, random_int(13, 21) + (5 if a.role == "mage" else 0), a, "fire")
			elif command == "spark":
				for target in alive_enemies():
					damage(target, random_int(8, 14) + (4 if a.role == "mage" else 0), a, "thunder")
			else:
				var boost = 1 + equipment_effect(a, "healBoost") + set_bonus(a, "healBoost") + talent_effect(a, "healBoost") + (0.1 if a.role == "priest" else 0)
				heal_member(party[sel_ally], (random_int(20, 30) + (8 if a.role == "priest" else 0)) * boost)
			consume_charge(a)
		"item":
			if not use_item(id):
				return false
		_:
			return false
	_settle_action()
	return true


func use_item(id: String) -> bool:
	# 仮実装: 道具の使用効果は未受領。試遊に必要な回復・蘇生だけを用意。
	if items.get(id, 0) <= 0 or id not in ["herb", "hiHerb", "manaWater", "panacea", "reviveStone"]:
		return false
	var target = party[sel_ally]
	if id == "reviveStone" and target.hp > 0:
		return false
	if id != "reviveStone" and target.hp <= 0:
		return false
	match id:
		"herb": heal_member(target, 25)
		"hiHerb": heal_member(target, 60)
		"manaWater": target.mp = minf(target.maxMp, target.mp + 14)
		"panacea": target.poison = 0
		"reviveStone": target.hp = maxf(1, roundi(target.maxHp * 0.5))
	items[id] -= 1
	say("%sに%sを使用（効果は仮）。" % [target.name, data.itemNames[id]])
	return true


func _settle_action() -> void:
	# 仮実装: 味方を左から各1回、その後敵。失敗したコマンドはここへ来ない。
	if alive_party().is_empty():
		phase = "lost"
		say("パーティが倒れた。最初から、または開発用補給で再開できます。")
		return
	if alive_enemies().is_empty():
		phase = "won"
		_reward()
		return
	for i in range(active + 1, party.size()):
		if party[i].hp > 0:
			active = i
			sel_ally = i
			return
	_enemy_turn()
	if alive_party().is_empty():
		phase = "lost"
		say("パーティが倒れた。")
		return
	active = _first_alive()
	sel_ally = active
	turn += 1
	for enemy in alive_enemies():
		enemy.intent = decide_intent(enemy)


func _first_alive() -> int:
	for i in range(party.size()):
		if party[i].hp > 0:
			return i
	return 0


func _enemy_turn() -> void:
	# 仮実装: 行動予告は移植、実行式・状態異常の持続は元コード未受領。
	for enemy in alive_enemies():
		var living = alive_party()
		if living.is_empty():
			break
		if enemy.stun > 0:
			enemy.stun -= 1
			say("%sは行動不能。" % enemy.name)
			continue
		var intent = enemy.intent
		var target = living[random_int(0, living.size() - 1)]
		for member in living:
			if member.name == intent.get("target", ""):
				target = member
		var action = intent.get("pattern", enemy.skill if intent.kind == "skill" else "attack")
		say("%s：%s（敵行動は仮）" % [enemy.name, intent.label])
		match action:
			"regen":
				enemy.hp = minf(enemy.maxHp, enemy.hp + roundi(enemy.maxHp * 0.2))
			"enemyHeal":
				for other in alive_enemies():
					other.hp = minf(other.maxHp, other.hp + roundi(other.maxHp * 0.12))
			"reflect":
				enemy.reflect = true
			"stoneGuard", "shieldAll":
				# 守備状態の式が未受領のため通常攻撃を仮適用。
				say("この守備行動の効果は未確認。開発版では通常攻撃。")
				hit(target, enemy.attack)
			"howl", "enrage":
				enemy.howled = true
				enemy.enraged = true
				enemy.attack = roundi(enemy.attack * 1.2)
			"bossCharge":
				enemy.charged = true
			"bossSmash":
				enemy.charged = false
				hit(target, enemy.attack * 1.6)
			"snipe":
				living.sort_custom(func(x, y): return x.hp / x.maxHp < y.hp / y.maxHp)
				hit(living[0], enemy.attack * 1.2)
			"doubleAttack":
				for n in range(2):
					if target.hp > 0:
						hit(target, enemy.attack * 0.65)
			"ember", "dragonBreath", "bossTrap", "hellBreath", "darkNova", "starEclipse", "curse":
				for member in alive_party():
					hit(member, enemy.attack * 0.7)
			"manaDrain":
				target.mp = maxf(0, target.mp - 3)
				hit(target, enemy.attack * 0.6)
			"poison":
				hit(target, enemy.attack * 0.8)
				if _roll() >= talent_effect(target, "poisonResist"):
					target.poison = 3
			"lifeDrain":
				hit(target, enemy.attack)
				enemy.hp = minf(enemy.maxHp, enemy.hp + roundi(enemy.attack * 0.3))
			"powerHit":
				hit(target, enemy.attack * 1.3)
			_:
				hit(target, enemy.attack + random_int(-2, 4))
	for member in alive_party():
		if member.poison > 0:
			member.hp -= 3
			member.poison -= 1
			say("%sは毒で3ダメージ（仮）。" % member.name)


func _reward() -> void:
	# 仮実装: 報酬・レベル成長・SP取得・戦後回復の実行部分は未受領。
	var experience = 30 + wave * 10
	for member in party:
		member.exp += experience
		while member.exp >= member.nextExp:
			member.exp -= member.nextExp
			member.level += 1
			member.nextExp = ceil(member.nextExp * 1.4)
			member.maxHp += 6
			member.maxMp += 3
			member.attack += 2
			member.defense += 1
			member.sp += 2
			if member.hp > 0:
				member.hp += 6
		if member.hp > 0:
			member.hp = minf(member.maxHp, member.hp + roundi(member.maxHp * 0.2))
			member.mp = minf(member.maxMp, member.mp + roundi(member.maxMp * (0.2 + talent_effect(member, "manaAfterBattle"))))
	for key in materials:
		materials[key] += maxi(1, roundi(data.diffs[difficulty].reward * (1 + wave / 5.0)))
	say("勝利！ EXP +%d、素材と戦後回復（報酬・成長は仮）。" % experience)


func next_wave() -> bool:
	if phase != "won":
		return false
	wave += 1
	turn = 1
	active = _first_alive()
	sel_ally = active
	sel_enemy = 0
	phase = "party"
	enemies = make_enemies()
	say("第%d階層へ。開発版には最終クリア条件を設定していません。" % wave)
	return true


func developer_supply() -> void:
	# 仮実装: 開発用。元ゲームの報酬や初期値として扱わない。
	for member in party:
		member.level = maxi(8, int(member.level))
		member.hp = member.maxHp
		member.mp = member.maxMp
		member.poison = 0
		member.sp += 15
	for key in materials:
		materials[key] += 20
	for id in ["herb", "manaWater", "reviveStone"]:
		items[id] = items.get(id, 0) + 5
	for definition in data.equipDefs:
		if not inventory.has(definition.id):
			inventory.append(definition.id)
	if phase == "lost":
		phase = "party"
		active = 0
		sel_ally = 0
		for enemy in alive_enemies():
			enemy.intent = decide_intent(enemy)
	say("開発用補給：全快・Lv8以上・SP+15・素材+20・装備追加。すべて仮処理です。")
