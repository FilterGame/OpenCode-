class_name BattleProjectile
extends Node2D

const GameConfig = preload("res://scripts/core/game_config.gd")

var start_pos: Vector2
var target_pos: Vector2
var team: int = GameConfig.TEAM_PLAYER
var life: float = 60.0
var progress: float = 0.0
var speed: float = 0.03
var arc_height: float = 150.0

func setup_projectile(p_start: Vector2, p_target: Vector2, p_team: int) -> void:
	start_pos = p_start
	target_pos = p_target
	team = p_team
	position = p_start

func update_projectile(game_speed: float) -> bool:
	progress += speed * game_speed
	if progress >= 1.0:
		life = 0.0
		return true

	position.x = lerpf(start_pos.x, target_pos.x, progress)
	var linear_y: float = lerpf(start_pos.y, target_pos.y, progress)
	var arc: float = 4.0 * arc_height * progress * (1.0 - progress)
	position.y = linear_y - arc
	queue_redraw()
	return false

func _draw() -> void:
	var dx: float = target_pos.x - start_pos.x
	var dy: float = (target_pos.y - start_pos.y) - 4.0 * arc_height * (1.0 - 2.0 * progress)
	var angle: float = atan2(dy, dx)
	draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)
	draw_rect(Rect2(-10, -1, 20, 2), Color.WHITE)
	draw_rect(Rect2(8, -2, 4, 4), Color("888888"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
