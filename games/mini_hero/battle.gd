extends RefCounted

signal changed
signal banner(text: String)
signal effect(target: String, index: int, text: String, kind: String)

var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://games/mini_hero/data.json"))
var rng := RandomNumberGenerator.new()
var clock: SceneTree
var party: Array = []
var enemies: Array = []
var last_enemies: Array = []
var equipment: Array = []
var inventory: Dictionary = {}
var items: Dictionary = {}
var materials: Dictionary = {}
var stats: Dictionary = {}
var quests: Dictionary = {}
var bestiary: Dictionary = {}
var messages: Array = []
var difficulty := "normal"
var wave := 1
var active := 0
var sel_enemy := 0
var sel_ally := 0
var phase := "party"
var busy := false
var preparing := false
var route_chosen := false
var route: Dictionary = {}
var event_kind := ""
var skill_mode := false
var instance_counter := 0

const ROUTES = {
	"safe": {"name":"安全な道","hp":0.9,"atk":0.9,"reward":0.85,"event":0.25,"force":null,"desc":"敵弱め / 報酬少なめ"},
	"danger": {"name":"危険な道","hp":1.25,"atk":1.15,"reward":1.4,"event":0.55,"force":null,"desc":"敵強め / 報酬多め"},
	"mine": {"name":"鉱脈の道","hp":1.05,"atk":1.0,"reward":1.1,"event":0.45,"force":"golem","desc":"魔鉱石+1 / ゴーレム多め"},
	"dragon": {"name":"竜の道","hp":1.18,"atk":1.12,"reward":1.3,"event":0.45,"force":"dragon","desc":"竜素材チャンス / ドラゴン多め"},
	"forest": {"name":"薬草の森","hp":0.95,"atk":0.95,"reward":0.95,"event":0.6,"force":"mushroom","desc":"薬草花+2 / キノコ多め / イベント多め"},
	"ruins": {"name":"亡霊の遺跡","hp":1.12,"atk":1.08,"reward":1.25,"event":0.6,"force":"ghost","desc":"報酬多め / ゴースト多め / 万能薬+1"},
	"treasure": {"name":"宝物庫への道","hp":1.15,"atk":1.1,"reward":1.55,"event":0.7,"force":"mimic","desc":"報酬かなり多め / ミミック多め"},
	"shrine": {"name":"祈りの道","hp":1.0,"atk":1.05,"reward":1.0,"event":0.75,"force":"warlock","desc":"LIMIT上昇 / イベント多め"},
	"storm": {"name":"雷鳴の道","hp":1.1,"atk":1.12,"reward":1.25,"event":0.45,"force":"bat","desc":"魔力水+1 / バット多め / 報酬多め"},
	"crystal": {"name":"水晶洞窟","hp":1.08,"atk":1.05,"reward":1.2,"event":0.5,"force":"crystal","desc":"魔鉱石+1・ぷるゼリー+1 / クリスタル多め"}}


func start(diff: String = "normal") -> void:
	difficulty = diff if data.diffs.has(diff) else "normal"
	rng.randomize()
	equipment = data.equipDefs.duplicate(true)
	party = data.members.duplicate(true)
	for member in party:
		member.equip = {"weapon": null, "armor": null, "accessory": null}
		member.sp = 0
		member.talents = {}
	items = {"herb":4,"hiHerb":1,"manaWater":2,"panacea":1,"reviveStone":0,"trainingBook":1,"powerSeed":0,"guardSeed":0,"lifeFruit":0,"magicFruit":0}
	materials = {"herbFlower":2,"magicOre":1,"slimeJelly":1,"poisonSpore":0,"dragonScale":0}
	inventory.clear()
	quests.clear()
	stats.clear()
	bestiary.clear()
	route = {"name":"通常の道","hp":1.0,"atk":1.0,"reward":1.0,"event":0.35,"force":null}
	route_chosen = false
	wave = 1
	active = 0
	sel_ally = 0
	sel_enemy = 0
	busy = false
	phase = "party"
	preparing = false
	skill_mode = false
	instance_counter = 0
	for id in ["bronzeSword","apprenticeStaff","prayerStaff","ironArmor","magicRobe","lifeRing"]:
		add_equipment(id)
	stats.eqGet = 0
	enemies = make_enemies()
	messages.clear()
	event_kind = ""
	say("難易度：%s / 全部入り完成版で開始！" % data.diffs[difficulty].label, "yellow")
	_changed()


func say(text: String, color: String = "") -> void:
	messages.append({"text": text, "color": color})


func actor() -> Dictionary:
	if party[active].hp <= 0:
		next_active()
	return party[active]


func enemy_target() -> Dictionary:
	if enemies[sel_enemy].hp <= 0:
		sel_enemy = maxi(0, enemies.find_custom(func(e): return e.hp > 0))
	return enemies[sel_enemy]


func next_active() -> void:
	for i in range(1, party.size() + 1):
		var n = (active + i) % party.size()
		if party[n].hp > 0:
			active = n
			sel_ally = n
			return


func pause(ms: int) -> void:
	if clock != null:
		await clock.create_timer(ms / 1000.0).timeout


func _bump(key: String, amount: int = 1) -> void:
	stats[key] = stats.get(key, 0) + amount


func _roll() -> float:
	return rng.randf()

func random_int(low: int, high: int) -> int:
	return mini(high, low + int(floor(_roll() * (high - low + 1))))

func alive_party() -> Array:
	return party.filter(func(m): return m.hp > 0)

func alive_enemies() -> Array:
	return enemies.filter(func(e): return e.hp > 0)

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
		if id == null:
			continue
		total += equipment_def(id).get("effects", {}).get(key, 0)
	return total

func has_equipment(m: Dictionary, base_id: String) -> bool:
	for id in m.get("equip", {}).values():
		if id != null and (id == base_id or equipment_def(id).get("baseId", "") == base_id):
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
	var m = party[index]
	for talent in data.talentDefs[m.role]:
		if talent.id != id:
			continue
		if not can_learn(index, talent):
			say("このスキルはまだ習得できない！", "red")
			return false
		m.sp -= talent.cost
		m.talents[id] = true
		for key in ["attack", "defense", "maxHp", "maxMp"]:
			var amount = talent.effect.get(key, 0)
			m[key] += amount
			if key == "maxHp":
				m.hp += amount
			if key == "maxMp":
				m.mp += amount
		say("%sはスキル「%s」を習得した！" % [m.name, talent.name], "green")
		_changed()
		return true
	return false


