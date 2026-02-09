class_name FloatingText
extends Node2D

var life: float = 60.0
var text_value: String = ""
var text_color: Color = Color.WHITE
var font_size: int = 20

func setup_text(p_text: String, color: Color) -> void:
	text_value = p_text
	text_color = color
	queue_redraw()

func update_floating(delta_speed: float) -> bool:
	life -= delta_speed
	position.y -= 1.0 * delta_speed
	queue_redraw()
	return life <= 0.0

func _draw() -> void:
	var draw_col: Color = text_color
	draw_col.a = clampf(life / 60.0, 0.0, 1.0)
	var font: Font = ThemeDB.fallback_font
	if font:
		draw_string(font, Vector2.ZERO, text_value, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size, draw_col)
