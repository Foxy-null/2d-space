class_name StageSixRoom
extends Node2D

const TERRAIN = preload("res://scripts/terrain_art.gd")
const LIGHT = preload("res://scenes/grabbable.tscn")
const HEAVY = preload("res://scenes/heavy_object.tscn")
const CREATURE = preload("res://scenes/jump_creature.tscn")
const UMBRELLA = preload("res://scenes/parachute_creature.tscn")
const GATE = preload("res://scenes/gravity_gate.tscn")
const WIND = preload("res://scenes/wind_area.tscn")
const SPRING = preload("res://scenes/spring.tscn")
const BUMPER = preload("res://scenes/pinball_spring.tscn")
const CRYSTAL = preload("res://scenes/refill_crystal.tscn")
const BUTTON = preload("res://scenes/pressure_button.tscn")
const ARRIVAL = preload("res://scenes/arrival_switch.tscn")

const TITLES := ["追跡者との投げ合い", "奪い合う開門スイッチ", "重荷を先へ送れ", "暴風の傘渡り", "逆さまの逃走路", "反発と空中ダッシュ", "横向きの重力迷宮", "重力を渡る縦の塔", "相棒と越える断崖", "二つの重量扉", "封鎖装置の予行", "追跡者との最終決着"]
const HINTS := [
	"Shiftで持ち、動きながら離すと投げる。敵を怯ませて道を作ろう。捕獲時の危険はスタミナで変わる。",
	"箱をスイッチに置くと扉が開く。敵も箱を使うので、予備の箱と投げるタイミングを使おう。",
	"重い箱は歩くと遅い。先へ投げてから追いかけ、重い箱が必要なスイッチへ運ぼう。",
	"赤い傘を持って上昇気流へ。風の中でも敵は傘を使う。傘の供給台へ戻って取り直せる。",
	"赤いゲートで天井へ、青で床へ。壁を掴み続けると、捕獲の危険が高まる。",
	"ばね・反発板から空中ダッシュへ。緑でダッシュ回復、紫で追加ジャンプを得られる。",
	"横重力では↑↓で壁沿いに歩き、Space / Aで壁から跳ぶ。投げた箱もその重力を引き継ぐ。",
	"左右の壁を床にしながら上へ。進路のゲートを通り、重力を切り替えて次の壁へ渡ろう。",
	"緑の相棒と紫のクリスタルは別の追加ジャンプ。着地で相棒の力が戻る。敵の投擲にも注意。",
	"二つの扉には別々の重りが必要。敵へ投げる箱とスイッチへ置く箱を使い分けよう。",
	"金のスイッチと縞の扉が対応する。箱を置き、閉じる側を確かめてから総合コースへ。",
	"二つの開門スイッチを通り、右上の出口へ逃げ切るか、追跡者を檻へ誘導して金の封鎖スイッチを押そう。",
]

var number := 0
var size := Vector2(1920, 960)
var spawn := Vector2(180, 794)
var enemy_spawn := Vector2(55, 794)
var exit_position := Vector2(1800, 700)
var exit_rect := Rect2()
var route: Array[Vector2] = []
var prepared := false
var preferred_item := ""
var hazards: Array[Rect2] = []
var moving_hazards: Array[Dictionary] = []
var supplies: Array[Dictionary] = []
var doors: Array[Dictionary] = []
var cage := Rect2()
var cage_doors: Array[StaticBody2D] = []
var seal_button: Area2D
var arrival: ArrivalSwitch
var exit_open := false
var _elapsed := 0.0
var _supply_left := 0.0


