extends Node2D
## Six distinct carry routes in room-local coordinates.

const TERRAIN = preload("res://scripts/terrain_art.gd")
const SPIKE = preload("res://scenes/spike_block.tscn")
const CREATURE = preload("res://scenes/jump_creature.tscn")
const GOAL = preload("res://scenes/arrival_switch.tscn")

@export_range(0, 5) var room_number := 0
var walls: Array[Rect2] = []
var exit_top := 500.0


func _ready() -> void:
	var items := Node2D.new()
	items.name = "Items"
	add_child(items)
	var hazards := Node2D.new()
	hazards.name = "Hazards"
	add_child(hazards)
	_block("LeftWall", Rect2(0, 100, 36, 620))
	_block("Entrance", Rect2(36, 620, 184, 40))
	# Each route has its own silhouette and movement problem.
	match room_number:
		0: # Rising stairs.
			walls = [Rect2(320, 530, 130, 32), Rect2(570, 420, 130, 32), Rect2(820, 330, 140, 32), Rect2(1030, 440, 100, 32)]
		1: # Wall-kick shaft and high-to-low transfers.
			walls = [Rect2(270, 300, 40, 420), Rect2(550, 430, 100, 32), Rect2(800, 310, 40, 390), Rect2(1040, 440, 80, 32)]
		2: # Covered low crossing.
			walls = [Rect2(300, 580, 150, 32), Rect2(570, 550, 160, 32), Rect2(850, 580, 150, 32)]
			_block("LowRoof", Rect2(250, 260, 800, 45))
		3: # Ridge followed by descending landings.
			walls = [Rect2(310, 510, 110, 32), Rect2(530, 370, 110, 32), Rect2(750, 450, 90, 32), Rect2(980, 550, 100, 32)]
		4: # Long jumps over wide gaps.
			walls = [Rect2(350, 550, 90, 40), Rect2(670, 500, 90, 40), Rect2(970, 550, 90, 40)]
		5: # Right, back left, then a long jump to the right.
			walls = [Rect2(300, 510, 120, 32), Rect2(560, 390, 120, 32), Rect2(340, 270, 130, 32), Rect2(790, 360, 130, 32), Rect2(1040, 450, 90, 32)]
	for rect in walls:
		_block("Platform%d" % get_child_count(), rect)
	exit_top = 500.0
	_block("Exit", Rect2(1160, exit_top, 120, 40))
	_block("ExitBarrier", Rect2(1280, 100, 24, 620))
	_label("Checkpoint", Vector2(45, 667), "↺ %02d / 06" % (room_number + 1), Color("81f6c2"), 16)
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
			_spike(Vector2(500, 350), Vector2(0, 220), 3.8, 0.0)
			_spike(Vector2(750, 210), Vector2(0, 250), 4.2, 0.55)
		1:
			_spike(Vector2(150, 320), Vector2(0, 190), 3.6, 0.4)
			_spike(Vector2(700, 230), Vector2(0, 260), 3.8, 0.0)
			_spike(Vector2(430, 200), Vector2(0, 260), 4.1, 0.5)
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
			_spike(Vector2(500, 360), Vector2(0, 250), 3.7, 0.0)
			_spike(Vector2(830, 350), Vector2(0, 260), 3.9, 0.3)
			_spike(Vector2(280, 390), Vector2(0, 210), 4.3, 0.5)
			_spike(Vector2(1120, 350), Vector2(0, 220), 4.1, 0.15)
		5:
			_spike(Vector2(490, 180), Vector2(0, 330), 4.0, 0.0)
			_spike(Vector2(960, 250), Vector2(0, 290), 3.8, 0.0)
			_spike(Vector2(250, 200), Vector2(0, 400), 4.3, 0.5)
			_spike(Vector2(710, 180), Vector2(0, 300), 4.5, 0.4)
	var creature := CREATURE.instantiate()
	creature.name = "JumpCreature"
	creature.position = Vector2(175, 580)
	items.add_child(creature)
	_label("CarryHint", Vector2(110, 495), "Shift / ZL・ZR", Color("a7f5ac"), 18)
	var delivery_icon := Sprite2D.new()
	delivery_icon.name = "DeliveryIcon"
	delivery_icon.texture = creature.get_node("Visuals/Body").sprite_frames.get_frame_texture("default", 0)
	# Keep the final badge clear of the goal and a companion held on its cap.
	delivery_icon.position = Vector2(1220, exit_top - (250 if room_number == 5 else 65))
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
	if room_number == 5:
		var goal := GOAL.instantiate()
		goal.name = "Goal"
		goal.position = Vector2(1220, exit_top)
		add_child(goal)
		goal.get_node("Bubble").hide()


func _block(label: String, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = label
	body.position = rect.get_center()
	var collider := CollisionShape2D.new()
	collider.name = "Collision"
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
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
