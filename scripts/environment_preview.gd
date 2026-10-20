extends Node2D

const NAMES := ["宇宙基地", "生活圏のある惑星", "未開発の惑星", "煮えたぎる溶岩", "邪悪なオーラ"]
const SCENES := {
	"Player": preload("res://scenes/player.tscn"),
	"GateUp": preload("res://scenes/gravity_gate.tscn"),
	"GateDown": preload("res://scenes/gravity_gate.tscn"),
	"DashPickup": preload("res://scenes/refill_crystal.tscn"),
	"JumpPickup": preload("res://scenes/jump_crystal.tscn"),
	"Spring": preload("res://scenes/spring.tscn"),
	"Bumper": preload("res://scenes/pinball_spring.tscn"),
	"Wind": preload("res://scenes/wind_area.tscn"),
	"LightBox": preload("res://scenes/grabbable.tscn"),
	"HeavyBox": preload("res://scenes/heavy_object.tscn"),
	"Creature": preload("res://scenes/jump_creature.tscn"),
	"Umbrella": preload("res://scenes/parachute_creature.tscn"),
	"WeighingPlate": preload("res://scenes/pressure_button.tscn"),
	"Goal": preload("res://scenes/arrival_switch.tscn"),
}

var player: PlayerController
var backdrop: StageBackdrop
var environment_theme := 0


func _ready() -> void:
	set_meta("environment_theme", 0)
	var background := CanvasLayer.new()
	background.layer = -10
	add_child(background)
	backdrop = StageBackdrop.new()
	background.add_child(backdrop)
	_terrain("LeftFloor", Rect2(0, 640, 440, 80))
	_terrain("RightFloor", Rect2(920, 640, 360, 80))
	_terrain("Ceiling", Rect2(0, 0, 1280, 72))
	_terrain("LeftWall", Rect2(0, 72, 24, 568))
	_terrain("RightWall", Rect2(1256, 72, 24, 568))
	_terrain("LeftLedge", Rect2(280, 390, 180, 28))
	_terrain("RightLedge", Rect2(830, 390, 190, 28))
	var positions := {
		"Player": Vector2(60, 600), "GateUp": Vector2(425, 240), "GateDown": Vector2(945, 185),
		"DashPickup": Vector2(580, 210), "JumpPickup": Vector2(730, 220),
		"Spring": Vector2(380, 640), "Bumper": Vector2(650, 370),
		"Wind": Vector2(680, 560), "LightBox": Vector2(145, 550),
		"HeavyBox": Vector2(230, 550), "Creature": Vector2(315, 550),
		"Umbrella": Vector2(1060, 550), "WeighingPlate": Vector2(230, 640),
		"Goal": Vector2(1175, 640),
	}
	for name in SCENES:
		var object: Node2D = SCENES[name].instantiate()
		object.name = name
		object.position = positions[name]
		if name == "GateDown":
			object.target_gravity = 1
		elif name == "Wind":
			object.area_size = Vector2(240, 160)
			object.wind_direction = Vector2.UP
		elif name == "Goal":
			object.mission_required = false
		elif name == "Player":
			object.get_node("Camera2D").enabled = false
		add_child(object)
	player = $Player
	player.set_respawn_position(Vector2(60, 600))
	player.wall_actions_enabled = true
	player.dash_enabled = true
	var camera := Camera2D.new()
	camera.position = Vector2(640, 360)
	add_child(camera)
	camera.make_current()
	for theme in NAMES:
		$UI/Toolbar/Environment.add_item(theme)
	$UI/Toolbar/Environment.item_selected.connect(set_environment)
	$UI/Toolbar/Motion.toggled.connect(func(value): backdrop.motion_enabled = value)
	var arguments := OS.get_cmdline_user_args()
	for i in arguments.size():
		if arguments[i] == "--environment" and i + 1 < arguments.size():
			set_environment(arguments[i + 1].to_int())


func _terrain(node_name: String, rect: Rect2) -> void:
	var solid := StaticBody2D.new()
	solid.name = node_name
	solid.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	solid.add_child(collision)
	var art := TerrainArt.new()
	var half := rect.size * 0.5
	art.polygon = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	solid.add_child(art)
	add_child(solid)


func set_environment(index: int) -> void:
	environment_theme = clampi(index, 0, 4)
	set_meta("environment_theme", environment_theme)
	backdrop.environment_theme = environment_theme
	$UI/Toolbar/Environment.select(environment_theme)
	for art in find_children("*", "Polygon2D", true, false):
		if art is TerrainArt:
			art.environment_theme = environment_theme
	$Goal.queue_redraw()


func _physics_process(_delta: float) -> void:
	if player.position.y < -52 or player.position.y > 772:
		player.respawn()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_5:
			set_environment(event.physical_keycode - KEY_1)
		elif event.physical_keycode == KEY_M:
			$UI/Toolbar/Motion.button_pressed = not $UI/Toolbar/Motion.button_pressed
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			set_environment(posmod(environment_theme - 1, 5))
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			set_environment(posmod(environment_theme + 1, 5))
		elif event.button_index == JOY_BUTTON_Y:
			$UI/Toolbar/Motion.button_pressed = not $UI/Toolbar/Motion.button_pressed