func _ready() -> void:
	set_meta("environment_theme", 3 if number < 6 else 4)
	prepared = number in [0, 1, 3, 6, 10]
	var items := Node2D.new()
	items.name = "Items"
	add_child(items)
	match number:
		0:
			_floor(0, 550, 820)
			_floor(760, 500, 820)
			_floor(1450, 470, 700)
			_platforms([Rect2(580, 650, 110, 28), Rect2(1000, 650, 140, 28), Rect2(1280, 540, 130, 28)])
			_supply(LIGHT, Vector2(260, 780))
			_supply(LIGHT, Vector2(930, 780))
			_hazard(Rect2(1170, 650, 70, 170), Vector2(0, -150), 3.0)
			route.assign([Vector2(460, 790), Vector2(630, 620), Vector2(880, 790), Vector2(1060, 620), Vector2(1340, 510), Vector2(1600, 670)])
		1:
			_floor(0, 1920, 820)
			_block(Rect2(450, 540, 180, 35))
			_block(Rect2(1100, 590, 180, 35))
			_block(Rect2(1550, 620, 150, 35))
			_supply(LIGHT, Vector2(260, 780))
			_weight_door(Vector2(590, 820), Rect2(800, 0, 38, 820), 2.0)
			_hazard(Rect2(990, 750, 90, 70))
			_hazard(Rect2(1420, 730, 90, 90), Vector2(180, 0), 3.6)
			exit_position.y = 820
			route.assign([Vector2(580, 790), Vector2(900, 790), Vector2(1200, 560), Vector2(1600, 590)])
		2:
			_floor(0, 430, 820)
			_floor(520, 360, 760)
			_floor(1000, 340, 650)
			_floor(1450, 470, 760)
			_supply(HEAVY, Vector2(260, 780))
			_weight_door(Vector2(1200, 650), Rect2(1380, 0, 38, 960), 8.0)
			_platforms([Rect2(470, 580, 90, 28), Rect2(910, 500, 90, 28)])
			_hazard(Rect2(640, 550, 65, 55), Vector2(180, 0), 3.7)
			exit_position.y = 760
			preferred_item = "HEAVY"
			route.assign([Vector2(380, 790), Vector2(560, 730), Vector2(820, 730), Vector2(1020, 620), Vector2(1250, 620), Vector2(1560, 730)])
		3:
			size.y = 1440
			spawn = Vector2(180, 1274)
			enemy_spawn = Vector2(55, 1274)
			_floor(0, 430, 1300)
			_floor(1450, 470, 480)
			_platforms([Rect2(700, 990, 180, 32), Rect2(1090, 710, 190, 32)])
			_supply(UMBRELLA, Vector2(270, 1260))
			_supply(UMBRELLA, Vector2(785, 950))
			_wind(Rect2(340, 370, 1170, 950), Vector2.UP, 2600.0, 500.0)
			_hazard(Rect2(920, 510, 65, 390))
			_hazard(Rect2(1290, 850, 70, 270), Vector2(0, -280), 4.6)
			exit_position.y = 480
			preferred_item = "PARACHUTE"
			route.assign([Vector2(470, 1110), Vector2(750, 960), Vector2(830, 400), Vector2(1160, 680), Vector2(1400, 450), Vector2(1650, 450)])
		4:
			_floor(0, 430, 820)
			_floor(1450, 470, 740)
			_block(Rect2(340, 100, 1100, 40))
			_block(Rect2(860, 140, 40, 230))
			_block(Rect2(1120, 390, 40, 300))
			_gate(Vector2(410, 680), -1)
			_gate(Vector2(1450, 280), 1)
			_crystal(Vector2(930, 390), 0)
			_crystal(Vector2(1220, 310), 1)
			_crystal(Vector2(1210, 400), 0)
			_supply(LIGHT, Vector2(250, 780))
			_hazard(Rect2(600, 140, 110, 70))
			_hazard(Rect2(1270, 140, 70, 90))
			exit_position.y = 740
			route.assign([Vector2(410, 660), Vector2(470, 180), Vector2(760, 180), Vector2(970, 410), Vector2(1080, 330), Vector2(1200, 330), Vector2(1210, 400), Vector2(1380, 520), Vector2(1470, 270), Vector2(1690, 710)])
		5:
			_floor(0, 430, 820)
			_floor(1460, 460, 690)
			_spring(Vector2(360, 820))
			_bumper(Vector2(900, 420))
			_crystal(Vector2(690, 470), 0)
			_crystal(Vector2(1120, 390), 1)
			_platforms([Rect2(650, 660, 130, 30), Rect2(930, 500, 130, 30), Rect2(1180, 600, 120, 30)])
			_hazard(Rect2(1010, 660, 75, 300))
			_supply(LIGHT, Vector2(250, 780))
			exit_position.y = 690
			route.assign([Vector2(350, 790), Vector2(640, 470), Vector2(770, 390), Vector2(990, 340), Vector2(1240, 570), Vector2(1640, 660)])
		6:
			_floor(0, 510, 820)
			_floor(1450, 470, 500)
			_block(Rect2(970, 320, 40, 500))
			_block(Rect2(1320, 0, 40, 390))
			_gate(Vector2(470, 670), 2)
			_gate(Vector2(940, 400), 2)
			_gate(Vector2(1260, 220), 2)
			_gate(Vector2(1430, 400), 1)
			_supply(LIGHT, Vector2(250, 780))
			_crystal(Vector2(1150, 400), 0)
			_hazard(Rect2(1010, 630, 70, 190))
			exit_position.y = 500
			route.assign([Vector2(470, 670), Vector2(944, 400), Vector2(944, 220), Vector2(1294, 250), Vector2(1294, 490), Vector2(1440, 440), Vector2(1640, 470)])
			_label(Vector2(1015, 240), "↑ 上端を越える", Color("a2ffd0"))
			_label(Vector2(1130, 440), "↓ 下端を越える", Color("a2ffd0"))
		7:
			size = Vector2(1280, 2160)
			spawn = Vector2(180, 1974)
			enemy_spawn = Vector2(55, 1974)
			_floor(0, 500, 2000)
			_platforms([Rect2(800, 1430, 200, 35), Rect2(220, 1040, 180, 35), Rect2(800, 650, 200, 35)])
			_block(Rect2(1100, 390, 36, 1610))
			_block(Rect2(100, 400, 36, 1150))
			_gate(Vector2(470, 1830), 2)
			_gate(Vector2(1060, 1280), -2)
			_gate(Vector2(170, 890), 2)
			_gate(Vector2(1160, 320), 1)
			_supply(CREATURE, Vector2(280, 1960))
			_crystal(Vector2(640, 1460), 0)
			_crystal(Vector2(640, 1070), 1)
			_crystal(Vector2(640, 680), 0)
			_hazard(Rect2(490, 1540, 70, 200))
			_hazard(Rect2(610, 870, 70, 200))
			exit_position = Vector2(1190, 390)
			route.assign([Vector2(420, 1970), Vector2(470, 1830), Vector2(1074, 1880), Vector2(1074, 1280), Vector2(170, 1330), Vector2(170, 890), Vector2(1074, 800), Vector2(1074, 300), Vector2(1160, 320), Vector2(1170, 360)])
			_label(Vector2(550, 1850), "→ 下側を渡って右壁へ", Color("a2ffd0"))
		8:
			_floor(0, 380, 820)
			_floor(1500, 420, 620)
			_platforms([Rect2(630, 620, 100, 30), Rect2(1030, 410, 100, 30)])
			_supply(CREATURE, Vector2(260, 780))
			_crystal(Vector2(520, 570), 1)
			_crystal(Vector2(870, 390), 0)
			_crystal(Vector2(1320, 360), 1)
			_hazard(Rect2(780, 620, 70, 340))
			_hazard(Rect2(1200, 580, 80, 100), Vector2(170, -120), 3.3)
			exit_position.y = 620
			preferred_item = "JUMP"
			route.assign([Vector2(330, 790), Vector2(680, 590), Vector2(1080, 380), Vector2(1350, 350), Vector2(1700, 590)])
		9:
			_floor(0, 1920, 820)
			_supply(LIGHT, Vector2(260, 780))
			_supply(HEAVY, Vector2(1160, 780))
			_weight_door(Vector2(540, 820), Rect2(740, 0, 36, 820), 2.0)
			_weight_door(Vector2(1290, 820), Rect2(1440, 0, 36, 820), 8.0)
			_platforms([Rect2(840, 560, 130, 30), Rect2(1220, 500, 120, 30)])
			_block(Rect2(1510, 550, 130, 30))
			_hazard(Rect2(850, 750, 60, 70), Vector2(190, 0), 3.2)
			_hazard(Rect2(1560, 610, 70, 210), Vector2(130, 0), 3.4)
			exit_position.y = 820
			route.assign([Vector2(540, 790), Vector2(860, 790), Vector2(1290, 790), Vector2(1480, 530), Vector2(1550, 520), Vector2(1780, 520)])
		10:
			_floor(0, 660, 820)
			_floor(1450, 470, 540)
			_supply(LIGHT, Vector2(260, 780))
			_weight_door(Vector2(510, 820), Rect2(750, 330, 36, 490), 2.0, true)
			_label(Vector2(340, 690), "金の重り台 → 縞の扉が閉じる", Color("ffdc78"))
			_platforms([Rect2(860, 670, 130, 30), Rect2(1160, 470, 120, 30)])
			_supply(UMBRELLA, Vector2(590, 780))
			_wind(Rect2(780, 260, 650, 580), Vector2(-0.35, -1), 2500, 480)
			_gate(Vector2(1170, 300), -1)
			_block(Rect2(1000, 100, 420, 32))
			_gate(Vector2(1440, 300), 1)
			_crystal(Vector2(1040, 500), 0)
			_hazard(Rect2(1030, 680, 70, 280))
			exit_position.y = 540
			preferred_item = "PARACHUTE"
			route.assign([Vector2(590, 790), Vector2(900, 640), Vector2(1160, 440), Vector2(1170, 300), Vector2(1380, 160), Vector2(1450, 300), Vector2(1660, 510)])
		11:
			_build_final()
	_block(Rect2(0, 0, 28, size.y + 200))
	_block(Rect2(size.x - 28, 0, 28, size.y + 200))
	if number == 7:
		_floor(1120, 160, exit_position.y)
	elif number != 11:
		_floor(exit_position.x - 120, size.x - exit_position.x + 120, exit_position.y)
	exit_rect = Rect2(exit_position + Vector2(-58, -185), Vector2(116, 180))
	arrival = ARRIVAL.instantiate()
	arrival.name = "Arrival"
	arrival.mission_required = false
	arrival.position = exit_position
	add_child(arrival)
	arrival.activated.connect(func(): exit_open = true)
	_label(exit_position + Vector2(-100, -220), "逃走出口" if number == 11 else "出口の到着台", Color("a2ffd0"))
	_label(spawn + Vector2(10, 55), "物体の供給台 / Shiftで持つ", Color("ffdc78"))


