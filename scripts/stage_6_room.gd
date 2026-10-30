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
const KEY = preload("res://scripts/escape_key.gd")
const ARRIVAL = preload("res://scenes/arrival_switch.tscn")
const SPIKE_BLOCK = preload("res://scenes/spike_block.tscn")
const ROOM_COUNT := 13
const FINAL_ROOM := ROOM_COUNT - 1
const MAX_NEEDLES := 640
const MAX_FLYING_NEEDLES := 96

const TITLES := ["針を道へ変える", "開門と予備の箱", "重荷を先へ送れ", "灰雲と傘渡り", "逆さまの逃走路", "反発と空中ダッシュ", "横向きの重力迷宮", "重力を渡る縦の塔", "相棒と越える断崖", "二つの重量扉", "封鎖装置の予行", "棘の振り子と誘導路", "追跡者との最終決着"]
const HINTS := [
	"長針は狙いの線へ3連射します。狙われた場所を離れて壁へ刺し、露出した先端へ箱を投げると安全な足場になります。最初の穴には普通の足場の道もあります。\n動きながらShiftを離すと投擲、止まって離すと置く操作です。敵に箱を当てると2秒止まります。緑でダッシュを戻し、紫の追加ジャンプを一つずつつなぎます。",
	"手前の軽い箱をShiftで持ち、開門スイッチの上で止まってから離してください。箱が台に残ると縞の扉が開きます。\n敵が近づいたら、開門用の箱は台に残し、別の箱を投げて怯ませます。扉の先は高い足場、床ばね、丸いバンパーを使うとトゲを避けて進めます。入口で準備してから進めば、追跡開始まで短い猶予があります。",
	"この扉には重い箱が必要です。軽い箱では重量が足りません。手前の重い箱を段差の先へ投げて追い、奥の重量スイッチまで運んで置いてください。\n持っている間は移動が遅く、壁も登れません。段差で詰まったら安全な足場で箱を先へ送り、自分は空身で追うと安定します。箱を敵への攻撃に使った場合も、金の輪で補充できます。",
	"赤い和傘を持って最初の上昇気流へ入ります。足場の真下で上昇が止まったら、横へ出て端を抜け、上へ回り込んでください。\n途中の足場で着地してから、横風に乗って次の上昇気流へ渡ります。後半の動くトゲには突っ込まず、上下する位置を見て外側を回ります。傘を失った場合は途中の金の輪でも取り直せます。",
	"最初の↑ゲートで天井を床にします。天井の障害物を避け、壁を掴むときは↓入力で重力に逆らって登ってください。\n途中は障害物の下へ離れ、緑で補充したダッシュをつなぎます。最後の↓ゲートを通って通常の床へ戻り、右の足跡の到着台へ着地します。荷物があると壁を掴めないので、必要なら置いて進みましょう。",
	"床のばねで上昇し、空中の緑を取ってダッシュを補充します。丸いバンパーへ入る角度で飛び出す方向を調整し、次の足場へ向かってください。\n紫を取ったら、落ち始める前に追加ジャンプで高さを戻します。ダッシュ・追加ジャンプを全部同時に使わず、一つずつ上昇の終わりにつなぐと最後の床まで届きます。",
	"最初の→ゲートで右の壁を床にし、一枚目は上端、次の壁は下端を回って↓ゲートから戻ります。\n後半の通常路は低い足場を右へ渡る道です。上には左重力と横ばねを使う近道も残っています。追尾トゲは曲がり角や受け壁へ誘導し、刺した先端へ箱を固定する道も試せます。",
	"下側の→ゲートを通り、まず右壁へ渡ります。右壁に着いたら↑で登り、←ゲートで反対の壁へ移ってください。\n左壁でも↑へ進み、次の→ゲートから右壁へ渡ってさらに登ります。塔の中央のトゲには近づかず、緑と紫を取るときだけ壁から跳び出すと安定します。頂上の↓ゲートを通った後は、右の到着台へ着地してください。",
	"緑の相棒を持ち、最初の足場へ通常ジャンプと相棒の追加ジャンプで渡ります。相棒の力は保持したままの着地で回復します。\n紫による追加ジャンプは相棒とは別です。上昇の終わりに一つずつ使い、緑のダッシュ回復もつないでください。動くトゲが近い足場では、一度着地して動きを見てから次へ跳びます。",
	"手前の扉は軽い箱、奥の扉は重い箱をそれぞれのスイッチへ置いて開きます。一つの箱を先へ持ち去ると開門条件を失うので、台に置いた箱は残してください。\n追ってきた敵には予備の箱を投げ、高い足場へ逃げて運搬する時間を作れます。二つ目の扉の先は床ばねで上がり、緑と紫をつないで動くトゲの上を渡ります。",
	"金の重量スイッチは「開門」ではなく「封鎖」です。箱を載せると対応する縞の扉が閉まるので、進路と敵の位置を確かめて使ってください。箱を外せば開け直せます。\n先へ進むときは傘を持って斜めの上昇気流へ入り、足場の横から上へ回り込みます。↑ゲートで天井側へ移り、最後の↓ゲートから出口へ着地してください。",
	"ステージ4と同じ四面の棘ブロックです。点線の端で折り返すので、広い踊り場で動きを見てから渡ります。\n敵は棘を歩けます。追尾トゲは受け壁へ誘い、刺さった先端を箱で覆うと近道になります。壁の裏へ回り込むと、敵は最後に見た場所を探します。",
	"3通りの決着を選べます。前座の重量扉はありません。\n決着：敵の予告をかわし、隙に箱を6回当てます。封鎖：逃走出口の下にある奥の装置へ向かい、くぼみの金の台へ重箱を置いて通電。敵を檻へ誘導し、箱で怯ませたら左の高台の制御盤を自分で踏みます。先に乗ったまま待っても作動しません。\n逃走：左右の高所にある鍵を2つ取り、敵と20秒対峙してから最も右上の出口へ。上段は逃走、下段は封じ込めです。"
]

