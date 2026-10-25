extends Node2D
## Carry routes in room-local coordinates.

const TERRAIN = preload("res://scripts/terrain_art.gd")
const SPIKE = preload("res://scenes/spike_block.tscn")
const CREATURE = preload("res://scenes/jump_creature.tscn")
const WIND = preload("res://scenes/wind_area.tscn")
const GOAL = preload("res://scenes/arrival_switch.tscn")
const SCROLL = preload("res://scenes/scroll_collectible.tscn")
const DASH = preload("res://scenes/refill_crystal.tscn")
const BOOT = preload("res://scenes/jump_crystal.tscn")
const GATE = preload("res://scenes/gravity_gate.tscn")
const SPRING = preload("res://scenes/spring.tscn")
const BUMPER = preload("res://scenes/pinball_spring.tscn")
const PARACHUTE = preload("res://scenes/parachute_creature.tscn")
const SCROLL_MARK = preload("res://scripts/scroll_marker.gd")

@export_range(0, 29) var room_number := 0
var walls: Array[Rect2] = []
var exit_top := 500.0
var entrance_top := 620.0
var room_height := 720.0
var room_width := 1280.0
var camera_offset_y := -80.0
var travel_direction := 1
var entrance_x := 110.0


func _ready() -> void:
	travel_direction = -1 if room_number in [25, 28] else 1
	var items := Node2D.new()
	items.name = "Items"
	add_child(items)
	var hazards := Node2D.new()
	hazards.name = "Hazards"
	add_child(hazards)
	if room_number == 1:
		entrance_top = 1700.0
		room_height = 1800.0
	elif room_number == 6:
		entrance_top = 1220.0
		room_height = 1320.0
	elif room_number == 7:
		entrance_top = 1800.0
		room_height = 1900.0
	elif room_number == 8:
		entrance_top = 1000.0
		room_height = 1100.0
	elif room_number >= 9:
		entrance_top = [1700.0, 1500.0, 1900.0, 1900.0, 2200.0, 2000.0, 2100.0, 1600.0, 1800.0, 2100.0, 2100.0, 1900.0, 1800.0, 2100.0, 2100.0, 2100.0, 2100.0, 2100.0, 1900.0, 2100.0, 2100.0][room_number - 9]
		room_height = entrance_top + (220.0 if room_number == 20 else 100.0)
	if room_number >= 15: room_width = 2560.0 if room_number == 23 else 1920.0
	entrance_x = route_x(110)
	if room_number in [11, 15]:
		camera_offset_y = -300.0
	_block("LeftWall", Rect2(0, 100, 36, room_height - 100))
	_block("Entrance", Rect2(36, entrance_top, 464 if room_number in [9, 15, 19, 23, 24, 28, 29] else 184, 40))
	# Each route has its own silhouette and movement problem.
	match room_number:
		0: # Jumping from the companion before grabbing it also cannot reach this landing.
			walls = [Rect2(370, 200, 450, 24), Rect2(960, 360, 120, 32)]
		1: # Wall-kick shaft and high-to-low transfers.
			walls = [Rect2(270, 300, 240, 1500), Rect2(550, 430, 100, 32), Rect2(800, 310, 40, 390), Rect2(1040, 440, 80, 32)]
		2: # Covered low crossing.
			walls = [Rect2(300, 580, 150, 32), Rect2(570, 550, 160, 32), Rect2(850, 580, 150, 32)]
			_block("LowRoof", Rect2(250, 260, 800, 45))
		3: # Ridge followed by descending landings.
			walls = [Rect2(310, 510, 110, 32), Rect2(530, 370, 110, 32), Rect2(750, 450, 90, 32), Rect2(980, 550, 100, 32)]
		4: # Long jumps over wide gaps.
			walls = [Rect2(850, 480, 230, 40)]
			var wind := WIND.instantiate()
			wind.name = "HighTailwind"
			wind.position = Vector2(500, 120)
			wind.area_size = Vector2(300, 40)
			wind.wind_direction = Vector2.RIGHT
			wind.wind_acceleration = 2000.0
			wind.max_wind_speed = 650.0
			add_child(wind)
		5: # Right, back left, then a long jump to the right.
			walls = [Rect2(300, 510, 120, 32), Rect2(560, 390, 120, 32), Rect2(340, 270, 130, 32), Rect2(790, 360, 130, 32), Rect2(1040, 450, 90, 32)]
		6: # Recover the companion and Dash between two high transfers.
			walls = [Rect2(370, 800, 220, 24), Rect2(760, 380, 250, 24), Rect2(1040, 470, 90, 24)]
		7: # A wall-kick shaft opens into a leftward turn and a lower crossing.
			walls = [Rect2(270, 500, 240, 1400), Rect2(70, 300, 130, 24), Rect2(550, 390, 180, 24), Rect2(930, 440, 130, 24)]
		8: # Enter the high wind, return left, then climb toward the final arrival.
			walls = [Rect2(850, 860, 230, 28), Rect2(560, 680, 200, 28), Rect2(880, 480, 250, 28)]
			var wind := WIND.instantiate()
			wind.name = "HighTailwind"
			wind.position = Vector2(500, 500)
			wind.area_size = Vector2(300, 40)
			wind.wind_direction = Vector2.RIGHT
			wind.wind_acceleration = 2000.0
			wind.max_wind_speed = 650.0
			add_child(wind)
		9:
			walls = [Rect2(600, 1140, 460, 24), Rect2(300, 850, 220, 24), Rect2(760, 550, 300, 24)]
			_item(BOOT, "JumpCrystal", Vector2(430, 1470))
			_scroll_branch("combo_left_02", Vector2(140, 650), Rect2(70, 720, 190, 24), Vector2(560, 930))
		10:
			walls = [Rect2(300, 350, 380, 24), Rect2(70, 920, 220, 24), Rect2(650, 670, 250, 24), Rect2(340, 600, 180, 24), Rect2(900, 420, 180, 24)]
			_item(GATE, "UpGate", Vector2(300, 1300)).target_gravity = -1
			_item(GATE, "DownGate", Vector2(220, 450)).target_gravity = 1
		11:
			walls = [Rect2(440, 1250, 330, 24), Rect2(180, 930, 220, 24), Rect2(760, 650, 300, 24)]
			var spring := SPRING.instantiate()
			spring.name = "Spring"
			spring.position = Vector2(205, entrance_top)
			spring.spring_speed = 1250.0
			add_child(spring)
		12:
			walls = [Rect2(850, 1760, 230, 28), Rect2(220, 1200, 580, 24), Rect2(820, 900, 260, 24), Rect2(1000, 650, 160, 24)]
			_item(BOOT, "JumpCrystal", Vector2(930, 1530))
			_wind("HighTailwind", Vector2(500, 1400), Vector2(300, 40), Vector2.RIGHT, 2000, 650)
			_scroll_branch("wind_left_03", Vector2(140, 1000), Rect2(70, 1070, 190, 24), Vector2(280, 1140))
		13:
			walls = [Rect2(270, 700, 240, 1600), Rect2(70, 400, 140, 24), Rect2(550, 650, 220, 24), Rect2(900, 900, 180, 24)]
		14:
			walls = [Rect2(370, 1580, 250, 24), Rect2(80, 1300, 240, 24), Rect2(720, 1020, 250, 24), Rect2(330, 740, 230, 24), Rect2(900, 500, 230, 24)]
			_wind("LastTailwind", Vector2(720, 510), Vector2(220, 80), Vector2.RIGHT, 900, 320)
		15:
			walls = [Rect2(480, 1440, 480, 24), Rect2(260, 1200, 250, 24), Rect2(900, 960, 300, 24), Rect2(1430, 720, 260, 24)]
			_item(DASH, "DashCrystal", Vector2(430, 1740))
			_scroll_branch("refill_left_04", Vector2(140, 950), Rect2(70, 1040, 190, 24), Vector2(510, 1280))
		16:
			walls = [Rect2(260, 400, 400, 24), Rect2(920, 800, 400, 24), Rect2(1450, 1300, 260, 24), Rect2(1050, 1000, 250, 24), Rect2(1620, 780, 180, 24)]
			_item(GATE, "UpGate", Vector2(300, 1400)).target_gravity = -1
			_item(GATE, "DownGate", Vector2(1260, 950)).target_gravity = 1
		17:
			walls = [Rect2(760, 1470, 580, 24), Rect2(1360, 500, 220, 1400)]
			_block("ShaftLeft", Rect2(1160, 300, 36, 1100))
			_wind("HighTailwind", Vector2(500, 1300), Vector2(650, 160), Vector2.RIGHT, 2000, 650)
			_scroll_branch("wind_shaft_05", Vector2(1030, 210), Rect2(950, 300, 200, 24), Vector2(1300, 330))
		18:
			walls = [Rect2(440, 1450, 460, 24), Rect2(180, 890, 420, 24), Rect2(900, 650, 360, 24), Rect2(1430, 820, 260, 24)]
			_spring("Spring", Vector2(205, entrance_top), 1250)
			_item(BOOT, "JumpCrystal", Vector2(500, 1220))
		19:
			walls = [Rect2(540, 1540, 600, 24), Rect2(320, 890, 400, 24), Rect2(1000, 650, 300, 24), Rect2(1470, 840, 250, 24)]
			_item(BOOT, "JumpCrystal", Vector2(430, 1870))
			_spring("Spring", Vector2(920, 1540), 1250)
			_scroll_branch("spring_left_06", Vector2(140, 620), Rect2(70, 700, 190, 24), Vector2(390, 790))
		20:
			walls = [Rect2(740, 1320, 580, 24), Rect2(400, 760, 420, 24), Rect2(1120, 540, 430, 24)]
			var bumper := BUMPER.instantiate()
			bumper.name = "Bumper"
			bumper.position = Vector2(248, entrance_top + 62)
			bumper.scale = Vector2.ONE * 2
			bumper.minimum_bounce_speed = 1750
			bumper.maximum_bounce_speed = 1750
			bumper.min_impact_normal_speed = 25
			add_child(bumper)
			_item(BOOT, "JumpCrystal", Vector2(1000, 1090))
		21:
			walls = [Rect2(260, 400, 400, 24), Rect2(70, 1100, 530, 24), Rect2(700, 450, 420, 24), Rect2(1280, 680, 380, 24)]
			_item(GATE, "UpGate", Vector2(300, 1600)).target_gravity = -1
			_item(GATE, "DownGate", Vector2(230, 500)).target_gravity = 1
			_spring("Spring", Vector2(480, 1100), 1250)
		22:
			walls = [Rect2(760, 1770, 580, 24), Rect2(1360, 800, 220, 1400)]
			_block("ShaftLeft", Rect2(1160, 600, 36, 1100))
			_wind("HighTailwind", Vector2(500, 1600), Vector2(650, 160), Vector2.RIGHT, 2000, 650)
			_scroll_branch("upper_wall_07", Vector2(1030, 510), Rect2(950, 600, 200, 24), Vector2(1300, 630))
		23:
			walls = [Rect2(540, 1540, 600, 24), Rect2(260, 980, 440, 24), Rect2(1050, 860, 400, 24), Rect2(2020, 760, 350, 24)]
			_item(BOOT, "JumpCrystal", Vector2(430, 1870))
			_item(BOOT, "UpperJumpCrystal", Vector2(800, 1310))
			_item(PARACHUTE, "ParachuteCreature", Vector2(950, 1500))
			_spring("ChoiceSpring", Vector2(1100, 1540), 1650)
			_wind("ChoiceTailwind", Vector2(1810, 820), Vector2(400, 260), Vector2.RIGHT, 1500, 320)
		24:
			walls = [Rect2(480, 1440, 480, 24), Rect2(260, 880, 480, 24), Rect2(900, 640, 360, 24), Rect2(1430, 820, 260, 24)]
			_item(DASH, "DashCrystal", Vector2(430, 1740))
			_item(BOOT, "JumpCrystal", Vector2(700, 1210))
			_scroll_branch("refill_upper_08", Vector2(140, 650), Rect2(70, 720, 190, 24), Vector2(400, 950))
		25:
			walls = [Rect2(440, 1450, 500, 24), Rect2(850, 400, 400, 24), Rect2(650, 900, 500, 24), Rect2(1280, 780, 380, 24)]
			_spring("Spring", Vector2(205, entrance_top), 1250)
			_item(GATE, "UpGate", Vector2(900, 1250)).target_gravity = -1
			_item(GATE, "DownGate", Vector2(800, 500)).target_gravity = 1
		26:
			walls = [Rect2(270, 800, 240, 1400), Rect2(1160, 600, 520, 24), Rect2(1450, 350, 350, 24)]
			_wind("HighTailwind", Vector2(820, 400), Vector2(650, 160), Vector2.RIGHT, 3500, 1200)
		27:
			walls = [Rect2(740, 1320, 580, 24), Rect2(900, 300, 400, 24), Rect2(650, 750, 600, 24), Rect2(1430, 650, 260, 24)]
			_bumper(Vector2(248, entrance_top + 62))
			_item(GATE, "UpGate", Vector2(1050, 1120)).target_gravity = -1
			_item(GATE, "DownGate", Vector2(820, 400)).target_gravity = 1
			_scroll_branch("inverted_left_09", Vector2(460, 500), Rect2(360, 580, 200, 24), Vector2(780, 810))
		28:
			walls = [Rect2(540, 1540, 600, 24), Rect2(1450, 960, 400, 24), Rect2(900, 600, 400, 24)]
			_item(BOOT, "JumpCrystal", Vector2(430, 1870))
			_bumper(Vector2(1188, 1602))
		29:
			walls = [Rect2(480, 1440, 600, 24), Rect2(750, 790, 460, 24), Rect2(300, 550, 300, 24), Rect2(1000, 570, 400, 24)]
			_item(DASH, "DashCrystal", Vector2(430, 1740))
			_spring("Spring", Vector2(900, 1440), 1250)

	for rect in walls:
		_block("Platform%d" % get_child_count(), rect, room_number in [0, 6, 8, 9, 11, 12, 14, 15, 18, 19, 20, 23] or (room_number in [7, 10, 13] and rect != walls[0]) or (room_number == 16 and rect not in [walls[0], walls[1]]) or (room_number in [17, 22] and rect == walls[0]) or (room_number == 21 and rect != walls[0]) or (room_number >= 24 and not (room_number in [25, 27] and rect == walls[1]) and not (room_number == 26 and rect == walls[0])))
	if travel_direction == -1:
		for index in walls.size(): walls[index] = route_rect(walls[index])
	if room_number == 6:
		_block("ScrollRest", Rect2(50, 600, 220, 24), true)
		var marker := Node2D.new()
		marker.name = "ScrollMark"
		marker.position = Vector2(395, 740)
		marker.scale = Vector2.ONE * 0.4
		marker.modulate.a = 0.75
		marker.set_script(SCROLL_MARK)
		add_child(marker)
		var scroll := SCROLL.instantiate()
		scroll.name = "Scroll"
		scroll.position = Vector2(180, 530)
		scroll.stage_id = "companion"
		scroll.scroll_id = "relay_left_01"
		add_child(scroll)
	exit_top = 1000.0 if room_number == 13 else (700.0 if room_number in [15, 16, 18, 19, 21, 22, 23] else (550.0 if room_number == 26 else (700.0 if room_number >= 24 else 500.0)))
	_block("Exit", Rect2(room_width - 120, exit_top, 120, 40), room_number in [10, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29])
	# The reversed carrier cannot rest under the boundary before the fall reset.
	_block("ExitBarrier", Rect2(room_width, 100, 24, room_height - (0 if room_number in [10, 16, 21, 25, 27] else 100)))
	if room_number != 0:
		_label("Checkpoint", Vector2(45 if travel_direction == 1 else room_width - 175, entrance_top + 47), "↺ %02d / %02d" % [room_number + 1, get_parent().get_child_count()], Color("81f6c2"), 16)
	_label("ExitLabel", Vector2(room_width - 100 if travel_direction == 1 else 35, exit_top + 48), "○ →" if travel_direction == 1 else "← ○", Color.WHITE, 22)
	var ceiling := SPIKE.instantiate()
	ceiling.name = "CeilingSpikes"
	ceiling.position = Vector2(room_width * 0.5, 16)
	ceiling.strip_half_width = room_width * 0.5
	ceiling.travel = Vector2.ZERO
	ceiling.ceiling_strip = true
	ceiling.room_number = room_number
	$Hazards.add_child(ceiling)
	match room_number:
		0:
			_spike(Vector2(300, 450), Vector2(0, 140), 3.8, 0.15)
			_spike(Vector2(900, 210), Vector2(0, 250), 4.2, 0.55)
		1:
			_spike(Vector2(150, 320), Vector2(0, 190), 3.6, 0.4)
			_spike(Vector2(700, 230), Vector2(0, 260), 3.8, 0.0)
			_spike(Vector2(530, 200), Vector2(0, 260), 4.1, 0.5)
			_spike(Vector2(940, 120), Vector2(0, 380), 4.3, 0.25)
		2:
			_spike(Vector2(480, 410), Vector2(0, 160), 3.4, 0.0)
			_spike(Vector2(770, 400), Vector2(0, 170), 3.7, 0.4)
			_spike(Vector2(260, 380), Vector2(300, 0), 4.2, 0.5)
			_spike(Vector2(1080, 360), Vector2(0, 290), 3.9, 0.2)
		3:
			_spike(Vector2(680, 220), Vector2(0, 300), 3.6, 0.0)
			_spike(Vector2(870, 360), Vector2(0, 250), 3.5, 0.3)
			_spike(Vector2(450, 300), Vector2(0, 230), 4.2, 0.5)
			_spike(Vector2(1120, 330), Vector2(0, 240), 4.0, 0.15)
		4:
			_spike(Vector2(500, 100), Vector2(0, 510), 3.7, 0.9)
			_spike(Vector2(830, 350), Vector2(0, 260), 3.9, 0.3)
			_spike(Vector2(280, 390), Vector2(0, 210), 4.3, 0.5)
			_spike(Vector2(1120, 350), Vector2(0, 220), 4.1, 0.15)
		5:
			_spike(Vector2(490, 180), Vector2(0, 330), 4.0, 0.0)
			_spike(Vector2(960, 250), Vector2(0, 290), 3.8, 0.0)
			_spike(Vector2(250, 200), Vector2(0, 400), 4.3, 0.5)
			_spike(Vector2(710, 180), Vector2(0, 300), 4.5, 0.4)
		6:
			_spike(Vector2(650, 420), Vector2(0, 160), 4.0, 0.5)
		7:
			_spike(Vector2(780, 240), Vector2(0, 180), 4.2, 0.5)
		8:
			_spike(Vector2(810, 700), Vector2(0, 160), 4.0, 0.0)
	if room_number in [4, 6, 8, 9, 10, 11, 12, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29]:
		var edge := SPIKE.instantiate()
		edge.name = "LeftEdgeSpikes"
		edge.position = Vector2(route_x(36), 630 if room_number == 6 else (350 if room_number == 4 else 730))
		edge.rotation = -PI / 2 * travel_direction
		edge.travel = Vector2.ZERO
		edge.ceiling_strip = true
		edge.strip_half_width = 590.0 if room_number == 6 else 250.0
		if room_number >= 9:
			edge.position.y = (entrance_top + 100) * 0.5
			edge.strip_half_width = (entrance_top - 100) * 0.5
		if room_number == 26:
			edge.position.y = 550
			edge.strip_half_width = 100
		edge.room_number = room_number
		$Hazards.add_child(edge)
	var creature := CREATURE.instantiate()
	creature.name = "JumpCreature"
	creature.position = Vector2(route_x(175), entrance_top - 40)
	items.add_child(creature)
	_label("CarryHint", Vector2(110, 495), "Shift / ZL・ZR", Color("a7f5ac"), 18)
	var delivery_icon := Sprite2D.new()
	delivery_icon.name = "DeliveryIcon"
	delivery_icon.texture = creature.get_node("Visuals/Body").sprite_frames.get_frame_texture("default", 0)
	# Keep the final badge clear of the goal and a companion held on its cap.
	delivery_icon.position = Vector2(route_x(room_width - 60), exit_top - (250 if room_number in [13, 17, 23, 29] else 65))
	if room_number in [6, 9, 10]:
		# The upper rest's camera would place an overhead badge under the pause button.
		delivery_icon.position.y = exit_top + 90
	delivery_icon.scale = Vector2.ONE * (42.0 / delivery_icon.texture.get_width())
	add_child(delivery_icon)
	var delivery_frame := Line2D.new()
	delivery_frame.name = "DeliveryFrame"
	delivery_frame.position = delivery_icon.position
	delivery_frame.points = PackedVector2Array([Vector2(-32, -30), Vector2(32, -30), Vector2(32, 30), Vector2(-32, 30)])
	delivery_frame.closed = true
	delivery_frame.width = 3.0
	delivery_frame.default_color = Color("a7f5ac")
	add_child(delivery_frame)
	if room_number == 29:
		var goal := GOAL.instantiate()
		goal.name = "Goal"
		goal.position = Vector2(route_x(room_width - 90), exit_top)
		add_child(goal)
		goal.get_node("Bubble").hide()