func _build_final() -> void:
	size = Vector2(2560, 1440)
	spawn = Vector2(180, 1274)
	enemy_spawn = Vector2(55, 1274)
	_floor(0, 640, 1300)
	_floor(780, 620, 1120)
	_floor(1540, 520, 850)
	_floor(2440, 120, 350)
	_platforms([Rect2(620, 1120, 110, 30), Rect2(1400, 950, 100, 30), Rect2(2160, 650, 200, 30), Rect2(2230, 480, 100, 30)])
	_supply(LIGHT, Vector2(260, 1260))
	_supply(HEAVY, Vector2(960, 1080))
	_supply(CREATURE, Vector2(1740, 810))
	_weight_door(Vector2(510, 1300), Rect2(740, 0, 36, 1440), 2.0)
	_weight_door(Vector2(1260, 1120), Rect2(1480, 0, 36, 1440), 8.0)
	_block(Rect2(1325, 800, 30, 320))
	_gate(Vector2(2340, 550), 2)
	_block(Rect2(2400, 360, 36, 440))
	_gate(Vector2(2450, 240), 1)
	_crystal(Vector2(2060, 560), 0)
	_crystal(Vector2(2210, 350), 1)
	_hazard(Rect2(1090, 950, 65, 170), Vector2(130, 0), 3.0)
	_hazard(Rect2(1780, 540, 75, 90), Vector2(100, 0), 3.1)
	_hazard(Rect2(2140, 870, 80, 570))
	cage = Rect2(1580, 620, 300, 230)
	_block(Rect2(1580, 590, 300, 30))
	cage_doors.append(_block(Rect2(1548, 620, 30, 230)))
	cage_doors.append(_block(Rect2(1882, 620, 30, 230)))
	for door in cage_doors:
		_set_door(door, false)
	seal_button = _button(Vector2(2220, 650), 2.0)
	_supply(LIGHT, Vector2(1930, 810))
	_label(Vector2(1580, 550), "追跡者を檻へ誘導", Color("ffdc78"))
	_label(Vector2(2210, 700), "檻の中の敵を封鎖\n箱を置いて作動", Color("ffdc78"))
	exit_position = Vector2(2470, 350)
	preferred_item = "HEAVY"
	route.assign([Vector2(510, 1270), Vector2(670, 1090), Vector2(900, 1090), Vector2(1340, 770), Vector2(1460, 920), Vector2(1600, 820), Vector2(1740, 820), Vector2(1860, 820), Vector2(1980, 820), Vector2(2060, 820), Vector2(2120, 570), Vector2(2240, 620), Vector2(2340, 550), Vector2(2374, 280), Vector2(2450, 200), Vector2(2470, 200)])