var number := 0
var size := Vector2(1920, 960)
var spawn := Vector2(180, 794)
var enemy_spawn := Vector2(55, 794)
var exit_position := Vector2(1800, 700)
var exit_rect := Rect2()
var route: Array[Vector2] = []
var prepared := false
var chase_delay := 0.6
var battle_arena := Rect2()
var key_collected := false
var escape_unlocked := false
var escape_key: Area2D
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
var needles: Node2D
var brittle_platforms: Array[StaticBody2D] = []
var spike_blocks: Array[SpikeBlock] = []
var attack_patterns: Array[int] = [0, 1, 2, 3]
var visible_area := Rect2()
var escape_keys: Array[Area2D] = []
var keys_collected := 0
var seal_console := Vector2.ZERO
var _console_occupied := false
var _seal_triggered := false
var passage_rect := Rect2()
var passage_route: Array[Vector2] = []
var passage_gate: StaticBody2D
var entrance_wall: StaticBody2D
var breach_left := 0.0
var extension_block: SpikeBlock
var spawn_area := Rect2()


func _ready() -> void:
	set_meta("environment_theme", 3 if number < 6 else 4)
	prepared = number in [0, 1, 3, 6, 10]
	var items := Node2D.new()
	items.name = "Items"
	add_child(items)
	needles = Node2D.new()
	needles.name = "Needles"
	add_child(needles)
	var clouds := Node2D.new()
	clouds.name = "AshClouds"
	add_child(clouds)
	attack_patterns.assign([[0, 3], [0, 1], [0, 3, 5], [3, 4], [2, 3, 4], [1, 3, 4, 5], [2, 3, 5], [0, 2, 3, 4], [1, 2, 3, 5], [0, 2, 3, 4, 5], [0, 3, 4], [1, 2, 3, 4, 5], [0, 1, 2, 3, 4, 5]][number])
	match number:
		0:
			_floor(0, 550, 820)
			_floor(760, 500, 820)
			_floor(1450, 470, 700)
			_platforms([Rect2(580, 650, 110, 28), Rect2(1000, 650, 140, 28), Rect2(1280, 540, 130, 28)])
			_supply(LIGHT, Vector2(260, 780))
			_supply(LIGHT, Vector2(1070, 780))
			_supply(UMBRELLA, Vector2(850, 780))
			_crystal(Vector2(630, 610), 0)
			_crystal(Vector2(1340, 445), 1)
			_block(Rect2(1500, 500, 280, 24))
			# The gap's receiving wall accepts needles without blocking the normal route.
			_block(Rect2(760, 740, 28, 80))
			_hazard(Rect2(1170, 750, 70, 70), Vector2(0, -100), 3.0)
			route.assign([Vector2(460, 790), Vector2(630, 620), Vector2(880, 790), Vector2(1060, 620), Vector2(1340, 510), Vector2(1600, 670)])
		1:
			size.x = 3000
			spawn.x = 600
			enemy_spawn.x = 320
			chase_delay = 1.5
			_floor(0, 3000, 820)
			_supply(LIGHT, Vector2(700, 780))
			_supply(LIGHT, Vector2(1650, 780))
			_weight_door(Vector2(1120, 820), Rect2(1400, 0, 38, 820), 2.0)
			_platforms([Rect2(580, 640, 230, 32), Rect2(930, 550, 200, 32), Rect2(1560, 650, 210, 32), Rect2(1900, 530, 180, 32), Rect2(2280, 610, 230, 32)])
			_block(Rect2(1880, 300, 260, 24))
			_spring(Vector2(1770, 820))
			_bumper(Vector2(2150, 390))
			_hazard(Rect2(1940, 750, 80, 70), Vector2(160, 0), 4.0)
			_hazard(Rect2(2580, 730, 90, 90))
			_crystal(Vector2(1650, 555), 1)
			_crystal(Vector2(2030, 440), 0)
			_crystal(Vector2(2390, 510), 1)
			exit_position = Vector2(2860, 820)
			route.assign([Vector2(1120, 790), Vector2(1510, 790), Vector2(1650, 620), Vector2(2000, 500), Vector2(2390, 570), Vector2(2740, 680)])
		2:
			size.x = 3200
			spawn.x = 600
			enemy_spawn.x = 320
			prepared = true
			chase_delay = 1.5
			_floor(0, 1250, 820)
			_floor(1250, 900, 730)
			_floor(2150, 1050, 640)
			_platforms([Rect2(1140, 775, 110, 45), Rect2(2040, 685, 110, 45)])
			_supply(HEAVY, Vector2(710, 780))
			_supply(LIGHT, Vector2(1640, 690))
			_weight_door(Vector2(1930, 730), Rect2(2190, 0, 38, 960), 8.0)
			_platforms([Rect2(860, 600, 240, 32), Rect2(1390, 500, 210, 32), Rect2(2390, 470, 200, 32), Rect2(2750, 350, 180, 32)])
			_crystal(Vector2(1100, 660), 0)
			_crystal(Vector2(1590, 610), 1)
			_crystal(Vector2(2520, 360), 0)
			_crystal(Vector2(2890, 290), 1)
			_hazard(Rect2(2630, 570, 80, 70), Vector2(140, 0), 4.2)
			exit_position = Vector2(3060, 640)
			preferred_item = "HEAVY"
			route.assign([Vector2(1110, 790), Vector2(1310, 700), Vector2(1900, 700), Vector2(2250, 610), Vector2(2450, 440), Vector2(2810, 320), Vector2(3040, 510)])
		3:
			size = Vector2(2880, 1680)
			spawn = Vector2(500, 1514)
			enemy_spawn = Vector2(80, 1514)
			chase_delay = 2.0
			_floor(0, 750, 1540)
			_floor(2520, 360, 620)
			_platforms([Rect2(900, 1200, 260, 32), Rect2(1340, 1000, 220, 32), Rect2(1700, 750, 220, 32), Rect2(2190, 550, 180, 32)])
			_platforms([Rect2(940, 990, 170, 24), Rect2(1730, 530, 160, 24)])
			_supply(UMBRELLA, Vector2(610, 1500))
			_supply(UMBRELLA, Vector2(1450, 960))
			_wind(Rect2(710, 450, 620, 1110), Vector2.UP, 2600.0, 500.0)
			_wind(Rect2(1410, 280, 1130, 850), Vector2.UP, 2600.0, 500.0)
			_wind(Rect2(1100, 760, 620, 220), Vector2.RIGHT, 850.0, 260.0)
			_hazard(Rect2(1240, 1260, 70, 420))
			_hazard(Rect2(2030, 690, 65, 200), Vector2(0, -100), 5.0)
			_crystal(Vector2(820, 1080), 0)
			_crystal(Vector2(1270, 880), 1)
			_crystal(Vector2(1620, 660), 0)
			_crystal(Vector2(2110, 420), 1)
			_crystal(Vector2(2470, 470), 0)
			exit_position = Vector2(2740, 620)
			preferred_item = "PARACHUTE"
			route.assign([Vector2(690, 1510), Vector2(820, 1340), Vector2(820, 1090), Vector2(1210, 1050), Vector2(1450, 970), Vector2(1610, 820), Vector2(1610, 640), Vector2(1950, 590), Vector2(2140, 480), Vector2(2440, 470), Vector2(2670, 590)])
		4:
			_floor(0, 430, 820)
			_floor(1450, 470, 740)
			_block(Rect2(340, 100, 1100, 40))
			_block(Rect2(860, 140, 40, 230))
			_block(Rect2(1120, 390, 40, 300))
			_gate(Vector2(410, 680), -1)
			_gate(Vector2(1450, 280), 1)
			_crystal(Vector2(930, 390), 0)
			_crystal(Vector2(1110, 250), 1)
			_crystal(Vector2(1210, 400), 0)
			_supply(LIGHT, Vector2(250, 780))
			_hazard(Rect2(600, 140, 110, 70))
			_hazard(Rect2(1270, 140, 70, 90))
			exit_position.y = 740
			route.assign([Vector2(410, 660), Vector2(470, 180), Vector2(760, 180), Vector2(970, 410), Vector2(1080, 330), Vector2(1200, 330), Vector2(1210, 400), Vector2(1380, 520), Vector2(1470, 270), Vector2(1690, 710)])
		5:
			_floor(0, 430, 820)
			_floor(1460, 460, 690)
			_floor(480, 270, 860)
			_floor(830, 300, 820)
			_floor(1210, 260, 760)
			_block(Rect2(620, 650, 30, 210))
			_block(Rect2(880, 590, 30, 230))
			_block(Rect2(1180, 600, 30, 160))
			_block(Rect2(470, 700, 90, 24))
			_supply(UMBRELLA, Vector2(730, 810))
			_supply(LIGHT, Vector2(520, 820))
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
			size.x = 2880
			_floor(0, 510, 820)
			_floor(1450, 470, 500)
			_floor(2630, 250, 500)
			_platforms([Rect2(1990, 580, 140, 32), Rect2(2390, 540, 160, 32)])
			_spring(Vector2(1810, 500))
			_bumper(Vector2(2210, 180))
			_gate(Vector2(2270, 290), -2)
			_block(Rect2(2090, 140, 36, 340))
			_spring(Vector2(2126, 290), PI / 2.0)
			_gate(Vector2(2580, 290), 1)
			_crystal(Vector2(2410, 290), 0)
			_crystal(Vector2(2060, 120), 1)
			_crystal(Vector2(2060, 280), 0)
			_crystal(Vector2(2410, 100), 1)
			_hazard(Rect2(2250, 630, 100, 330))
			_block(Rect2(970, 320, 40, 500))
			_block(Rect2(1320, 0, 40, 390))
			_gate(Vector2(470, 670), 2)
			_gate(Vector2(1430, 400), 1)
			_supply(LIGHT, Vector2(250, 780))
			_crystal(Vector2(1150, 400), 0)
			_hazard(Rect2(1010, 630, 70, 190))
			exit_position = Vector2(2740, 500)
			_platforms([Rect2(2160, 600, 150, 30)])
			_crystal(Vector2(2230, 500), 0)
			route.assign([Vector2(470, 670), Vector2(944, 220), Vector2(1294, 250), Vector2(1294, 490), Vector2(1440, 440), Vector2(1640, 470), Vector2(1810, 470), Vector2(2050, 550), Vector2(2230, 570), Vector2(2470, 510), Vector2(2690, 390)])
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
		8:
			_floor(0, 380, 820)
			_floor(1500, 420, 620)
			_platforms([Rect2(630, 620, 100, 30), Rect2(1030, 410, 100, 30)])
			_supply(CREATURE, Vector2(260, 780))
			_supply(CREATURE, Vector2(1090, 370))
			_supply(LIGHT, Vector2(430, 780))
			_platforms([Rect2(400, 820, 150, 30), Rect2(850, 780, 160, 30), Rect2(1300, 760, 160, 30)])
			_crystal(Vector2(520, 570), 1)
			_crystal(Vector2(870, 390), 0)
			_crystal(Vector2(1320, 360), 1)
			_hazard(Rect2(780, 620, 70, 340))
			_hazard(Rect2(1200, 580, 80, 100), Vector2(170, -120), 3.3)
			exit_position.y = 620
			preferred_item = "JUMP"
			route.assign([Vector2(330, 790), Vector2(680, 590), Vector2(1080, 380), Vector2(1350, 350), Vector2(1700, 590)])
		9:
			size.x = 3200
			spawn.x = 600
			enemy_spawn.x = 320
			prepared = true
			chase_delay = 1.5
			_floor(0, 3200, 820)
			_supply(LIGHT, Vector2(710, 780))
			_supply(HEAVY, Vector2(1730, 780))
			_block(Rect2(2160, 640, 260, 24))
			_weight_door(Vector2(1120, 820), Rect2(1390, 0, 36, 820), 2.0)
			_weight_door(Vector2(2130, 820), Rect2(2400, 0, 36, 820), 8.0)
			_platforms([Rect2(640, 620, 250, 32), Rect2(1030, 520, 210, 32), Rect2(1550, 610, 260, 32), Rect2(1960, 520, 220, 32), Rect2(2500, 650, 240, 32), Rect2(2820, 500, 180, 32)])
			_spring(Vector2(2470, 820))
			_hazard(Rect2(2710, 750, 75, 70), Vector2(130, 0), 4.0)
			_crystal(Vector2(1710, 520), 1)
			_crystal(Vector2(2620, 540), 0)
			exit_position = Vector2(3060, 820)
			route.assign([Vector2(1120, 790), Vector2(1500, 790), Vector2(2130, 790), Vector2(2470, 790), Vector2(2470, 620), Vector2(2610, 620), Vector2(2900, 470), Vector2(3050, 670)])
		10:
			_floor(0, 660, 820)
			_floor(1450, 470, 540)
			_supply(LIGHT, Vector2(260, 780))
			_weight_door(Vector2(510, 820), Rect2(750, 330, 36, 490), 2.0, true)
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
			_build_spike_corridor()
		12:
			_build_final()
	if number in [0, 5, 9]:
		var platform := _block(Rect2(size.x * 0.55, spawn.y - 360.0, 160, 22))
		platform.set_meta("needle_breakable", true)
		platform.modulate = Color("f1b17d")
		brittle_platforms.append(platform)
		var crack := Line2D.new()
		crack.width = 3.0
		crack.default_color = Color("592e35")
		crack.points = PackedVector2Array([Vector2(-20, -11), Vector2(-5, -2), Vector2(-15, 5), Vector2(8, 11)])
		platform.add_child(crack)
	if number != FINAL_ROOM:
		_build_extension()
	# Break a section of the enclosing wall when the enemy follows into the next room.
	if number > 0:
		enemy_spawn = Vector2(-50, spawn.y)
	spawn_area = Rect2(spawn - Vector2(160, 200), Vector2(400, 280))
	_block(Rect2(0, 0, 28, spawn.y - 150))
	entrance_wall = _block(Rect2(0, spawn.y - 150, 28, 176))
	_block(Rect2(0, spawn.y + 26, 28, size.y - spawn.y + 174))
	_floor(-180, 208, spawn.y + 26)
	_block(Rect2(size.x - 28, 0, 28, size.y + 200))
	if number != FINAL_ROOM:
		_floor(exit_position.x - 120, size.x - exit_position.x + 120, exit_position.y)
	exit_rect = Rect2(exit_position + Vector2(-58, -185), Vector2(116, 180))
	arrival = ARRIVAL.instantiate()
	arrival.name = "Arrival"
	arrival.mission_required = number == FINAL_ROOM
	arrival.position = exit_position
	add_child(arrival)
	arrival.get_node("Bubble").hide()
	arrival.activated.connect(open_passage)
	if number == FINAL_ROOM:
		update_escape(false)