func make_equipment(id: String) -> String:
	var base = equipment_def(id)
	if base.is_empty() or id.contains("__"):
		return id
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
	# 日時IDはGodotの連番へ置換。元コードと同じ乱数回数を維持する。
	definition.id = "%s__%d_%d" % [id, instance_counter, random_int(1, 999999)]
	definition.baseId = id
	definition.name = "%s【%s】" % [base.name, affix.name]
	definition.affix = affix.name
	definition.rarity = base.rarity + ("+" if affix.rarity == "SR" else "")
	equipment.append(definition)
	return definition.id


func add_equipment(id: String) -> void:
	var got = make_equipment(id)
	inventory[got] = inventory.get(got, 0) + 1
	_bump("eqGet")
	var e = equipment_def(got)
	var jobs = e.jobs.map(func(j): return {"hero":"勇者","mage":"魔法使い","priest":"僧侶"}[j])
	say("装備「%s」を入手！ 装備可能:%s" % [e.name, " / ".join(jobs)], "green")
	banner.emit("装備入手：" + e.name)


func apply_equipment(m: Dictionary, e: Dictionary, sign_value: int) -> void:
	for key in e.stats:
		m[key] = m.get(key, 0) + e.stats[key] * sign_value
	m.hp = minf(m.hp, m.maxHp)
	m.mp = minf(m.mp, m.maxMp)


func equip(index: int, id: String) -> bool:
	if index < 0 or index >= party.size():
		return false
	var m = party[index]
	var e = equipment_def(id)
	if e.is_empty() or not e.jobs.has(m.role) or inventory.get(id, 0) <= 0:
		return false
	var old = m.equip[e.slot]
	if old != null:
		apply_equipment(m, equipment_def(old), -1)
		inventory[old] = inventory.get(old, 0) + 1
	inventory[id] -= 1
	m.equip[e.slot] = id
	apply_equipment(m, e, 1)
	say("%sは「%s」を装備！" % [m.name, e.name], "blue")
	_changed()
	return true


func unequip(index: int, slot: String) -> void:
	var m = party[index]
	var old = m.equip[slot]
	if old == null:
		return
	apply_equipment(m, equipment_def(old), -1)
	inventory[old] = inventory.get(old, 0) + 1
	m.equip[slot] = null
	_changed()


func can_craft(recipe: Dictionary) -> bool:
	for key in recipe.cost:
		if materials.get(key, 0) < recipe.cost[key]:
			return false
	return true


func craft(id: String, is_equipment: bool = false) -> bool:
	for recipe in (data.equipRecipes if is_equipment else data.recipes):
		if recipe.id != id:
			continue
		if not can_craft(recipe):
			say("装備クラフトの素材が足りない！" if is_equipment else "素材が足りない！", "red")
			return false
		for key in recipe.cost:
			materials[key] -= recipe.cost[key]
		if is_equipment:
			add_equipment(id)
			_bump("eqCraft")
		else:
			reward_item(id, int(recipe.make))
			_bump("craft")
			say("%sを%d個クラフト！" % [recipe.name, recipe.make], "green")
		_changed()
		return true
	return false


func make_enemies() -> Array:
	var pool = data.enemyBase.duplicate(true)
	if route.force != null:
		var forced = pool.filter(func(e): return e.type == route.force)
		if not forced.is_empty():
			pool = forced + pool
	var bases: Array = []
	if wave == 1:
		for kind in ["slime", "ghost", "golem"]:
			bases.append(pool.filter(func(e): return e.type == kind)[0])
	else:
		if wave % 5 == 0:
			bases.append(data.bossBase[mini(int(wave / 5), data.bossBase.size()) - 1])
		while bases.size() < 3 and not pool.is_empty():
			bases.append(pool.pop_at(random_int(0, pool.size() - 1)))
	var made: Array = []
	var diff = data.diffs[difficulty]
	for i in range(bases.size()):
		var e = bases[i].duplicate(true)
		var boss = e.type.begins_with("boss")
		e.weak = data.profiles[e.type][0]
		e.resist = data.profiles[e.type][1]
		e.isBoss = boss
		e.name = "%s%s Lv.%d" % [e.base, "" if boss else " " + char(65 + i), wave]
		e.maxHp = roundi((e.hp + (wave - 1) * 8 + (wave * 8 if boss else 0)) * diff.hp * route.hp * data.enemyPower)
		e.hp = e.maxHp
		e.attack = roundi((e.attack + (wave - 1) * 1.4) * diff.atk * route.atk * data.enemyPower)
		e.defense += floor(wave / 4.0)
		e.stun = 0
		for key in ["guarded", "reflect", "howled", "charged"]:
			e[key] = false
		e.intentFlash = true
		e.intent = null
		made.append(e)
	for e in made:
		e.intent = decide_intent(e)
	last_enemies = made.duplicate(true)
	return made


func alive_target() -> Dictionary:
	var living = alive_party()
	return living[random_int(0, living.size() - 1)] if not living.is_empty() else {}


func weakest_party() -> Dictionary:
	var living = alive_party()
	living.sort_custom(func(x, y): return x.hp / x.maxHp < y.hp / y.maxHp)
	return living[0] if not living.is_empty() else {}


func lowest_def_party() -> Dictionary:
	var living = alive_party()
	living.sort_custom(func(x, y): return x.defense < y.defense)
	return living[0] if not living.is_empty() else {}


func special_label(e: Dictionary) -> String:
	if e.stun > 0:
		return "❄️ 行動不能"
	return {"regen":"💚 自己回復","doubleAttack":"⚔️ 強撃・二連撃","ember":"🔥 強化・全体火の粉","dragonBreath":"🔥 強化・全体ブレス","stoneGuard":"🛡️ 防御アップ","reflect":"💎 反射状態","poison":"🍄 毒攻撃","howl":"🐺 遠吠え","manaDrain":"🔮 MP吸収","bossTrap":"⚠️ 強化・大罠","hellBreath":"⚠️ 強化・灼熱ブレス","darkNova":"⚠️ 強化・闇の大技","starEclipse":"⚠️ 超危険・星蝕の大技"}.get(e.skill, "特殊行動")


func pattern_label(pattern: String) -> String:
	return {"powerHit":"💢 渾身の一撃","snipe":"🎯 弱った相手を狙う","lifeDrain":"🩸 生命吸収","enemyHeal":"💚 仲間を回復","shieldAll":"🛡️ 敵全体を守る","enrage":"🔥 怒りで攻撃UP","curse":"🌑 呪いの波動","bossCharge":"⚠️ 力をためる","bossSmash":"💥 溜め大技"}.get(pattern, "特殊パターン")


