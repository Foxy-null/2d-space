extends Node2D
## The target area locks when cast; smoke gathers before any ash can fall.

signal rain(at: Vector2, down: Vector2)

const CLOUD := preload("res://assets/enemies/star-mountain/ash-cloud.png")
const SWIRL := preload("res://assets/enemies/star-mountain/ash-swirl.gdshader")
var smoke_origin := Vector2.ZERO
var down := Vector2.DOWN
var elapsed := 0.0
var waves := 0
var picture: Sprite2D


func _ready() -> void:
	rotation = Vector2.DOWN.angle_to(down)
	picture = Sprite2D.new()
	# Give the shader the same cropped UV space used in the approved preview.
	picture.texture = ImageTexture.create_from_image(CLOUD.get_image().get_region(CLOUD.get_image().get_used_rect()))
	var shader := ShaderMaterial.new()
	shader.shader = SWIRL
	shader.set_shader_parameter("aspect", float(picture.texture.get_width()) / picture.texture.get_height())
	shader.set_shader_parameter("vortices", PackedVector4Array([
		Vector4(0.233, 0.719, 0.19, -1), Vector4(0.2965, 0.2624, 0.19, 1),
		Vector4(0.5617, 0.5007, 0.26, -1), Vector4(0.9236, 0.5433, 0.23, 1),
	]))
	picture.material = shader
	add_child(picture)
	_update_picture()


func advance(delta: float) -> void:
	elapsed += delta
	# Alternating rows keep 160px lanes while covering a wider predicted landing zone.
	while waves < 8 and elapsed >= 1.3 + waves * 0.45:
		for slot in 9:
			if slot % 2 == waves % 2:
				rain.emit(to_global(Vector2((slot - 4) * 80, 24)), down)
		waves += 1
	_update_picture()
	queue_redraw()
	if elapsed >= 5.7:
		queue_free()


func _update_picture() -> void:
	var forming := smoothstep(0.2, 1.1, elapsed)
	picture.scale = Vector2.ONE * 760.0 / picture.texture.get_width() * lerpf(0.12, 1.0, forming)
	picture.modulate.a = forming * (1.0 - smoothstep(5.0, 5.7, elapsed))
	picture.material.set_shader_parameter("phase", fposmod(elapsed, 4.0) * TAU / 4.0)


func _draw() -> void:
	if elapsed < 1.3:
		var origin := to_local(smoke_origin)
		for index in 14:
			var progress := clampf(elapsed / 1.1 - index * 0.035, 0.0, 1.0)
			var at := origin.lerp(Vector2.ZERO, progress) + Vector2(16 * sin(progress * TAU + index), -28 * sin(progress * PI))
			draw_circle(at, 10 + progress * 17, Color(0.42, 0.4, 0.37, sin(progress * PI) * 0.6))
	# Gold seeds signal the next row before it drops, rather than marking a hitbox.
	if waves < 8 and elapsed > 0.8:
		for slot in 9:
			if slot % 2 == waves % 2:
				draw_line(Vector2((slot - 4) * 80, 40), Vector2((slot - 4) * 80, 66), Color("ffdf70"), 3, true)