func _build_extension() -> void:
	var old_width := size.x
	var floor_y := exit_position.y
	# Keep the gravity course's original side wall, with a door at its exit height.
	if floor_y > 210:
		_block(Rect2(old_width - 28, 0, 28, floor_y - 210))
	_block(Rect2(old_width - 28, floor_y + 30, 28, size.y - floor_y + 170))
	passage_gate = _block(Rect2(old_width - 28, floor_y - 210, 28, 240))
	passage_gate.modulate = Color("ffd37d")
	size.x += 1000
	passage_rect = Rect2(size.x - 180, floor_y - 150, 100, 180)
	var start := old_width + 40
	_supply(LIGHT, Vector2(start + 60, floor_y - 40))
	_supply(UMBRELLA, Vector2(start + 300, floor_y - 40))
	_supply(CREATURE, Vector2(start + 650, floor_y - 40))
	# A covered lower route trades speed for shelter; the upper route carries refills.
	_platforms([Rect2(start + 200, floor_y - 160, 250, 28), Rect2(start + 500, floor_y - 230, 220, 28)])
	_block(Rect2(start + 100, floor_y - 85, 100, 25))
	_block(Rect2(start + 680, floor_y - 100, 28, 100))
	_crystal(Vector2(start + 340, floor_y - 215), 0)
	_crystal(Vector2(start + 590, floor_y - 285), 1)
	if number % 3 == 1:
		_spike_block(Vector2(start + 500, floor_y - 50), Vector2(0, -180), 4.8, 0.0)
		extension_block = spike_blocks.back()
	elif number % 3 == 2:
		_spring(Vector2(start + 120, floor_y))
		_bumper(Vector2(start + 780, floor_y - 260))
	passage_route.assign([Vector2(old_width + 100, floor_y - 28), Vector2(start + 330, floor_y - 188), Vector2(start + 610, floor_y - 258), Vector2(start + 810, floor_y - 130), passage_rect.get_center() - Vector2(0, 26)])