func _block(label: String, rect: Rect2, one_way := false) -> void:
	rect = route_rect(rect)
	var body := StaticBody2D.new()
	body.name = label
	body.position = rect.get_center()
	var collider := CollisionShape2D.new()
	collider.name = "Collision"
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	collider.one_way_collision = one_way
	body.add_child(collider)
	var art := Polygon2D.new()
	art.name = "Visual"
	art.set_script(TERRAIN)
	var half := rect.size * 0.5
	art.polygon = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	body.add_child(art)
	add_child(body)


func _spike(at: Vector2, travel: Vector2, period: float, phase: float) -> void:
	var spike := SPIKE.instantiate()
	spike.name = "Spike%d" % ($Hazards.get_child_count())
	spike.position = at
	spike.travel = travel
	spike.period = period
	spike.phase = phase
	spike.room_number = room_number
	$Hazards.add_child(spike)


func _label(label: String, at: Vector2, value: String, tint: Color, font_size: int) -> void:
	var text := Label.new()
	text.name = label
	text.position = at
	text.text = value
	text.modulate = tint
	text.add_theme_font_size_override("font_size", font_size)
	add_child(text)


func _item(scene: PackedScene, label: String, at: Vector2) -> Node2D:
	var item := scene.instantiate() as Node2D
	item.name = label
	item.position = Vector2(route_x(at.x), at.y)
	$Items.add_child(item)
	return item


