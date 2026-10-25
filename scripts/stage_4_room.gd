extends Node2D
## Carry routes in room-local coordinates.

const TERRAIN = preload("res://scripts/terrain_art.gd")
const SPIKE = preload("res://scenes/spike_block.tscn")
const CREATURE = preload("res://scenes/jump_creature.tscn")
const WIND = preload("res://scenes/wind_area.tscn")
const GOAL = preload("res://scenes/arrival_switch.tscn")
const SCROLL = preload("res://scenes/scroll_collectible.tscn")
const BOOT = preload("res://scenes/jump_crystal.tscn")
const GATE = preload("res://scenes/gravity_gate.tscn")
const SPRING = preload("res://scenes/spring.tscn")
const SCROLL_MARK = preload("res://scripts/scroll_marker.gd")

@export_range(0, 14) var room_number := 0
var walls: Array[Rect2] = []
var exit_top := 500.0
var entrance_top := 620.0
var room_height := 720.0
var camera_offset_y := -80.0


func _ready() -> void:
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
		entrance_top = [1700.0, 1500.0, 1900.0, 1900.0, 2200.0, 2000.0][room_number - 9]
		room_height = entrance_top + 100.0
	if room_number == 11:
		camera_offset_y = -300.0
	_block("LeftWall", Rect2(0, 100, 36, room_height - 100))
	_block("Entrance", Rect2(36, entrance_top, 464 if room_number == 9 else 184, 40))
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
	for rect in walls:
		_block("Platform%d" % get_child_count(), rect, room_number in [0, 6, 8, 9, 11, 12, 14] or (room_number in [7, 10, 13] and rect != walls[0]))
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
	exit_top = 1000.0 if room_number == 13 else 500.0
	_block("Exit", Rect2(1160, exit_top, 120, 40), room_number == 10)
	# The reversed carrier cannot rest under the boundary before the fall reset.
	_block("ExitBarrier", Rect2(1280, 100, 24, room_height - (0 if room_number == 10 else 100)))
	if room_number != 0:
		_label("Checkpoint", Vector2(45, entrance_top + 47), "↺ %02d / %02d" % [room_number + 1, get_parent().get_child_count()], Color("81f6c2"), 16)
	_label("ExitLabel", Vector2(1180, exit_top + 48), "○ →", Color.WHITE, 22)
	var ceiling := SPIKE.instantiate()
	ceiling.name = "CeilingSpikes"
	ceiling.position = Vector2(640, 16)
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
	if room_number in [4, 6, 8, 9, 10, 11, 12, 14]:
		var edge := SPIKE.instantiate()
		edge.name = "LeftEdgeSpikes"
		edge.position = Vector2(36, 630 if room_number == 6 else (350 if room_number == 4 else 730))
		edge.rotation = -PI / 2
		edge.travel = Vector2.ZERO
		edge.ceiling_strip = true
		edge.strip_half_width = 590.0 if room_number == 6 else 250.0
		if room_number >= 9:
			edge.position.y = (entrance_top + 100) * 0.5
			edge.strip_half_width = (entrance_top - 100) * 0.5
		edge.room_number = room_number
		$Hazards.add_child(edge)
	var creature := CREATURE.instantiate()
	creature.name = "JumpCreature"
	creature.position = Vector2(175, entrance_top - 40)
	items.add_child(creature)
	_label("CarryHint", Vector2(110, 495), "Shift / ZL・ZR", Color("a7f5ac"), 18)
	var delivery_icon := Sprite2D.new()
	delivery_icon.name = "DeliveryIcon"
	delivery_icon.texture = creature.get_node("Visuals/Body").sprite_frames.get_frame_texture("default", 0)
	# Keep the final badge clear of the goal and a companion held on its cap.
	delivery_icon.position = Vector2(1220, exit_top - (250 if room_number in [13, 14] else 65))
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
	if room_number == 14:
		var goal := GOAL.instantiate()
		goal.name = "Goal"
		goal.position = Vector2(1220, exit_top)
		add_child(goal)
		goal.get_node("Bubble").hide()


func _block(label: String, rect: Rect2, one_way := false) -> void:
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
	item.position = at
	$Items.add_child(item)
	return item


func _wind(label: String, at: Vector2, size: Vector2, direction: Vector2, acceleration: float, speed: float) -> void:
	var wind := WIND.instantiate()
	wind.name = label
	wind.position = at
	wind.area_size = size
	wind.wind_direction = direction
	wind.wind_acceleration = acceleration
	wind.max_wind_speed = speed
	add_child(wind)


func _scroll_branch(id: String, at: Vector2, rest: Rect2, mark: Vector2) -> void:
	_block("ScrollRest", rest, true)
	var scroll := SCROLL.instantiate()
	scroll.name = "Scroll"
	scroll.position = at
	scroll.stage_id = "companion"
	scroll.scroll_id = id
	add_child(scroll)
	var marker := Node2D.new()
	marker.name = "ScrollMark"
	marker.position = mark
	marker.scale = Vector2.ONE * 0.4
	marker.modulate.a = 0.75
	marker.set_script(SCROLL_MARK)
	add_child(marker)