func can_special(e: Dictionary) -> bool:
	if e.stun > 0:
		return true
	match e.skill:
		"regen": return e.hp < e.maxHp * 0.7
		"stoneGuard": return not e.guarded
		"reflect": return not e.reflect
		"poison": return alive_party().any(func(m): return m.poison <= 0)
		"howl": return not e.howled
		"manaDrain": return alive_party().any(func(m): return m.mp > 0)
	return true


func decide_intent(e: Dictionary) -> Variant:
	if e.hp <= 0:
		return null
	if e.stun > 0:
		return {"kind":"skill", "label":special_label(e), "warn":false}
	if e.charged:
		return {"kind":"pattern", "pattern":"bossSmash", "label":pattern_label("bossSmash"), "warn":true}
	var patterns: Array = []
	if e.isBoss:
		patterns.append("bossCharge")
		if e.charged:
			patterns.append("bossSmash")
	if e.hp < e.maxHp * 0.45 and not e.get("enraged", false):
		patterns.append("enrage")
	if alive_enemies().any(func(x): return x.hp > 0 and x.hp < x.maxHp * 0.55):
		patterns.append("enemyHeal")
	if not e.get("shielded", false) and alive_enemies().size() >= 2:
		patterns.append("shieldAll")
	if alive_party().any(func(m): return m.hp / m.maxHp < 0.45):
		patterns.append("snipe")
	if e.type in ["warlock", "ghost", "boss_demon"]:
		patterns.append_array(["curse", "lifeDrain"])
	if e.type in ["wolf", "mimic", "boss_mimic", "dragon", "boss_dragon", "boss_star_dragon"]:
		patterns.append("powerHit")
	if not patterns.is_empty() and _roll() < (0.32 if e.isBoss else 0.22):
		var pattern = patterns[random_int(0, patterns.size() - 1)]
		return {"kind":"pattern", "pattern":pattern, "label":pattern_label(pattern), "warn":pattern in ["powerHit","snipe","lifeDrain","curse","bossCharge","bossSmash"]}
	if can_special(e) and _roll() < (0.45 if e.isBoss else 0.30):
		return {"kind":"skill", "label":special_label(e), "warn":e.isBoss or e.skill in ["dragonBreath","ember","doubleAttack","poison"]}
	var target = alive_target()
	var name_text = target.get("name", "")
	return {"kind":"attack", "target":name_text, "label":"⚔️ %sを攻撃" % name_text if not target.is_empty() else "⚔️ 通常攻撃", "warn":false}


func assign_enemy_intents() -> void:
	var first = ""
	for e in enemies:
		if e.hp <= 0:
			e.intent = null
			continue
		var old = e.intent.label if e.intent != null else ""
		e.intent = decide_intent(e)
		e.intentFlash = old != e.intent.label
		if e.intentFlash and e.intent.warn and first.is_empty():
			first = "%s：%s" % [e.name, e.intent.label]
	if not first.is_empty():
		banner.emit(first)


func element_damage(e: Dictionary, element: String, amount: float, a: Dictionary) -> int:
	amount *= 1 + equipment_effect(a, element + "Boost") + set_bonus(a, element + "Boost") + talent_effect(a, element + "Boost")
	if element == "fire":
		amount *= 1 + talent_effect(a, "fireSpellBoost")
	if a.get("charge", 0):
		amount *= 1 + talent_effect(a, "focusBoost")
	if element == "ice" and talent_effect(a, "iceWall"):
		for m in alive_party():
			m.guarding = true
		say("氷の壁！ 味方全員が防御状態！", "blue")
	if element == "ice" and talent_effect(a, "iceChase"):
		var extra = maxi(3, roundi(amount * 0.12))
		e.hp -= extra
		say("凍結追撃！ %d追加ダメージ！" % extra, "blue")
	if e.weak == element:
		amount *= 1.5
		_bump("weak")
		say("弱点！ %sが効いた！" % data.ename[element], "yellow")
		if a.role == "mage":
			var gain = 2 + talent_effect(a, "weakMpGain")
			a.mp = minf(a.maxMp, a.mp + gain)
			say("属性研究：MPが%d回復！" % gain, "blue")
		if talent_effect(a, "weakChase"):
			var extra = maxi(3, roundi(amount * 0.15))
			e.hp -= extra
			say("弱点追撃！ %d追加ダメージ！" % extra, "yellow")
	if e.resist == element:
		amount *= 0.6
	return maxi(1, roundi(amount))


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
		say("会心！", "yellow")
	if e.reflect:
		e.reflect = false
		var reflected = maxi(1, roundi(value * 0.35))
		say("%sの反射！ %sに%d反射ダメージ！" % [e.name, a.name, reflected], "purple")
		hit(a, reflected)
	e.hp -= value
	effect.emit("enemy", enemies.find(e), "%d%s" % [value, " 弱点!" if e.weak == element else ""], "crit" if value >= 35 else "damage")
	if value >= 35:
		effect.emit("screen", 0, "", "shake")
	add_limit(a, 8)
	if element == "thunder" and _roll() < talent_effect(a, "thunderStun"):
		stun(e)
		say("%sは雷撃干渉でしびれた！" % e.name, "blue")
	if element == "holy" and _roll() < talent_effect(a, "purify"):
		for key in ["guarded", "reflect", "shielded", "enraged"]:
			e[key] = false
		say("%sの強化を浄化した！" % e.name, "blue")
	return value


func hit(m: Dictionary, amount: float) -> void:
	if m.is_empty():
		return
	if m.role == "hero" and m.hp / m.maxHp <= 0.3:
		amount = ceil(amount * (0.55 if talent_effect(m, "unyieldingBoost") else 0.75))
		say("勇者の不屈！", "blue")
	if m.guarding:
		amount = ceil(amount * (0.4 if party_talent("priest", "guardSupport") else 0.5))
		m.guarding = false
		m.limit = minf(100, m.limit + party_talent("hero", "guardLimitBoost"))
		say("%sは防御で軽減！" % m.name, "blue")
	amount = ceil(amount * (1 - talent_effect(m, "damageResist")))
	amount = maxi(1, roundi(amount - m.defense * 0.25))
	m.hp -= amount
	effect.emit("ally", party.find(m), str(int(amount)), "crit" if amount >= 25 else "damage")
	if amount >= 25:
		effect.emit("screen", 0, "", "shake")
	add_limit(m, 12)
	say("%sは%dダメージ" % [m.name, amount], "red")


