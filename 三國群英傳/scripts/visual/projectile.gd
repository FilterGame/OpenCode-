extends Node2D

signal impact(hit_position: Vector2, team: int, damage: int)

@export var speed: float = 1.35
@export var arc_height: float = 120.0

var start_pos: Vector2
var target_pos: Vector2
var progress: float = 0.0
var team: int = 1
var damage: int = 10
var speed_scale: float = 1.0
var _last_pos: Vector2


func _ready() -> void:
	add_to_group(&"battle_actor")
	_last_pos = global_position


func launch(from: Vector2, to: Vector2, team_id: int, damage_value: int) -> void:
	start_pos = from
	target_pos = to
	team = team_id
	damage = damage_value
	progress = 0.0
	global_position = from
	_last_pos = from
	queue_redraw()


func _process(delta: float) -> void:
	var scaled_delta := delta * speed_scale
	_last_pos = global_position
	progress += speed * scaled_delta
	if progress >= 1.0:
		global_position = target_pos
		impact.emit(global_position, team, damage)
		queue_free()
		return

	global_position = _sample_position(progress)
	queue_redraw()


func _sample_position(t: float) -> Vector2:
	var linear := start_pos.lerp(target_pos, t)
	var arc := 4.0 * arc_height * t * (1.0 - t)
	linear.y -= arc
	return linear


func _draw() -> void:
	var velocity := global_position - _last_pos
	var angle := velocity.angle() if velocity.length_squared() > 0.0001 else 0.0
	var shaft_start := Vector2(-10.0, 0.0).rotated(angle)
	var shaft_end := Vector2(10.0, 0.0).rotated(angle)
	var tip_left := Vector2(10.0, 0.0).rotated(angle)
	var tip_right := Vector2(5.5, -3.0).rotated(angle)
	var tip_bottom := Vector2(5.5, 3.0).rotated(angle)

	draw_line(shaft_start, shaft_end, Color(0.95, 0.95, 1.0), 2.0, true)
	draw_colored_polygon(PackedVector2Array([tip_left, tip_right, tip_bottom]), Color(0.62, 0.62, 0.7))