func open_passage() -> void:
	exit_open = true
	if is_instance_valid(passage_gate):
		_set_door(passage_gate, false)
	queue_redraw()


func set_entrance_intact(intact: bool) -> void:
	entrance_wall.collision_layer = 1 if intact else 0
	_set_door(entrance_wall, intact)
	breach_left = 0.0 if intact else 0.45
	queue_redraw()


func _build_spike_corridor() -> void:
	size = Vector2(2880, 1200)
	spawn = Vector2(220, 1014)
	enemy_spawn = Vector2(70, 1014)
	prepared = true
	chase_delay = 1.5
	_floor(0, 720, 1040)
	_floor(980, 640, 940)
	_floor(1920, 960, 840)
	_platforms([Rect2(470, 850, 130, 30), Rect2(740, 880, 180, 30), Rect2(1650, 790, 180, 30), Rect2(2250, 660, 210, 30)])
	_block(Rect2(1280, 680, 40, 180))
	_supply(LIGHT, Vector2(400, 1000))
	_supply(LIGHT, Vector2(1430, 900))
	_crystal(Vector2(820, 750), 0)
	_crystal(Vector2(1730, 650), 1)
	_spike_block(Vector2(650, 650), Vector2(0, 320), 4.4, 0.0)
	_spike_block(Vector2(1120, 620), Vector2(260, 0), 4.8, 0.5)
	_spike_block(Vector2(1860, 520), Vector2(0, 330), 4.6, 0.2)
	_spike_block(Vector2(2480, 570), Vector2(110, 150), 5.2, 0.5)
	exit_position = Vector2(2720, 840)
	route.assign([Vector2(530, 820), Vector2(810, 850), Vector2(1120, 910), Vector2(1450, 910), Vector2(1730, 760), Vector2(2070, 810), Vector2(2350, 630), Vector2(2730, 720)])