func heal_member(m: Dictionary, amount: float) -> void:
	amount = roundi(amount)
	m.hp = minf(m.maxHp, m.hp + amount)
	effect.emit("ally", party.find(m), "+%d" % amount, "heal")
	m.limit = minf(100, m.limit + 4)
	say("%sが%d回復" % [m.name, amount], "green")


func stun(e: Dictionary) -> void:
	e.stun = maxi(int(e.stun), 1)
	e.intent = {"kind":"stun", "label":"❄️ 行動不能", "warn":false}


func consume_charge(a: Dictionary) -> void:
	if a.get("charge", 0):
		a.charge = 0
		say("魔力集中が解けた。", "blue")


func need_mp(a: Dictionary, amount: int) -> bool:
	if a.mp < amount:
		say("%sはMPが足りない！ 必要MP:%d / 現在MP:%d" % [a.name, amount, a.mp], "red")
		return false
	return true


func use_skill(id: String) -> bool:
	var a = actor()
	var e = enemy_target()
	var matches = data.skills[a.role].filter(func(s): return s.id == id)
	if matches.is_empty():
		return false
	if id == "revive" and not party.any(func(m): return m.hp <= 0):
		say("復活させる仲間がいない！", "red")
		return false
	var cost = mp_cost(a, matches[0].mp)
	if not need_mp(a, cost):
		return false
	a.mp -= cost
	skill_mode = true
	match id:
		"heroSlash":
			var base = a.attack + random_int(12, 18) + a.level * 2 - e.defense
			var d = damage(e, roundi(base * (1 + talent_effect(a, "heroSlashBoost"))), a, "holy")
			say("%sに%dダメージ。勇者は防御！" % [e.name, d], "yellow")
			a.guarding = true
		"quickSlash":
			var d = damage(e, a.attack + random_int(5, 10) + a.level - e.defense, a)
			add_limit(a, 5)
			say("%sに%d素早いダメージ！ LIMITが少し上昇！" % [e.name, d], "yellow")
		"guardStrike":
			var d = damage(e, a.attack + random_int(7, 12) + a.level - e.defense, a)
			heal_member(a, random_int(10, 18) + a.level * 2)
			say("%sに%dダメージ！ 勇者はHPを回復した！" % [e.name, d], "yellow")
		"cover":
			for m in alive_party():
				m.guarding = true
				if talent_effect(a, "coverBoost"):
					m.limit = minf(100, m.limit + 6)
			say("全員が強固な防御状態！ LIMITも上昇！" if talent_effect(a, "coverBoost") else "全員が防御状態！", "blue")
		"shieldBash":
			var d = damage(e, a.attack + random_int(8, 14) + a.level - e.defense, a)
			var stopped = _roll() < 0.35
			if stopped:
				stun(e)
			say("%sに%dダメージ！%s" % [e.name, d, " 行動遅延成功！ 次の行動を1回スキップ！" if stopped else ""], "yellow")
		"windSlash":
			for x in alive_enemies():
				var d = damage(x, a.attack + random_int(5, 10) + a.level - x.defense, a, "wind")
				say("%sに%d風ダメージ" % [x.name, d], "yellow")
		"rally":
			var plus = 20 + talent_effect(a, "rallyBoost")
			for m in alive_party():
				m.limit = minf(100, m.limit + plus)
				m.guarding = true
			say("勇気の号令！ 全員のLIMITが%d上昇、防御状態！" % plus, "blue")
		"braveStrike":
			var bonus = roundi(maxf(0, 1 - a.hp / a.maxHp) * 32)
			var d = damage(e, a.attack + random_int(18, 28) + bonus + a.level * 2 - e.defense, a, "holy")
			say("%sに%d背水ダメージ！" % [e.name, d], "yellow")
		"gigaSlash":
			var base = a.attack + random_int(28, 38) + a.level * 3 - e.defense
			var d = damage(e, roundi(base * (1 + talent_effect(a, "gigaSlashBoost"))), a, "holy")
			say("%sに%d超ダメージ！" % [e.name, d], "yellow")
		"iceDance":
			for x in alive_enemies():
				var d = damage(x, random_int(13, 20) + a.level * 2, a, "ice")
				say("%sに%d氷ダメージ" % [x.name, d], "blue")
		"sparkShot":
			var d = damage(e, random_int(12, 18) + a.level, a, "thunder")
			say("%sに%d雷ダメージ！" % [e.name, d], "yellow")
		"chillNeedle", "thunderBolt", "frostPrison":
			var element = "thunder" if id == "thunderBolt" else "ice"
			var low = {"chillNeedle":11,"thunderBolt":18,"frostPrison":24}[id]
			var high = {"chillNeedle":17,"thunderBolt":28,"frostPrison":36}[id]
			var d = damage(e, random_int(low, high) + a.level * (1 if id == "chillNeedle" else 2), a, element)
			var chance = {"chillNeedle":0.22,"thunderBolt":0.3,"frostPrison":0.45 + talent_effect(a, "frostPrisonBoost")}[id]
			var stopped = _roll() < chance
			if stopped:
				stun(e)
			var suffix = {"chillNeedle":" 冷気で行動を遅らせた！","thunderBolt":" しびれて次の行動を1回スキップ！","frostPrison":" 行動を封じた！ 次の行動を1回スキップ！"}[id] if stopped else ""
			say("%sに%d%sダメージ！%s" % [e.name, d, data.ename[element], suffix], "yellow" if id == "thunderBolt" else "blue")
		"focus":
			a.charge = 1
			say("次の魔法を強化！", "blue")
		"fireStorm":
			var bonus = 10 if a.get("charge", 0) else 0
			a.charge = 0
			for x in alive_enemies():
				var d = damage(x, random_int(18, 26) + bonus + a.level, a, "fire")
				say("%sに%d炎ダメージ" % [x.name, d], "yellow")
		"manaBurst":
			for x in alive_enemies():
				var d = damage(x, random_int(16, 24) + a.level * 2, a, "thunder")
				say("%sに%d魔力ダメージ" % [x.name, d], "yellow")
			a.mp = minf(a.maxMp, a.mp + 2)
		"meteor":
			for x in alive_enemies():
				var d = damage(x, roundi((random_int(24, 34) + a.level * 2) * (1 + talent_effect(a, "meteorBoost"))), a)
				say("%sに%d隕石ダメージ" % [x.name, d], "yellow")
		"partyHeal":
			for m in alive_party():
				heal_member(m, (random_int(16, 24) + a.level * 2) * (1 + talent_effect(a, "partyHealBoost") + talent_effect(a, "healBoost")))
		"lightSmite":
			var d = damage(e, random_int(10, 16) + a.level + a.attack * 0.5, a, "holy")
			say("%sに%d聖ダメージ！" % [e.name, d], "yellow")
		"miniHealAll":
			for m in alive_party():
				heal_member(m, (random_int(8, 13) + a.level) * (1 + talent_effect(a, "healBoost")))
			say("小さな祈りが仲間を包んだ。", "green")
		"cleanse":
			for m in alive_party():
				m.poison = 0
				heal_member(m, random_int(6, 12) + a.level)
		"barrier":
			for m in alive_party():
				m.guarding = true
				heal_member(m, (random_int(5, 10) + a.level) * (1 + talent_effect(a, "healBoost")))
				if talent_effect(a, "barrierBoost"):
					m.limit = minf(100, m.limit + 8)
			say("強化された聖なる結界！" if talent_effect(a, "barrierBoost") else "聖なる結界！", "blue")
		"bigHeal":
			party[sel_ally].poison = 0
			heal_member(party[sel_ally], (random_int(35, 50) + a.level * 3) * (1 + talent_effect(a, "bigHealBoost") + talent_effect(a, "healBoost")))
		"holyLight":
			for x in alive_enemies():
				var d = damage(x, roundi((random_int(13, 21) + a.level * 2) * (1 + talent_effect(a, "holyLightBoost"))), a, "holy")
				say("%sに%d聖ダメージ" % [x.name, d], "yellow")
			for m in alive_party():
				heal_member(m, random_int(5, 10) + a.level)
		"blessing":
			for m in alive_party():
				m.poison = 0
				m.limit = minf(100, m.limit + 18)
				heal_member(m, random_int(8, 14) + a.level)
			say("祝福！ 毒を払いLIMIT上昇！", "green")
		"revive":
			var dead = party.filter(func(m): return m.hp <= 0)[0]
			dead.hp = ceil(dead.maxHp * (0.45 + talent_effect(a, "reviveBoost")))
			dead.mp = ceil(dead.maxMp * 0.25)
			say("%sが復活！" % dead.name, "green")
	skill_mode = false
	return true