func _physics_process(delta: float) -> void:
	_elapsed += delta
	for entry in doors:
		_set_door(entry.body, not entry.button.is_pressed() if not entry.closes else entry.button.is_pressed())
	for entry in moving_hazards:
		entry.current = Rect2(entry.rect.position + entry.travel * (0.5 - 0.5 * cos(_elapsed * TAU / entry.period)), entry.rect.size)
	_supply_left -= delta
	if _supply_left <= 0.0:
		_supply_left = 0.75
		_restock()
	queue_redraw()


func _restock() -> void:
	for supply in supplies:
		var available := false
		var matching: Array[Grabbable] = []
		for item in $Items.get_children():
			if item.get_meta("supply", -1) != supply.id:
				continue
			matching.append(item)
			if item.carrier == null and item.position.distance_to(supply.at) < 150.0:
				available = true
		if available:
			continue
		# shortcut: six items per supply, raise the cap for puzzles needing more simultaneous weights.
		if matching.size() < 6:
			_spawn_item(supply.scene, supply.at, supply.id)
		else:
			matching.sort_custom(func(a, b): return a.position.distance_squared_to(supply.at) > b.position.distance_squared_to(supply.at))
			for item in matching:
				var on_switch := seal_button != null and seal_button.get_overlapping_bodies().has(item)
				for entry in doors:
					on_switch = on_switch or entry.button.get_overlapping_bodies().has(item)
				if item.carrier == null and not on_switch:
					item.reset_for_respawn()
					break