func _build_final() -> void:
	size = Vector2(5600, 1680)
	spawn = Vector2(350, 1294)
	enemy_spawn = Vector2(70, 1294)
	prepared = true
	chase_delay = 2.5
	preferred_item = "JUMP"
	_floor(0, 4420, 1320)
	_floor(4420, 120, 1400)
	_floor(4540, 1060, 1320)
	battle_arena = Rect2(28, 28, 5544, 1352)
	_supply(LIGHT, Vector2(900, 1280))
	_supply(HEAVY, Vector2(4350, 1280))
	_supply(LIGHT, Vector2(2250, 1280))
	_supply(LIGHT, Vector2(2540, 1280))
	_supply(LIGHT, Vector2(3750, 1280))
	_supply(CREATURE, Vector2(520, 1130))
	# Preparing power does not close the cage. The player must reach the remote console.
	cage = Rect2(5040, 1020, 360, 300)
	_block(Rect2(5040, 990, 360, 30))
	cage_doors.append(_block(Rect2(5008, 1020, 30, 300)))
	cage_doors.append(_block(Rect2(5402, 1020, 30, 300)))
	for door in cage_doors:
		_set_door(door, false)
	# A recessed tray keeps passing actors from pushing the prepared weight off its switch.
	seal_button = _button(Vector2(4480, 1400), 8.0)
	seal_button.pressed_changed.connect(func(_pressed): queue_redraw())
	seal_console = Vector2(5000, 1240)
	_platforms([Rect2(4950, 1240, 130, 30)])
	# Separate left and right escape keys require crossing the arena, not waiting by the cage.
	_platforms([Rect2(430, 1160, 230, 30), Rect2(690, 1020, 220, 30), Rect2(1030, 860, 220, 30), Rect2(620, 700, 250, 30), Rect2(1170, 780, 230, 30), Rect2(1530, 700, 230, 30), Rect2(1910, 710, 230, 30), Rect2(2310, 860, 230, 30), Rect2(2740, 710, 230, 30), Rect2(3150, 580, 260, 30), Rect2(3420, 680, 380, 30), Rect2(3910, 530, 220, 30)])
	_floor(4180, 300, 420)
	_platforms([Rect2(4550, 440, 240, 30), Rect2(4900, 370, 240, 30)])
	_floor(5260, 340, 300)
	_block(Rect2(2200, 1090, 550, 30))
	_block(Rect2(820, 1100, 250, 24))
	_block(Rect2(1500, 1000, 650, 24))
	_block(Rect2(620, 480, 250, 24))
	_block(Rect2(1910, 490, 230, 24))
	_block(Rect2(3150, 360, 260, 24))
	_block(Rect2(5260, 80, 220, 24))
	_block(Rect2(3630, 1060, 540, 30))
	_block(Rect2(4260, 1060, 650, 28))
	_supply(UMBRELLA, Vector2(2010, 1280))
	_supply(UMBRELLA, Vector2(4020, 1280))
	_supply(LIGHT, Vector2(4750, 1280))
	_crystal(Vector2(4690, 340), 0)
	_crystal(Vector2(5060, 260), 1)
	_supply(CREATURE, Vector2(2390, 820))
	_supply(LIGHT, Vector2(5000, 1200))
	_crystal(Vector2(900, 780), 1)
	_crystal(Vector2(1450, 660), 0)
	_crystal(Vector2(2240, 650), 1)
	_crystal(Vector2(2680, 660), 0)
	_crystal(Vector2(3510, 540), 1)
	_crystal(Vector2(4010, 420), 0)
	_spike_block(Vector2(2470, 660), Vector2(0, 240), 4.6, 0.0)
	_spike_block(Vector2(3650, 470), Vector2(0, 260), 5.2, 0.5)
	for at in [Vector2(740, 640), Vector2(3280, 520)]:
		var key := KEY.new()
		key.position = at
		add_child(key)
		key.collected.connect(func():
			keys_collected += 1
			key_collected = keys_collected == escape_keys.size()
		)
		escape_keys.append(key)
	escape_key = escape_keys[0]
	exit_position = Vector2(5460, 300)
	route.assign([Vector2(530, 1130), Vector2(780, 990), Vector2(1140, 830), Vector2(740, 670), Vector2(1280, 750), Vector2(1650, 670), Vector2(2030, 680), Vector2(2370, 830), Vector2(2860, 680), Vector2(3280, 550), Vector2(3500, 650), Vector2(4020, 500), Vector2(4310, 390), Vector2(4670, 410), Vector2(5020, 340), Vector2(5450, 190)])