func use_limit(id: String) -> bool:
	var a = actor()
	var e = enemy_target()
	if not data.limits[a.role].any(func(li): return li.id == id):
		return false
	_bump("limit")
	banner.emit("%sのLIMIT!" % a.name)
	effect.emit("screen", 0, "", "holyWash")
	effect.emit("screen", 0, "", "shake")
	a.limit = 0
	if talent_effect(a, "limitChain"):
		for m in alive_party():
			if m != a:
				m.limit = minf(100, m.limit + 12)
	match id:
		"limitHeroBlade":
			var base = a.attack + random_int(52, 76) + a.level * 5 - e.defense
			var d = damage(e, roundi(base * (1 + talent_effect(a, "gigaSlashBoost"))), a, "holy")
			say("%sに%d必殺ダメージ！" % [e.name, d], "yellow")
			for m in alive_party():
				m.guarding = true
		"limitFortress":
			for m in alive_party():
				m.guarding = true
				heal_member(m, random_int(18, 28) + a.level * 2)
				m.limit = minf(100, m.limit + 10)
		"limitJudgement":
			for x in alive_enemies():
				var d = damage(x, random_int(28, 42) + a.attack + a.level * 3, a, "holy")
				say("%sに%d裁きの光！" % [x.name, d], "yellow")
		"limitMegaFlare", "limitManaOverdrive":
			for x in alive_enemies():
				var fire_mode = id == "limitMegaFlare"
				var d = damage(x, random_int(42 if fire_mode else 32, 62 if fire_mode else 50) + a.level * (4 if fire_mode else 3), a, "fire" if fire_mode else "thunder")
				say("%sに%d%sの必殺ダメージ！" % [x.name, d, "炎" if fire_mode else "雷"], "yellow")
			if id == "limitManaOverdrive":
				a.mp = minf(a.maxMp, a.mp + ceil(a.maxMp * 0.35))
		"limitTimeFreeze":
			var stopped = 0
			for x in alive_enemies():
				var d = damage(x, random_int(28, 44) + a.level * 3, a, "ice")
				say("%sに%d氷の必殺ダメージ！" % [x.name, d], "blue")
				if _roll() < 0.35 + talent_effect(a, "timeFreezeBoost"):
					x.stun = maxi(x.stun, 1)
					stopped += 1
			say("時凍結界！ %d体を封じた！" % stopped if stopped > 0 else "行動阻害は入らなかった。", "blue")
		"limitMiracle":
			for m in party:
				if m.hp <= 0:
					m.hp = ceil(m.maxHp * (0.45 + talent_effect(a, "reviveBoost")))
				m.poison = 0
				heal_member(m, (random_int(35, 55) + a.level * 3) * (1 + talent_effect(a, "healBoost")))
		"limitSanctuary":
			for m in party:
				if m.hp <= 0:
					m.hp = ceil(m.maxHp * 0.25)
				m.poison = 0
				m.guarding = true
				heal_member(m, random_int(24, 38) + a.level * 2)
				m.limit = minf(100, m.limit + 12)
		"limitHolyNova":
			for x in alive_enemies():
				var d = damage(x, roundi((random_int(24, 38) + a.level * 3) * (1 + talent_effect(a, "holyNovaBoost"))), a, "holy")
				say("%sに%d聖なる爆発！" % [x.name, d], "yellow")
			for m in alive_party():
				heal_member(m, (random_int(14, 24) + a.level * 2) * (1 + talent_effect(a, "healBoost")))
	return true