func reset_state() -> void:
	_elapsed = 0.0
	exit_open = false
	arrival.reset_for_respawn()
	for child in get_children():
		if child.has_method("reset_for_respawn") and child != arrival:
			child.reset_for_respawn()
	for door in cage_doors:
		_set_door(door, false)
	for supply in supplies:
		var matching: Array = $Items.get_children().filter(func(item): return item.get_meta("supply", -1) == supply.id)
		for index in range(1, matching.size()):
			matching[index].queue_free()


func all_weight_doors_open() -> bool:
	for entry in doors:
		if not entry.closes and not entry.button.is_pressed():
			return false
	return true


func hazard_ahead(actor: PlayerController, direction: float) -> bool:
	var tangent := actor.get_walk_axis()
	var down := actor.get_gravity_vector()
	var rectangles: Array = hazards.duplicate()
	for entry in moving_hazards:
		rectangles.append(entry.current)
	for rect: Rect2 in rectangles:
		var half_along := (absf(tangent.x) * rect.size.x + absf(tangent.y) * rect.size.y) * 0.5
		var half_down := (absf(down.x) * rect.size.x + absf(down.y) * rect.size.y) * 0.5
		var ahead := (rect.get_center() - actor.position).dot(tangent) * signf(direction) - half_along
		var top := rect.get_center().dot(down) - half_down
		if actor.is_on_floor() and top > actor.position.dot(down) + 32:
			continue
		if ahead > -30 and ahead < 210 and actor.position.dot(down) > top - 120 and actor.position.dot(down) < top + half_down * 2 + 100:
			return true
	return false


func seal_enemy(enemy: PlayerController, player: PlayerController) -> bool:
	if seal_button == null or not seal_button.is_pressed() or not all_weight_doors_open():
		return false
	if not cage.encloses(Rect2(enemy.position - Vector2(26, 26), Vector2(52, 52))) or cage.grow(30).has_point(player.position) or player.position.x <= cage.end.x or player.position.y >= cage.end.y:
		return false
	for door in cage_doors:
		_set_door(door, true)
	return true


