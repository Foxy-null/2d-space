extends Node2D

const SKY := preload("res://assets/environments/daylight-anime.png")
const SUNLIGHT := preload("res://assets/environments/daylight.gdshader")

var elapsed := 0.0


func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = SUNLIGHT


func _process(delta: float) -> void:
	elapsed = fposmod(elapsed + delta, 60.0)
	material.set_shader_parameter("elapsed", elapsed)
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(SKY, get_viewport_rect(), false)
