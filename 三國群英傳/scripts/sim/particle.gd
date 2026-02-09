class_name BattleParticle
extends Node2D

var particle_type: String = "blood"
var life: float = 30.0
var vx: float = 0.0
var vy: float = 0.0
var size: float = 4.0

func setup_particle(p_position: Vector2, p_type: String) -> void:
	position = p_position
	particle_type = p_type
	vx = randf_range(-2.5, 2.5)
	vy = randf_range(-2.5, 2.5)
	size = randf_range(2.0, 7.0)
	life = 30.0

func update_particle(game_speed: float) -> void:
	position.x += vx * game_speed
	position.y += vy * game_speed
	life -= game_speed
	if particle_type == "wave":
		size += 5.0 * game_speed
		position.x += 15.0 * game_speed
	queue_redraw()

func _draw() -> void:
	var alpha: float = maxf(0.0, life / 30.0)
	if particle_type == "wave":
		draw_arc(Vector2.ZERO, 50.0, -PI / 2.0, PI / 2.0, 18, Color(0.533, 0.8, 1.0, alpha), 5.0)
		return

	var col: Color = Color("aa0000") if particle_type == "blood" else Color("ffff00")
	col.a = alpha
	draw_circle(Vector2.ZERO, size, col)
