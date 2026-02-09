extends Node2D


func _ready() -> void:
	if get_viewport() != null:
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	queue_redraw()


func _on_viewport_size_changed() -> void:
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	var horizon := size.y * 0.62

	draw_rect(Rect2(0.0, 0.0, size.x, horizon), Color(0.17, 0.29, 0.45), true)
	draw_rect(Rect2(0.0, horizon - 48.0, size.x, 48.0), Color(0.32, 0.38, 0.25), true)
	draw_rect(Rect2(0.0, horizon, size.x, size.y - horizon), Color(0.38, 0.28, 0.18), true)
	draw_rect(Rect2(0.0, horizon - 10.0, size.x, 12.0), Color(0.22, 0.44, 0.2), true)

	var left_mountain := PackedVector2Array([
		Vector2(size.x * 0.06, horizon),
		Vector2(size.x * 0.22, horizon - 130.0),
		Vector2(size.x * 0.4, horizon)
	])
	var mid_mountain := PackedVector2Array([
		Vector2(size.x * 0.24, horizon),
		Vector2(size.x * 0.45, horizon - 150.0),
		Vector2(size.x * 0.68, horizon)
	])
	var right_mountain := PackedVector2Array([
		Vector2(size.x * 0.6, horizon),
		Vector2(size.x * 0.8, horizon - 120.0),
		Vector2(size.x * 0.95, horizon)
	])

	draw_colored_polygon(left_mountain, Color(0.16, 0.21, 0.2, 0.88))
	draw_colored_polygon(mid_mountain, Color(0.15, 0.19, 0.19, 0.95))
	draw_colored_polygon(right_mountain, Color(0.16, 0.21, 0.2, 0.88))
