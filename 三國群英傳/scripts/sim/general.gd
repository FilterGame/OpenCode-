class_name BattleGeneral
extends "res://scripts/sim/entity.gd"

var general_name: String = ""
var draw_scale: float = 1.5

func setup_general(start_position: Vector2, p_team: int, p_name: String) -> void:
	setup(start_position, p_team, "general")
	general_name = p_name
	max_hp = 500.0 if team == GameConfig.TEAM_PLAYER else 800.0
	hp = max_hp
	mp = 100.0
	attack_range = 80.0
	attack_speed = 40.0
	is_horse = true

func _draw() -> void:
	var dir: float = 1.0
	if target != null:
		dir = 1.0 if target.position.x > position.x else -1.0
	else:
		dir = 1.0 if team == GameConfig.TEAM_PLAYER else -1.0

	var bounce: float = sin(anim_frame * 0.2) * 3.0 if state == "move" else 0.0
	var attack_rot: float = PI / 2.0 if state == "attack" and attack_cooldown > 20.0 else -PI / 4.0

	if dead:
		draw_set_transform(Vector2.ZERO, PI / 2.0, Vector2(draw_scale, draw_scale))
	else:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(dir * draw_scale, draw_scale))

	draw_ellipse(Vector2.ZERO, 30.0, 8.0, Color(0, 0, 0, 0.4))

	# Horse
	draw_rect(Rect2(-20, -30 + bounce, 50, 20), Color.WHITE if team == GameConfig.TEAM_PLAYER else Color("332211"))
	draw_rect(Rect2(-15 + bounce, -10, 8, 15), Color.WHITE if team == GameConfig.TEAM_PLAYER else Color("332211"))
	draw_rect(Rect2(15 - bounce, -10, 8, 15), Color.WHITE if team == GameConfig.TEAM_PLAYER else Color("332211"))
	draw_rect(Rect2(20, -45 + bounce, 15, 20), Color.WHITE if team == GameConfig.TEAM_PLAYER else Color("332211"))
	draw_rect(Rect2(30, -50 + bounce, 12, 10), Color.WHITE if team == GameConfig.TEAM_PLAYER else Color("332211"))

	# Rider
	draw_rect(Rect2(-5, -55 + bounce, 15, 30), Color("006600") if team == GameConfig.TEAM_PLAYER else Color("440000"))
	draw_rect(Rect2(-2, -65 + bounce, 10, 10), Color("ffccaa"))

	# Weapon
	draw_set_transform(Vector2(5, -50 + bounce), attack_rot, Vector2(dir * draw_scale, draw_scale))
	draw_rect(Rect2(0, -40, 3, 80), Color("442211"))
	if team == GameConfig.TEAM_PLAYER:
		draw_arc(Vector2(3, -40), 15, 0.0, PI, 16, Color("cceecc"), 4.0)
	else:
		draw_rect(Rect2(-10, -40, 23, 5), Color("cceecc"))
		draw_rect(Rect2(10, -50, 3, 20), Color("cceecc"))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not dead and hp < max_hp:
		draw_rect(Rect2(-15, -95, 30, 5), Color.RED)
		draw_rect(Rect2(-15, -95, 30.0 * (hp / max_hp), 5), GameConfig.COLOR_HP_BAR)
