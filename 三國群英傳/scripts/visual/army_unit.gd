extends Node2D

@export var team: int = 1
@export var unit_kind: StringName = &"infantry"
@export var display_name: String = "?????拆???"
@export var move_speed: float = 64.0
@export var max_hp: int = 24
@export var hp: int = 24
@export var max_mp: int = 0
@export var mp: int = 0
@export var troops: int = 1

var command: StringName = &"charge"
var speed_scale: float = 1.0
var _base_y: float = 0.0
var _bob_phase: float = 0.0
var _facing: float = 1.0


func _ready() -> void:
	add_to_group(&"battle_actor")
	_base_y = position.y
	_bob_phase = randf() * TAU
	if team == 2:
		_facing = -1.0
	queue_redraw()


func setup(team_id: int, name_text: String) -> void:
	team = team_id
	display_name = name_text
	if team == 2:
		_facing = -1.0
		command = &"advance"
	else:
		_facing = 1.0


func set_command(next_command: StringName) -> void:
	command = next_command


func apply_damage(amount: int) -> void:
	hp = maxi(hp - maxi(amount, 0), 0)
	if hp <= 0:
		queue_free()
	queue_redraw()


func gain_mp(amount: int) -> void:
	if max_mp <= 0:
		return
	mp = mini(mp + maxi(amount, 0), max_mp)


func spend_mp(amount: int) -> bool:
	var cost := maxi(amount, 0)
	if mp < cost:
		return false
	mp -= cost
	return true


func _process(delta: float) -> void:
	var scaled_delta := delta * speed_scale
	var direction := _movement_direction()
	if direction != 0.0:
		_facing = sign(direction)

	var arena_right := maxf(get_viewport_rect().size.x - 36.0, 36.0)
	position.x = clampf(position.x + direction * move_speed * scaled_delta, 36.0, arena_right)
	_bob_phase += scaled_delta * 6.5
	position.y = _base_y + sin(_bob_phase) * 2.5
	queue_redraw()


func _movement_direction() -> float:
	if team == 2:
		return -1.0

	match command:
		&"charge":
			return 1.0
		&"retreat":
			return -1.0
		&"hold":
			return 0.0
		_:
			return 0.0


func _draw() -> void:
	var armor := Color(0.24, 0.47, 0.95) if team == 1 else Color(0.86, 0.29, 0.24)
	var trim := Color(0.08, 0.1, 0.14)
	var skin := Color(0.95, 0.81, 0.68)
	var spear_tip_color := Color(0.86, 0.86, 0.9)
	var hp_ratio := 0.0 if max_hp <= 0 else float(hp) / float(max_hp)

	draw_rect(Rect2(-14.0, -46.0, 28.0, 4.0), Color(0.06, 0.06, 0.06, 0.85), true)
	draw_rect(Rect2(-13.0, -45.0, 26.0 * hp_ratio, 2.0), Color(0.87, 0.18, 0.2), true)

	draw_circle(Vector2(0.0, -26.0), 8.0, skin)
	draw_rect(Rect2(-9.0, -19.0, 18.0, 22.0), armor, true)
	draw_rect(Rect2(-9.0, -19.0, 18.0, 22.0), trim, false, 1.5)
	draw_rect(Rect2(-10.0, 2.0, 8.0, 12.0), trim, true)
	draw_rect(Rect2(2.0, 2.0, 8.0, 12.0), trim, true)

	var spear_dir := 16.0 * _facing
	draw_line(Vector2(0.0, -10.0), Vector2(spear_dir, -3.0), Color(0.56, 0.45, 0.22), 2.0, true)
	draw_circle(Vector2(spear_dir, -3.0), 2.0, spear_tip_color)
