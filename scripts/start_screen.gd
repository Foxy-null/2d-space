extends Control

var _elapsed := 0.0

@onready var _logo: TextureRect = $Center/Content/Logo
@onready var _start_button: Button = $Center/Content/Start
@onready var _controls: Label = $Center/Content/Controls


func _ready() -> void:
	_start_button.grab_focus.call_deferred()
	# OS設定を取得できない場合の戻り値は-1、動きの抑制が指定された場合は1。
	if DisplayServer.accessibility_should_reduce_animation() == 1:
		$Backdrop.motion_enabled = false
		set_process(false)
		return

	_logo.resized.connect(func(): _logo.pivot_offset = _logo.size * 0.5)
	_logo.pivot_offset = _logo.size * 0.5
	_logo.draw.connect(_draw_sparkles)
	_logo.scale = Vector2.ONE * 0.92
	_logo.modulate.a = 0.0
	_start_button.modulate.a = 0.0
	_start_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls.modulate.a = 0.0
	var intro := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro.tween_property(_logo, "modulate:a", 1.0, 0.65)
	intro.parallel().tween_property(_logo, "scale", Vector2.ONE, 0.65)
	intro.tween_interval(0.15)
	intro.tween_callback(_start_button.set.bind("mouse_filter", Control.MOUSE_FILTER_STOP))
	intro.tween_property(_start_button, "modulate:a", 1.0, 0.3)
	intro.parallel().tween_property(_controls, "modulate:a", 1.0, 0.25).set_delay(0.1)
	intro.tween_callback(_breathe_logo)


func _breathe_logo() -> void:
	var motion := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(_logo, "scale", Vector2.ONE * 1.012, 2.8)
	motion.tween_property(_logo, "scale", Vector2.ONE, 2.8)


func _process(delta: float) -> void:
	_elapsed += delta
	_logo.queue_redraw()


func _draw_sparkles() -> void:
	var center := _logo.size * 0.5
	for index in 12:
		var phase := fposmod(_elapsed / 2.8 + float(index) / 12.0, 1.0)
		var glow := pow(sin(phase * PI), 2.0)
		var angle := TAU * float(index) / 12.0 + 0.035 * sin(_elapsed * TAU / 20.0 + index)
		var point := center + Vector2(cos(angle) * (center.x + 8.0), sin(angle) * (center.y + 8.0))
		var tint := Color(1.0, 0.85, 0.45, glow * 0.9) if index % 2 == 0 else Color(0.65, 0.96, 1.0, glow * 0.9)
		var radius := 3.0 + glow * 7.0
		_logo.draw_line(point - Vector2(radius, 0), point + Vector2(radius, 0), tint, 2.0, true)
		_logo.draw_line(point - Vector2(0, radius), point + Vector2(0, radius), tint, 2.0, true)
		_logo.draw_circle(point, 1.5, tint)


func _start() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")
