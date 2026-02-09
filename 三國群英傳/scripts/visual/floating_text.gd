extends Node2D

@export var lifetime: float = 1.1

var speed_scale: float = 1.0
var _elapsed: float = 0.0
var _text: String = "-0"
var _color: Color = Color(1.0, 1.0, 1.0, 1.0)
var _velocity: Vector2 = Vector2(0.0, -52.0)


func _ready() -> void:
	add_to_group(&"battle_actor")
	queue_redraw()


func setup(text_value: String, world_pos: Vector2, text_color: Color = Color(1.0, 1.0, 1.0)) -> void:
	_text = text_value
	global_position = world_pos
	_color = text_color
	_elapsed = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	var scaled_delta := delta * speed_scale
	_elapsed += scaled_delta
	if _elapsed >= lifetime:
		queue_free()
		return
	global_position += _velocity * scaled_delta
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return

	var font_size := 24
	var alpha := 1.0 - clampf(_elapsed / lifetime, 0.0, 1.0)
	var text_size := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var base := Vector2(-text_size.x * 0.5, 0.0)

	var shadow := Color(0.0, 0.0, 0.0, alpha * 0.9)
	var body := _color
	body.a = alpha
	draw_string(font, base + Vector2(1.2, 1.2), _text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, shadow)
	draw_string(font, base, _text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, body)
