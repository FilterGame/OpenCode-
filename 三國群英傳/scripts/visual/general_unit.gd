extends "res://scripts/visual/army_unit.gd"


func _ready() -> void:
	unit_kind = &"general"
	if max_hp < 320:
		max_hp = 420
	if hp <= 0 or hp > max_hp:
		hp = max_hp
	if max_mp < 100:
		max_mp = 100
	if mp < 0:
		mp = 0
	move_speed = minf(move_speed, 46.0)
	super._ready()


func _draw() -> void:
	super._draw()
	var cape_color := Color(0.92, 0.8, 0.25, 0.9) if team == 1 else Color(0.95, 0.4, 0.25, 0.9)
	var crown_color := Color(0.98, 0.85, 0.3)
	var back_dir := -_facing
	var cape_points := PackedVector2Array([
		Vector2(-9.0, -16.0),
		Vector2(-9.0 + 14.0 * back_dir, -9.0),
		Vector2(-5.0 + 11.0 * back_dir, 9.0),
		Vector2(-1.0, 5.0),
		Vector2(-9.0, -16.0)
	])
	draw_colored_polygon(cape_points, cape_color)
	draw_circle(Vector2(0.0, -36.0), 3.5, crown_color)
	draw_rect(Rect2(-5.0, -34.0, 10.0, 2.0), crown_color, true)
