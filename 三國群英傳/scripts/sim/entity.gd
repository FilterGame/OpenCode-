class_name BattleEntity
extends Node2D

const GameConfig = preload("res://scripts/core/game_config.gd")

var team: int = GameConfig.TEAM_PLAYER
var unit_type: String = "infantry"
var speed: float = 1.0
var state: String = "idle"
var hp: float = 20.0
var max_hp: float = 20.0
var attack_range: float = 40.0
var attack_cooldown: float = 0.0
var attack_speed: float = 60.0
var anim_frame: float = 0.0
var dead: bool = false
var command: String = GameConfig.CMD_CHARGE
var is_horse: bool = false
var mp: float = 0.0

var target: BattleEntity = null
var vx: float = 0.0
var vy: float = 0.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var projectile_callback: Callable
var floating_text_callback: Callable

func _ready() -> void:
	rng.randomize()
	z_index = int(position.y)
	queue_redraw()

func setup(start_position: Vector2, p_team: int, p_type: String = "infantry") -> void:
	position = start_position
	team = p_team
	unit_type = p_type
	speed = (1.0 + randf() * 0.5) * (0.8 if unit_type == "archer" else 1.0)
	attack_range = 300.0 if unit_type == "archer" else 40.0
	attack_speed = 120.0 if unit_type == "archer" else 60.0
	hp = 15.0 if unit_type == "archer" else 20.0
	max_hp = hp
	command = GameConfig.CMD_CHARGE
	z_index = int(position.y)
	queue_redraw()

func set_callbacks(projectile_cb: Callable, floating_cb: Callable) -> void:
	projectile_callback = projectile_cb
	floating_text_callback = floating_cb

func set_command(cmd: String) -> void:
	command = cmd

func update_entity(entities: Array, game_speed: float, ground_y: float) -> void:
	if dead:
		return

	if unit_type != "general" and team == GameConfig.TEAM_PLAYER:
		if command == GameConfig.CMD_HOLD:
			state = "idle"
			target = null
			update_visual_state()
			return
		if command == GameConfig.CMD_RETREAT:
			vx = -speed
			position.x += vx * game_speed
			anim_frame += game_speed
			update_visual_state()
			return

	if target == null or target.dead:
		find_target(entities)

	if target != null:
		var dx: float = target.position.x - position.x
		var dy: float = target.position.y - position.y
		var dist: float = sqrt(dx * dx + dy * dy)
		if dist < attack_range:
			state = "attack"
			attack_cooldown -= game_speed
			if attack_cooldown <= 0.0:
				attack()
				attack_cooldown = attack_speed
		else:
			state = "move"
			var angle: float = atan2(dy, dx)
			vx = cos(angle) * speed
			vy = sin(angle) * (speed * 0.5)
			position.x += vx * game_speed
			position.y += vy * game_speed
			anim_frame += game_speed
	else:
		state = "move"
		vx = (1.0 if team == GameConfig.TEAM_PLAYER else -1.0) * speed
		position.x += vx * game_speed
		anim_frame += game_speed

	if position.y < ground_y - 100.0:
		position.y = ground_y - 100.0
	if position.y > ground_y + 100.0:
		position.y = ground_y + 100.0

	z_index = int(position.y)
	update_visual_state()

func find_target(entities: Array) -> void:
	var closest: BattleEntity = null
	var min_dist: float = 2000.0
	for e in entities:
		if e is BattleEntity:
			var other: BattleEntity = e
			if other.team != team and not other.dead:
				var dist: float = abs(other.position.x - position.x)
				if dist < min_dist:
					min_dist = dist
					closest = other
	target = closest

func attack() -> void:
	if target == null:
		return
	if unit_type == "archer":
		if projectile_callback.is_valid():
			projectile_callback.call(position.x, position.y - 30.0, target.position.x, target.position.y, team)
	else:
		var dmg: int = 5 + int(rng.randi() % 5)
		target.take_damage(float(dmg))
	anim_frame = 0.0
	queue_redraw()

func take_damage(amount: float) -> void:
	hp -= amount
	if floating_text_callback.is_valid():
		floating_text_callback.call(position, "-%d" % int(amount), Color.RED)
	if hp <= 0.0:
		dead = true
		state = "dead"
		queue_redraw()

func update_visual_state() -> void:
	modulate.a = 0.5 if dead else 1.0
	queue_redraw()

func _draw() -> void:
	var dir: float = 1.0
	if target != null:
		dir = 1.0 if target.position.x > position.x else -1.0
	else:
		dir = 1.0 if team == GameConfig.TEAM_PLAYER else -1.0

	var bounce: float = sin(anim_frame * 0.2) * 2.0 if state == "move" else 0.0
	var attack_anim: float = 10.0 if state == "attack" and attack_cooldown > (attack_speed - 15.0) else 0.0

	if dead:
		draw_set_transform(Vector2.ZERO, PI / 2.0, Vector2(1.0, 1.0))
	else:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(dir, 1.0))

	# Shadow
	draw_ellipse(Vector2(0, 0), 15.0, 5.0, Color(0, 0, 0, 0.3))

	# Legs
	draw_rect(Rect2(-5 + bounce, -15, 4, 15), Color("111111"))
	draw_rect(Rect2(5 - bounce, -15, 4, 15), Color("111111"))

	# Torso
	var armor_col: Color = GameConfig.COLOR_PLAYER_ARMOR if team == GameConfig.TEAM_PLAYER else GameConfig.COLOR_ENEMY_ARMOR
	var skin_col: Color = GameConfig.COLOR_PLAYER_SKIN if team == GameConfig.TEAM_PLAYER else GameConfig.COLOR_ENEMY_SKIN
	draw_rect(Rect2(-8, -35 + bounce, 16, 25), armor_col)
	draw_rect(Rect2(-6, -45 + bounce, 12, 12), skin_col)

	if unit_type == "archer":
		draw_rect(Rect2(-7, -46 + bounce, 14, 4), Color("665544"))
		# Bow
		draw_arc(Vector2(5, -30 + bounce), 10, -PI / 2.0, PI / 2.0, 12, Color("885522"), 2.0)
	else:
		draw_rect(Rect2(-7, -48 + bounce, 14, 5), Color("555555"))
		draw_rect(Rect2(0, -52 + bounce, 2, 4), Color("0000ff") if team == GameConfig.TEAM_PLAYER else Color("ff0000"))
		if state == "attack":
			draw_set_transform(Vector2(10, -30), attack_anim * 0.1, Vector2(dir, 1.0))
			draw_rect(Rect2(0, -20, 2, 40), Color("888888"))
			draw_rect(Rect2(-2, -25, 6, 10), Color("eeeeee"))
			if dead:
				draw_set_transform(Vector2.ZERO, PI / 2.0, Vector2(1.0, 1.0))
			else:
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(dir, 1.0))
		else:
			draw_rect(Rect2(5, -30 + bounce, 2, 30), Color("888888"))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not dead and hp < max_hp:
		draw_rect(Rect2(-10, -60, 20, 4), Color.RED)
		draw_rect(Rect2(-10, -60, 20.0 * (hp / max_hp), 4), GameConfig.COLOR_HP_BAR)
