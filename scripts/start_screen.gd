extends Control

var _elapsed := 0.0
var _landing_pulse := 0.0
var _launch_progress := 0.0
var _starting := false
var _intro: Tween
var _breathing: Tween

@onready var _logo: TextureRect = $Center/Content/Logo
@onready var _start_button: Button = $Center/Content/Start
@onready var _controls: Label = $Center/Content/Controls
@onready var _ninja: AnimatedSprite2D = $Mascot/Ninja
@onready var _effects: Node2D = $Effects


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
	_effects.draw.connect(_draw_effects)
	_ninja.play("jump")
	_fly_ninja(0.0)
	_logo.scale = Vector2.ONE * 0.92
	_logo.modulate.a = 0.0
	_start_button.modulate.a = 0.0
	_start_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls.modulate.a = 0.0
	_intro = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro.tween_property(_logo, "modulate:a", 1.0, 0.65)
	_intro.parallel().tween_property(_logo, "scale", Vector2.ONE, 0.65)
	_intro.tween_interval(0.15)
	_intro.tween_callback(_start_button.set.bind("mouse_filter", Control.MOUSE_FILTER_STOP))
	_intro.tween_property(_start_button, "modulate:a", 1.0, 0.3)
	_intro.parallel().tween_property(_controls, "modulate:a", 1.0, 0.25).set_delay(0.1)
	_intro.parallel().tween_method(_fly_ninja, 0.0, 1.0, 0.7).set_trans(Tween.TRANS_LINEAR)
	_intro.tween_callback(_land_ninja)
	_intro.tween_callback(_breathe_logo)


func _fly_ninja(progress: float) -> void:
	_ninja.position = Vector2(-size.x * 0.5, -20).bezier_interpolate(Vector2(-360, -300), Vector2(-100, -250), Vector2.ZERO, progress)
	_ninja.rotation = -0.35 * sin(progress * PI)


func _land_ninja() -> void:
	_ninja.play("idle")
	_landing_pulse = 1.0
	create_tween().tween_property(self, "_landing_pulse", 0.0, 0.4)


func _breathe_logo() -> void:
	_breathing = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathing.tween_property(_logo, "scale", Vector2.ONE * 1.012, 2.8)
	_breathing.tween_property(_logo, "scale", Vector2.ONE, 2.8)


func _process(delta: float) -> void:
	_elapsed += delta
	_logo.queue_redraw()
	_effects.queue_redraw()


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


func _draw_effects() -> void:
	if _landing_pulse > 0.0:
		var radius := 8.0 + (1.0 - _landing_pulse) * 50.0
		for index in 8:
			var direction := Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
			var point: Vector2 = $Mascot.position + Vector2(0, 48) + direction * Vector2(radius, radius * 0.35)
			_effects.draw_circle(point, 2.0 + _landing_pulse * 2.0, Color(1, 0.85, 0.45, _landing_pulse * 0.8))
	if _starting:
		_effects.draw_rect(Rect2(Vector2.ZERO, size), Color(0.018, 0.027, 0.075, _launch_progress))
		for index in 24:
			var direction := Vector2.RIGHT.rotated(TAU * float(index) / 24.0)
			var start := size * 0.5 + direction * (120.0 + _launch_progress * 240.0)
			var end := start + direction * _launch_progress * 420.0
			_effects.draw_line(start, end, Color(0.65, 0.96, 1, sin(_launch_progress * PI) * 0.85), 1.0 + _launch_progress * 2.0, true)


func _start() -> void:
	if _starting:
		return
	_starting = true
	if DisplayServer.accessibility_should_reduce_animation() == 1:
		get_tree().change_scene_to_file("res://scenes/stage_select.tscn")
		return
	_intro.kill()
	if _breathing != null:
		_breathing.kill()
	_start_button.disabled = true
	_ninja.play("jump")
	var launch := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	launch.tween_property(self, "_launch_progress", 1.0, 0.28)
	launch.tween_property(_ninja, "position", _ninja.position + Vector2(320, -640), 0.28)
	launch.chain().tween_callback(get_tree().change_scene_to_file.bind("res://scenes/stage_select.tscn"))