func _block(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = rect.size
	body.add_child(shape)
	var art := Polygon2D.new()
	art.set_script(TERRAIN)
	var half := rect.size * 0.5
	art.polygon = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	body.add_child(art)
	add_child(body)
	return body


func _floor(x: float, width: float, y: float) -> void:
	_block(Rect2(x, y, width, 60))


func _platforms(rectangles: Array) -> void:
	for rect in rectangles:
		_block(rect)


func _supply(scene: PackedScene, at: Vector2) -> void:
	var id := supplies.size()
	supplies.append({"id": id, "scene": scene, "at": at})
	_spawn_item(scene, at, id)
	_label(at + Vector2(-45, 65), "供給", Color("ffdc78"))


func _spawn_item(scene: PackedScene, at: Vector2, id: int) -> void:
	var item: Grabbable = scene.instantiate()
	item.position = at
	item.directional_gravity_enabled = true
	item.set_meta("supply", id)
	$Items.add_child(item)


func _button(at: Vector2, weight: float) -> Area2D:
	var button := BUTTON.instantiate()
	button.position = at
	button.required_weight = weight
	add_child(button)
	return button


func _weight_door(at: Vector2, rect: Rect2, weight: float, closes := false) -> void:
	var button := _button(at, weight)
	var body := _block(rect)
	doors.append({"button": button, "body": body, "closes": closes})
	_set_door(body, not closes)
	_label(at + Vector2(-65, -75), "封鎖" if closes else ("重い箱" if weight > 2 else "開門"), Color("ffdc78"))


func _set_door(body: StaticBody2D, closed: bool) -> void:
	if body.visible == closed:
		return
	body.visible = closed
	body.get_child(0).set_deferred("disabled", not closed)


func _gate(at: Vector2, direction: int) -> void:
	var gate := GATE.instantiate()
	gate.position = at
	gate.target_gravity = direction
	add_child(gate)


func _wind(rect: Rect2, direction: Vector2, acceleration: float, limit: float) -> void:
	var wind := WIND.instantiate()
	wind.position = rect.get_center()
	wind.area_size = rect.size
	wind.wind_direction = direction
	wind.wind_acceleration = acceleration
	wind.max_wind_speed = limit
	add_child(wind)


func _spring(at: Vector2) -> void:
	var spring := SPRING.instantiate()
	spring.position = at
	add_child(spring)


func _bumper(at: Vector2) -> void:
	var bumper := BUMPER.instantiate()
	bumper.position = at
	add_child(bumper)


func _crystal(at: Vector2, kind: int) -> void:
	var crystal := CRYSTAL.instantiate()
	crystal.position = at
	crystal.refill_kind = kind
	add_child(crystal)


func _hazard(rect: Rect2, travel := Vector2.ZERO, period := 4.0) -> void:
	if travel.is_zero_approx():
		hazards.append(rect)
	else:
		moving_hazards.append({"rect": rect, "current": rect, "travel": travel, "period": period})


func _label(at: Vector2, value: String, tint: Color) -> void:
	var label := Label.new()
	label.position = at
	label.text = value
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", Color("15162c"))
	label.add_theme_constant_override("outline_size", 5)
	add_child(label)


func _draw() -> void:
	for entry in moving_hazards:
		_draw_hazard(entry.current)
	for rect in hazards:
		_draw_hazard(rect)
	if cage.has_area():
		draw_rect(cage, Color(1, 0.8, 0.3, 0.07))
		var wire_start := seal_button.position + Vector2(0, 20)
		var wire_end := Vector2(cage.end.x, cage.position.y - 15)
		draw_polyline(PackedVector2Array([wire_start, Vector2(wire_start.x, wire_end.y), wire_end]), Color(1, 0.8, 0.3, 0.65), 4)
		for x in range(int(cage.position.x), int(cage.end.x), 24):
			draw_line(Vector2(x, cage.position.y), Vector2(x, cage.end.y), Color(1, 0.8, 0.3, 0.25), 3)
	for entry in doors:
		var from: Vector2 = entry.button.position + Vector2(0, 25)
		var to: Vector2 = entry.body.position
		draw_polyline(PackedVector2Array([from, Vector2(to.x, from.y), to]), Color(1, 0.8, 0.3, 0.4), 3)


func _draw_hazard(rect: Rect2) -> void:
	draw_rect(rect, Color("7a263b"))
	for x in range(int(rect.position.x), int(rect.end.x), 22):
		ArtDraw.polygon(self, PackedVector2Array([Vector2(x, rect.end.y), Vector2(x + 11, rect.position.y), Vector2(minf(x + 22, rect.end.x), rect.end.y)]), Color("ff7f8d"))