func use_item(id: String) -> bool:
	if items.get(id, 0) <= 0:
		return false
	if id == "reviveStone" and not party.any(func(m): return m.hp <= 0):
		say("復活させる仲間がいない！", "red")
		return false
	var t = party[sel_ally]
	items[id] -= 1
	_bump("itemUse")
	if id == "trainingBook":
		_bump("bookUse")
	match id:
		"herb": heal_member(t, 25)
		"hiHerb": heal_member(t, 55)
		"manaWater":
			t.mp = minf(t.maxMp, t.mp + 18)
			say("%sのMP回復" % t.name, "blue")
		"panacea":
			t.poison = 0
			heal_member(t, 15)
		"reviveStone":
			var dead = party.filter(func(m): return m.hp <= 0)[0]
			dead.hp = ceil(dead.maxHp * 0.5)
			say("%sが復活！" % dead.name, "green")
		"trainingBook":
			t.sp += 1
			say("%sは修練の書でSPを1獲得した！" % t.name, "blue")
		"powerSeed":
			t.attack += 1
			say("%sの攻撃+1" % t.name, "yellow")
		"guardSeed":
			t.defense += 1
			say("%sの防御+1" % t.name, "blue")
		"lifeFruit":
			t.maxHp += 5
			t.hp += 5
			say("%sの最大HP+5" % t.name, "green")
		"magicFruit":
			t.maxMp += 3
			t.mp += 3
			say("%sの最大MP+3" % t.name, "blue")
	return true


func command_effect(command: String, id: String = "") -> bool:
	var a = actor()
	var e = enemy_target()
	match command:
		"attack":
			var element = "fire" if equipment_effect(a, "fireAttack") and _roll() < equipment_effect(a, "fireAttack") else "physical"
			var d = damage(e, a.attack + random_int(-2, 4) - e.defense, a, element)
			say("%sの攻撃！ %sに%dダメージ！" % [a.name, e.name, d], "yellow")
		"guard":
			_bump("guard")
			a.guarding = true
			say("%sは身を守っている" % a.name, "blue")
		"skill": return use_skill(id)
		"limit": return use_limit(id)
		"item": return use_item(id)
		"fire", "spark", "heal":
			var cost = mp_cost(a, {"fire":3,"spark":6,"heal":4}[command])
			if not need_mp(a, cost):
				return false
			a.mp -= cost
			effect.emit("screen", 0, "", "holyWash" if command == "heal" else "magicWash")
			if command == "fire":
				var d = damage(e, random_int(13, 21) + (5 if a.role == "mage" else 0), a, "fire")
				say("%sに%d炎ダメージ！" % [e.name, d], "yellow")
			elif command == "spark":
				for target in alive_enemies():
					var d = damage(target, random_int(8, 14) + (4 if a.role == "mage" else 0), a, "thunder")
					say("%sに%d雷ダメージ" % [target.name, d], "yellow")
			else:
				var boost = 1 + equipment_effect(a, "healBoost") + set_bonus(a, "healBoost") + talent_effect(a, "healBoost") + (0.1 if a.role == "priest" else 0)
				heal_member(party[sel_ally], (random_int(20, 30) + (8 if a.role == "priest" else 0)) * boost)
			consume_charge(a)
		_: return false
	return true


func perform(command: String, id: String = "") -> bool:
	if busy or phase != "party":
		return false
	busy = true
	_changed()
	var acting = actor()
	if not command_effect(command, id):
		busy = false
		_changed()
		return false
	if acting.poison > 0 and acting.hp > 0:
		var d = random_int(3, 5)
		acting.hp -= d
		acting.poison -= 1
		say("%sは毒で%dダメージ！" % [acting.name, d], "red")
	_changed()
	if alive_enemies().is_empty():
		win()
		return true
	if alive_party().is_empty():
		lose()
		return true
	await pause(160)
	var round_end = not alive_party().any(func(m): return party.find(m) > active)
	next_active()
	if round_end:
		await enemy_phase()
	if alive_party().is_empty():
		lose()
	else:
		busy = false
		_changed()
	return true


func enemy_skill(e: Dictionary) -> bool:
	if e.stun > 0:
		e.stun -= 1
		say("%sは動けない！" % e.name, "blue")
		return true
	var t = alive_target()
	match e.skill:
		"regen":
			if e.hp < e.maxHp * 0.7:
				var h = random_int(6, 12 + wave)
				e.hp = minf(e.maxHp, e.hp + h)
				say("%sが%d回復！" % [e.name, h], "green")
				return true
		"doubleAttack":
			for i in range(2):
				var living = alive_party()
				if not living.is_empty():
					hit(living[random_int(0, living.size() - 1)], ceil(e.attack * 0.9) + random_int(0, 3))
			return true
		"ember", "dragonBreath":
			var d = (random_int(11, 20) if e.skill == "dragonBreath" else random_int(9, 17)) + floor(wave / 2.0)
			for m in alive_party():
				hit(m, d)
			return true
		"stoneGuard":
			if not e.guarded:
				e.defense += 2
				e.guarded = true
				say("%sの防御UP！" % e.name, "blue")
				return true
		"reflect":
			if not e.reflect:
				e.reflect = true
				say("%sは反射状態！" % e.name, "blue")
				return true
		"poison":
			if t.poison <= 0:
				if _roll() < party_talent("priest", "poisonResist"):
					say("%sは加護で毒を防いだ！" % t.name, "blue")
					return true
				t.poison = 3
				say("%sは毒を受けた！" % t.name, "red")
				return true
		"howl":
			if not e.howled:
				e.howled = true
				for x in alive_enemies():
					x.attack += 2
				say("敵全体の攻撃UP！", "red")
				return true
		"manaDrain":
			var mp = minf(t.mp, random_int(4, 8))
			t.mp -= mp
			e.hp = minf(e.maxHp, e.hp + mp * 2)
			say("%sのMPを%d奪った！" % [t.name, mp], "blue")
			return true
	return false


func enemy_pattern(e: Dictionary, pattern: String) -> bool:
	match pattern:
		"powerHit":
			hit(lowest_def_party(), ceil(e.attack * 1.65) + random_int(2, 6))
			say("%sの渾身の一撃！" % e.name, "red")
		"snipe":
			var t = weakest_party()
			hit(t, ceil(e.attack * 1.25) + random_int(2, 5))
			say("%sは弱った%sを狙った！" % [e.name, t.name], "red")
		"lifeDrain":
			var t = alive_target()
			var before = t.hp
			hit(t, ceil(e.attack * 1.05) + random_int(1, 4))
			var h = maxf(4, ceil((before - maxf(0, t.hp)) * 0.6))
			e.hp = minf(e.maxHp, e.hp + h)
			say("%sは生命を吸収して%d回復！" % [e.name, h], "red")
		"enemyHeal":
			var living = alive_enemies()
			living.sort_custom(func(a, b): return a.hp / a.maxHp < b.hp / b.maxHp)
			var t = living[0]
			var h = random_int(10, 18) + floor(wave / 2.0)
			t.hp = minf(t.maxHp, t.hp + h)
			say("%sは%sを%d回復！" % [e.name, t.name, h], "green")
		"shieldAll":
			for x in alive_enemies():
				x.defense += 1
			e.shielded = true
			say("%sの号令！ 敵全体の防御UP！" % e.name, "blue")
		"enrage":
			e.attack += 3
			e.enraged = true
			say("%sは怒りで攻撃力UP！" % e.name, "red")
		"curse":
			for m in alive_party():
				m.mp -= minf(m.mp, random_int(2, 5))
				hit(m, random_int(3, 7) + floor(wave / 3.0))
			say("%sの呪いの波動！" % e.name, "red")
		"bossCharge":
			e.charged = true
			say("%sは力をためている……次に注意！" % e.name, "red")
		"bossSmash":
			e.charged = false
			for m in alive_party():
				hit(m, random_int(24, 38) + floor(wave / 2.0))
			say("%sの溜め大技！" % e.name, "red")
		_: return false
	return true