func update_escape(time_ready: bool) -> void:
	var unlocked := time_ready and key_collected and all_weight_doors_open()
	if unlocked == escape_unlocked and arrival.get_meta("escape_initialized", false):
		return
	escape_unlocked = unlocked
	arrival.set_meta("escape_initialized", true)
	arrival.set_progress(0 if unlocked else 1, 1, "escape", "20秒の対峙と\n左右の鍵2つが必要")


func item_on_switch(item: Grabbable) -> bool:
	if seal_button != null and seal_button.get_overlapping_bodies().has(item):
		return true
	for entry in doors:
		if entry.button.get_overlapping_bodies().has(item):
			return true
	return false


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if breach_left > 0.0:
		breach_left = maxf(0.0, breach_left - delta)
		queue_redraw()
	for spike in spike_blocks:
		spike.advance(delta)
	for entry in doors:
		_set_door(entry.body, not entry.button.is_pressed() if not entry.closes else entry.button.is_pressed())
	for entry in moving_hazards:
		entry.current = Rect2(entry.rect.position + entry.travel * (0.5 - 0.5 * cos(_elapsed * TAU / entry.period)), entry.rect.size)
		entry.surface.position = entry.current.get_center()
	_supply_left -= delta
	if _supply_left <= 0.0:
		_supply_left = 0.75
		_restock()
	if not moving_hazards.is_empty():
		queue_redraw()


