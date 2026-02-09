extends Node2D

@export var lifetime: float = 0.45

var speed_scale: float = 1.0
var _elapsed: float = 0.0
var _burst_color: Color = Color(1.0, 0.55, 0.22, 1.0)
var _pieces: Array[Dictionary] = []


func _ready() -> void:
	add_to_group(&"battle_actor")
	if _pieces.is_empty():
		_seed_pieces()
	queue_redraw()


func trigger(origin: Vector2, color: Color) -> void:
	global_position = origin
	_burst_color = color
	_elapsed = 0.0
	_seed_pieces()
	queue_redraw()


func _seed_pieces() -> void:
	_pieces.clear()
	for i in 8:
		var angle := randf_range(0.0, TAU)
		var distance := randf_range(9.0, 34.0)
		var radius := randf_range(2.0, 4.5)
		_pieces.append({
			"dir": Vector2.RIGHT.rotated(angle),
			"distance": distance,
			"radius": radius
		})


func _process(delta: float) -> void:
	_elapsed += delta * speed_scale
	if _elapsed >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_elapsed / lifetime, 0.0, 1.0)
	var alpha := 1.0 - t
	for piece in _pieces:
		var dir: Vector2 = piece["dir"]
		var distance: float = piece["distance"]
		var radius: float = piece["radius"]
		var pos := dir * (distance * ease(t, 0.6))
		var color := _burst_color
		color.a = alpha
		draw_circle(pos, maxf(0.5, radius * (1.0 - t * 0.35)), color)