func boss_intent(e: Dictionary) -> bool:
	var low = {"bossTrap":16,"hellBreath":22,"darkNova":28,"starEclipse":34}
	var high = {"bossTrap":26,"hellBreath":34,"darkNova":42,"starEclipse":52}
	if not low.has(e.skill):
		return false
	for m in alive_party():
		hit(m, random_int(low[e.skill], high[e.skill]) + floor(wave * (0.75 if e.skill == "starEclipse" else 0.5)))
		if e.skill == "starEclipse":
			m.mp = maxf(0, m.mp - random_int(4, 9))
			if _roll() < 0.35 and m.poison <= 0:
				m.poison = 2
				say("%sは星毒を受けた！" % m.name, "red")
	if e.skill == "starEclipse":
		e.hp = minf(e.maxHp, e.hp + ceil(e.maxHp * 0.06))
	var suffix = {"bossTrap":"大罠が発動！","hellBreath":"灼熱ブレス！","darkNova":"闇の大技！","starEclipse":"星蝕！ 全体大ダメージ、MP減少、さらに自身が回復！"}[e.skill]
	say("%sの%s" % [e.name, suffix], "red")
	return true


func execute_intent(e: Dictionary) -> void:
	if e.stun > 0:
		e.stun -= 1
		e.intent = {"kind":"stun", "label":"❄️ 行動不能", "warn":false}
		say("%sは行動遅延で動けない！" % e.name, "blue")
		return
	var intent = e.intent if e.intent != null else decide_intent(e)
	if intent.kind == "pattern" and enemy_pattern(e, intent.pattern):
		return
	if intent.kind == "skill":
		if boss_intent(e) or enemy_skill(e):
			return
	var named = alive_party().filter(func(m): return m.name == intent.get("target", ""))
	var t = named[0] if not named.is_empty() else alive_target()
	if not t.is_empty():
		hit(t, e.attack + random_int(-1, 3))


func enemy_phase() -> void:
	say("--- 敵のターン ---", "red")
	for e in enemies:
		if e.hp <= 0 or alive_party().is_empty():
			continue
		await pause(160)
		effect.emit("enemy", enemies.find(e), "", "intentAct")
		await pause(350)
		execute_intent(e)
		_changed()
	assign_enemy_intents()
	_changed()


func reward_item(id: String, amount: int) -> void:
	items[id] = items.get(id, 0) + amount


func add_material(id: String, amount: int) -> void:
	materials[id] = materials.get(id, 0) + amount
	say("%sを%d個入手！" % [data.mat[id], amount], "green")


func random_quest_equipment() -> void:
	add_equipment(["lifeRing","manaRing","adventureCharm","sageRing","flameStaff","iceStaff","saintRobe","thunderSword","guardianBlade","stormStaff","saintStaff","focusCharm","luckyCharm"][random_int(0, 12)])


func quest_progress(definition: Dictionary) -> int:
	var expression = definition.progress
	if expression == "wave":
		return wave
	var re = RegEx.new()
	re.compile("(stats|materials)\\.(\\w+)")
	var total = 0
	for found in re.search_all(expression):
		total += int((stats if found.get_string(1) == "stats" else materials).get(found.get_string(2), 0))
	return total


func quest_unlocked(definition: Dictionary) -> bool:
	var requires = definition.get("requires", [])
	if requires is String:
		requires = [requires]
	return requires.all(func(id): return quests.get(id, false))


func unlocked_quests() -> Array:
	return data.quests.filter(quest_unlocked)


func _give(actions: Array) -> void:
	for action in actions:
		match action.kind:
			"item": reward_item(action.id, int(action.amount))
			"material": add_material(action.id, int(action.amount))
			"equipment": add_equipment(action.id)
			"randomEquipment": random_quest_equipment()


func claim_quest(id: String) -> bool:
	var definitions = data.quests.filter(func(q): return q.id == id)
	if definitions.is_empty():
		return false
	var q = definitions[0]
	if quests.get(id, false) or quest_progress(q) < q.goal or not quest_unlocked(q):
		return false
	var before = unlocked_quests().map(func(d): return d.id)
	quests[id] = true
	var reward_text = q.get("reward", "")
	if q.has("randomReward"):
		var total = q.randomReward.reduce(func(sum_value, r): return sum_value + r.get("weight", 1), 0)
		var n = _roll() * total
		var selected = q.randomReward.back()
		for r in q.randomReward:
			n -= r.get("weight", 1)
			if n <= 0:
				selected = r
				break
		_give(selected.give)
		reward_text = selected.text
	else:
		_give(q.give)
	_bump("questClaim")
	say("クエスト「%s」達成！ 報酬:%s" % [q.name, reward_text], "yellow")
	for newly in unlocked_quests():
		if not before.has(newly.id) and not quests.get(newly.id, false):
			say("新クエスト解放：「%s」" % newly.name, "blue")
	_changed()
	return true


func record_book() -> void:
	for e in last_enemies:
		_bump("kills")
		if e.isBoss:
			_bump("boss")
		if e.type == "boss_star_dragon":
			_bump("starDragonBoss")
		if e.type == "slime":
			_bump("slimeKill")
		if e.type in ["dragon", "boss_dragon"]:
			_bump("dragonKill")
		bestiary[e.base] = {"name":e.base,"weak":e.weak,"resist":e.resist,"drops":e.type,"kills":bestiary.get(e.base, {}).get("kills", 0) + 1}


