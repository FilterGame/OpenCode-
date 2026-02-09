class_name BackgroundRenderer
extends Node2D

const GameConfig = preload("res://scripts/core/game_config.gd")

var ground_y: float = 540.0
var frame_count: int = 0
var camera_x: float = 0.0
var bg_mountains: Array[Vector2] = []
var bg_city: Array[float] = []
var bg_clouds: Array[Dictionary] = []

func _ready() -> void:
	randomize()
	init_assets()

func setup(p_ground_y: float) -> void:
	ground_y = p_ground_y
	init_assets()
	queue_redraw()

func tick(p_frame_count: int, p_camera_x: float) -> void:
	frame_count = p_frame_count
	camera_x = p_camera_x
	queue_redraw()

func init_assets() -> void:
	bg_mountains.clear()
	bg_city.clear()
	bg_clouds.clear()

	var x: float = 0.0
	while x < 3000.0:
		bg_mountains.append(Vector2(x, ground_y - 100.0 - randf() * 150.0))
		x += 100.0
	bg_mountains.append(Vector2(3000.0, ground_y))

	for i in 20:
		bg_city.append(100.0 + i * 100.0)

	for _i in 5:
		bg_clouds.append({
			"x": randf() * 2000.0,
			"y": randf() * 300.0,
			"w": 100.0 + randf() * 100.0,
			"speed": 0.2 + randf() * 0.2
		})

func _draw() -> void:
	# Sky
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), GameConfig.COLOR_BG_SKY)

	# Mountains
	draw_set_transform(Vector2(-camera_x * 0.2, 0), 0.0, Vector2.ONE)
	var mountain_points: PackedVector2Array = PackedVector2Array()
	mountain_points.append(Vector2(0, ground_y - 100.0))
	for pt in bg_mountains:
		mountain_points.append(pt)
	mountain_points.append(Vector2(3000, ground_y))
	mountain_points.append(Vector2(0, ground_y))
	draw_colored_polygon(mountain_points, Color("445566"))

	# Clouds
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for cloud in bg_clouds:
		var draw_x: float = fmod(cloud["x"] + frame_count * cloud["speed"], 3000.0) - 500.0 - camera_x * 0.1
		draw_ellipse(Vector2(draw_x, cloud["y"]), cloud["w"], 30.0, Color(1, 1, 1, 0.4))

	# City walls
	draw_set_transform(Vector2(-camera_x * 0.5, 0), 0.0, Vector2.ONE)
	draw_rect(Rect2(100, ground_y - 200, 2000, 200), Color("776655"))
	for city_x in bg_city:
		draw_rect(Rect2(city_x, ground_y - 220, 50, 20), Color("776655"))

	# Ground
	draw_set_transform(Vector2(-camera_x, 0), 0.0, Vector2.ONE)
	draw_rect(Rect2(0, ground_y - 50, GameConfig.WORLD_WIDTH, get_viewport_rect().size.y), GameConfig.COLOR_BG_GROUND)
	for i in 20:
		var y_off: float = float((i * 13217) % 50)
		draw_rect(Rect2(i * 150, ground_y + y_off, 50, 20), GameConfig.COLOR_BG_GRASS)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
