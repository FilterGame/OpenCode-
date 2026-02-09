class_name PortraitDraw
extends Control

@export var is_player: bool = true

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var size_v: Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, size_v), Color("333333"))
	var center: Vector2 = size_v * 0.5
	draw_circle(center, minf(size_v.x, size_v.y) * 0.3, Color("ccaa88"))
	if is_player:
		draw_arc(center + Vector2(0, 5), minf(size_v.x, size_v.y) * 0.34, 0, PI, 24, Color.BLACK, 3.0)
		draw_rect(Rect2(center.x - 22, center.y - 28, 44, 8), Color.BLACK)
	else:
		draw_rect(Rect2(center.x - 30, center.y - 55, 60, 40), Color("550000"))
		draw_rect(Rect2(center.x - 4, center.y - 65, 8, 35), Color.RED)