func gain_exp(amount: int) -> void:
	for m in party:
		if m.hp <= 0:
			continue
		m.exp += roundi(amount * data.diffs[difficulty].exp)
		while m.exp >= m.nextExp and m.level < 10:
			m.exp -= m.nextExp
			m.level += 1
			m.maxHp += {"hero":8,"mage":4,"priest":6}[m.role]
			m.maxMp += 6 if m.role == "mage" else 4
			m.attack += 1
			m.defense += 0 if m.role == "mage" else 1
			m.hp = m.maxHp
			m.mp = m.maxMp
			m.nextExp = roundi(m.nextExp * 1.35)
			m.sp += 1
			say("%sはLv.%dに上がった！ スキルポイント+1！" % [m.name, m.level], "green")
			banner.emit("%s LEVEL UP!" % m.name)


func drop_materials() -> void:
	for e in last_enemies:
		if e.type == "slime":
			add_material("slimeJelly", 1)
		if e.type in ["dragon", "boss_dragon"]:
			add_material("dragonScale", 1)
		if _roll() < 0.45 * route.reward:
			add_material(["herbFlower","magicOre","poisonSpore"][random_int(0, 2)], 1)


func reward() -> void:
	for m in alive_party():
		m.hp = minf(m.maxHp, m.hp + ceil(m.maxHp * 0.25))
		m.mp = minf(m.maxMp, m.mp + ceil(m.maxMp * 0.2))
	reward_item("herb", 1)
	drop_materials()
	for m in alive_party():
		if talent_effect(m, "manaAfterBattle"):
			m.mp = minf(m.maxMp, m.mp + ceil(m.maxMp * talent_effect(m, "manaAfterBattle")))
	var db = alive_party().reduce(func(sum_value, m): return sum_value + equipment_effect(m, "dropBoost") + talent_effect(m, "dropBoost"), 0.0)
	if wave % 5 == 0:
		add_equipment(["sageRing","flameStaff","iceStaff","adventureCharm","dragonSlayer","starWand","judgementMace","oracleVestment","heroCape"][random_int(0, 8)])
	elif _roll() < (0.22 + db) * route.reward:
		random_quest_equipment()


func next_is_boss_floor() -> bool:
	return (wave + 1) % 5 == 0


func choose_route(id: String) -> bool:
	if not ROUTES.has(id) or not preparing or route_chosen:
		return false
	route_chosen = true
	_bump("route")
	if id != "safe":
		_bump(id + "Route")
	route = ROUTES[id].duplicate(true)
	route.erase("desc")
	match id:
		"mine": add_material("magicOre", 1)
		"dragon":
			if _roll() < 0.5:
				add_material("dragonScale", 1)
		"forest":
			add_material("herbFlower", 2)
			if _roll() < 0.35:
				add_material("poisonSpore", 1)
		"ruins":
			reward_item("panacea", 1)
			say("万能薬を1個入手！", "green")
		"treasure":
			if _roll() < 0.35:
				random_quest_equipment()
		"shrine":
			for m in alive_party():
				m.limit = minf(100, m.limit + 15)
			say("祈りの力でLIMITが高まった！", "blue")
		"storm":
			reward_item("manaWater", 1)
			say("魔力水を1個入手！", "green")
		"crystal":
			add_material("magicOre", 1)
			add_material("slimeJelly", 1)
	say("次は「%s」へ進む。" % route.name, "yellow")
	_changed()
	return true


func make_event() -> void:
	if next_is_boss_floor() or _roll() > route.event:
		return
	event_kind = ["spring","treasure","shrine"][random_int(1, 3) - 1]


func choose_starter_reward(id: String) -> bool:
	if stats.get("starterRewardChosen", false) or id not in ["herb","mana","sp","craft"]:
		return false
	stats.starterRewardChosen = true
	match id:
		"herb":
			reward_item("herb", 3)
			say("支給品：薬草x3を受け取った！", "green")
		"mana":
			reward_item("manaWater", 2)
			say("支給品：魔力水x2を受け取った！", "blue")
		"sp":
			reward_item("trainingBook", 1)
			say("支給品：修練の書x1を受け取った！", "yellow")
		"craft":
			add_material("magicOre", 3)
			say("支給品：魔鉱石x3を受け取った！", "green")
	event_kind = ""
	_changed()
	return true


func resolve_event() -> void:
	match event_kind:
		"spring":
			for m in party:
				heal_member(m, 20)
		"treasure": random_quest_equipment()
		"shrine":
			for m in party:
				m.limit = minf(100, m.limit + 20)
			say("LIMITが高まった！", "blue")
		_: return
	event_kind = ""
	_changed()


func win() -> void:
	phase = "won"
	preparing = true
	busy = false
	route_chosen = false
	effect.emit("screen", 0, "", "victoryBurst")
	banner.emit("VICTORY!")
	record_book()
	gain_exp(18 + wave * 6)
	reward()
	if wave == 3 and not stats.get("earlyCraftGift", false):
		stats.earlyCraftGift = 1
		add_material("herbFlower", 2)
		add_material("magicOre", 1)
		add_material("slimeJelly", 1)
		say("クラフト練習用の素材を見つけた！", "yellow")
	if next_is_boss_floor():
		say("次はボス部屋だ。道は選べない……準備して進もう！", "red")
	make_event()
	if wave == 1 and not stats.get("starterRewardChosen", false):
		event_kind = "starter"
	if next_is_boss_floor():
		route = {"name":"ボス部屋前","hp":1.0,"atk":1.0,"reward":1.0,"event":0.0,"force":null}
		route_chosen = true
	_changed()


func lose() -> void:
	phase = "lost"
	busy = false
	say("到達階層：第%d階層" % wave, "yellow")
	_changed()


func next_wave() -> bool:
	if phase != "won" or not preparing or not route_chosen or busy:
		return false
	preparing = false
	route_chosen = false
	wave += 1
	enemies = make_enemies()
	sel_enemy = 0
	active = maxi(0, party.find_custom(func(m): return m.hp > 0))
	sel_ally = active
	phase = "party"
	busy = false
	event_kind = ""
	say("--- 第%d階層 ---" % wave, "yellow")
	if wave % 5 == 0:
		say("最深部の気配……星を喰らう邪竜が現れる！" if wave >= 20 else "ボス部屋だ……敵の予告に注意！", "red")
	_changed()
	return true


func _changed() -> void:
	if not party.is_empty() and not enemies.is_empty():
		enemy_target()
		actor()
	changed.emit()