func _restock() -> void:
	for supply in supplies:
		var available := false
		var matching: Array[Grabbable] = []
		for item in $Items.get_children():
			if item.get_meta("supply", -1) != supply.id or is_instance_valid(item.pinned_to):
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
				var on_switch := item_on_switch(item)
				if item.carrier == null and not on_switch and not is_instance_valid(item.pinned_to):
					item.reset_for_respawn()
					break


func reset_state() -> void:
	for cloud in $AshClouds.get_children():
		cloud.free()
	for needle in needles.get_children():
		needle.free()
	for platform in brittle_platforms:
		platform.collision_layer = 1
		platform.show()
	_elapsed = 0.0
	_supply_left = 0.0
	for entry in moving_hazards:
		entry.current = entry.rect
		entry.surface.position = entry.rect.get_center()
	exit_open = false
	if is_instance_valid(passage_gate):
		_set_door(passage_gate, true)
	key_collected = false
	keys_collected = 0
	_console_occupied = false
	_seal_triggered = false
	escape_unlocked = false
	arrival.reset_for_respawn(true)
	if number == FINAL_ROOM:
		arrival.set_meta("escape_initialized", false)
		update_escape(false)
	for child in get_children():
		if child.has_method("reset_for_respawn") and child != arrival:
			child.reset_for_respawn()
	for entry in doors:
		_set_door(entry.body, not entry.closes)
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
	if actor.is_in_group("spike_immune"):
		return false
	var tangent := actor.get_walk_axis()
	var down := actor.get_gravity_vector()
	var rectangles: Array = hazards.duplicate()
	for needle in needles.get_children():
		if needle.stuck and needle.is_dangerous():
			rectangles.append(Rect2(needle.tip_position() - Vector2(4, 4), Vector2(8, 8)))
	for entry in moving_hazards:
		rectangles.append(entry.current)
	for spike in spike_blocks:
		rectangles.append(Rect2(spike.global_position - spike.hit_extent(), spike.hit_extent() * 2.0))
	for rect: Rect2 in rectangles:
		var half_along := (absf(tangent.x) * rect.size.x + absf(tangent.y) * rect.size.y) * 0.5
		var half_down := (absf(down.x) * rect.size.x + absf(down.y) * rect.size.y) * 0.5
		var ahead := (rect.get_center() - actor.position).dot(tangent) * signf(direction) - half_along
		var top := rect.get_center().dot(down) - half_down
		if actor.is_on_floor() and top > actor.position.dot(down) + 32:
			continue
		if actor.is_on_floor() and top + half_down * 2.0 < actor.position.dot(down) - 26.0:
			continue
		if ahead > -30 and ahead < 210 and actor.position.dot(down) > top - 120 and actor.position.dot(down) < top + half_down * 2 + 100:
			return true
	return false


func seal_enemy(enemy: PlayerController, player: PlayerController) -> bool:
	if seal_button == null:
		return false
	var occupied := player.gravity_direction == 1 and player.is_on_floor() and Rect2(seal_console - Vector2(65, 45), Vector2(130, 50)).has_point(player.position)
	var stepped := occupied and not _console_occupied
	_console_occupied = occupied
	if not stepped or not seal_button.is_pressed() or not all_weight_doors_open():
		return false
	if enemy.stun_left <= 0.0 or not cage.encloses(Rect2(enemy.position - Vector2(26, 26), Vector2(52, 52))):
		return false
	for door in cage_doors:
		_set_door(door, true)
	_seal_triggered = true
	return true