func _wind(label: String, at: Vector2, size: Vector2, direction: Vector2, acceleration: float, speed: float) -> void:
	var wind := WIND.instantiate()
	wind.name = label
	wind.position = Vector2(route_x(at.x), at.y)
	wind.area_size = size
	wind.wind_direction = Vector2(direction.x * travel_direction, direction.y)
	wind.wind_acceleration = acceleration
	wind.max_wind_speed = speed
	add_child(wind)


func _scroll_branch(id: String, at: Vector2, rest: Rect2, mark: Vector2) -> void:
	_block("ScrollRest", rest, true)
	var scroll := SCROLL.instantiate()
	scroll.name = "Scroll"
	scroll.position = Vector2(route_x(at.x), at.y)
	scroll.stage_id = "companion"
	scroll.scroll_id = id
	add_child(scroll)
	var marker := Node2D.new()
	marker.name = "ScrollMark"
	marker.position = Vector2(route_x(mark.x), mark.y)
	marker.scale = Vector2.ONE * 0.4
	marker.modulate.a = 0.75
	marker.set_script(SCROLL_MARK)
	add_child(marker)


func _spring(label: String, at: Vector2, speed: float) -> void:
	var spring := SPRING.instantiate()
	spring.name = label
	spring.position = Vector2(route_x(at.x), at.y)
	spring.spring_speed = speed
	add_child(spring)


func route_x(x: float) -> float:
	return x if travel_direction == 1 else room_width - x


func route_rect(rect: Rect2) -> Rect2:
	return rect if travel_direction == 1 else Rect2(room_width - rect.end.x, rect.position.y, rect.size.x, rect.size.y)


func _bumper(at: Vector2) -> void:
	var bumper := BUMPER.instantiate()
	bumper.name = "Bumper"
	bumper.position = Vector2(route_x(at.x), at.y)
	bumper.scale = Vector2.ONE * 2
	bumper.minimum_bounce_speed = 1750
	bumper.maximum_bounce_speed = 1750
	bumper.min_impact_normal_speed = 25
	add_child(bumper)