func can_launch_projectiles(origin: Vector2, excluded: Array[RID], count: int) -> bool:
	if needles.get_child_count() + count > MAX_NEEDLES:
		return false
	var flying := 0
	for needle in needles.get_children():
		if not needle.stuck and not needle.is_queued_for_deletion():
			flying += 1
	if flying + count > MAX_FLYING_NEEDLES:
		return false
	var query := PhysicsPointQueryParameters2D.new()
	query.position = origin
	query.collision_mask = 1
	query.exclude = excluded
	return get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


func _spike_block(at: Vector2, travel: Vector2, period: float, phase: float) -> void:
	var spike: SpikeBlock = SPIKE_BLOCK.instantiate()
	spike.position = at
	spike.travel = travel
	spike.period = period
	spike.phase = phase
	spike.external_collision = true
	add_child(spike)
	spike_blocks.append(spike)


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


func break_needle_platform(body: StaticBody2D) -> void:
	if body in brittle_platforms:
		body.collision_layer = 0
		body.hide()


func _supply(scene: PackedScene, at: Vector2) -> void:
	var id := supplies.size()
	supplies.append({"id": id, "scene": scene, "at": at})
	_spawn_item(scene, at, id)


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


func _spring(at: Vector2, angle := 0.0) -> void:
	var spring := SPRING.instantiate()
	spring.position = at
	spring.rotation = angle
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
	var surface := AnimatableBody2D.new()
	surface.collision_layer = 2
	surface.collision_mask = 0
	surface.position = rect.get_center()
	var collision := CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	collision.shape.size = rect.size
	surface.add_child(collision)
	add_child(surface)
	if travel.is_zero_approx():
		hazards.append(rect)
	else:
		moving_hazards.append({"rect": rect, "current": rect, "travel": travel, "period": period, "surface": surface})


func _draw() -> void:
	if passage_rect.has_area():
		var at := passage_rect.get_center()
		var color := Color("8de8b0") if exit_open else Color("ffd37d")
		for i in 3:
			var point := at + Vector2(i * 22 - 40, -50)
			draw_polyline(PackedVector2Array([point + Vector2(-8, -12), point + Vector2(8, 0), point + Vector2(-8, 12)]), color, 4)
	if breach_left > 0.0:
		var center := entrance_wall.position
		for i in 12:
			var offset := Vector2(cos(i * 2.4), sin(i * 1.7)) * (1.0 - breach_left / 0.45) * 110.0
			draw_circle(center + offset, 7.0 * breach_left / 0.45, Color("c9b2a0"))
	for supply in supplies:
		ArtDraw.ellipse(self, supply.at + Vector2(0, 34), Vector2(36, 7), Color("ffdc78"), 2)
	for entry in moving_hazards:
		_draw_hazard(entry.current)
	for rect in hazards:
		_draw_hazard(rect)
	if cage.has_area():
		draw_rect(cage, Color(1, 0.8, 0.3, 0.07))
		var wire_start := seal_button.position + Vector2(0, 20)
		var wire_end := Vector2(cage.end.x, cage.position.y - 15)
		var powered: bool = seal_button.is_pressed()
		var light := Color("86e7a4") if _seal_triggered else Color("ffdc78")
		draw_polyline(PackedVector2Array([wire_start, Vector2(wire_start.x, wire_end.y), wire_end]), light if powered else Color(1, 0.8, 0.3, 0.25), 4)
		if powered and not _seal_triggered:
			var spark := Vector2(wire_start.x, lerpf(wire_start.y, wire_end.y, fposmod(_elapsed * 0.7, 1.0)))
			draw_circle(spark, 7, light)
		for x in range(int(cage.position.x), int(cage.end.x), 24):
			draw_line(Vector2(x, cage.position.y), Vector2(x, cage.end.y), Color(1, 0.8, 0.3, 0.25), 3)
		ArtDraw.ellipse(self, seal_console, Vector2(60, 9), Color("86e7a4") if seal_button.is_pressed() else Color("9b9baa"), 3)
		ArtDraw.footprints(self, seal_console - Vector2(0, 3), 0.8)
		draw_polyline(PackedVector2Array([wire_end, Vector2(seal_console.x, wire_end.y), seal_console]), Color("ffdc7888"), 3)
	for entry in doors:
		var from: Vector2 = entry.button.position + Vector2(0, 25)
		var to: Vector2 = entry.body.position
		draw_polyline(PackedVector2Array([from, Vector2(to.x, from.y), to]), Color(1, 0.8, 0.3, 0.4), 3)


func _draw_hazard(rect: Rect2) -> void:
	draw_rect(rect, Color("7a263b"))
	for x in range(int(rect.position.x), int(rect.end.x), 22):
		ArtDraw.polygon(self, PackedVector2Array([Vector2(x, rect.end.y), Vector2(x + 11, rect.position.y), Vector2(minf(x + 22, rect.end.x), rect.end.y)]), Color("ff7f8d"))
