class_name SimEntity
extends RefCounted

var id: int = -1
var name: String = ""

var x: float = 0.0
var y: float = 0.0
var z: float = 0.0

var team: int = BattleConstants.TEAM_PLAYER
var unit_type: String = BattleConstants.ENTITY_INFANTRY

var vx: float = 0.0
var vy: float = 0.0
var speed: float = 1.0

var state: String = BattleConstants.STATE_IDLE
var hp: int = 20
var max_hp: int = 20
var mp: float = 0.0
var max_mp: float = 0.0

var target_id: int = -1

var attack_range: float = 40.0
var attack_cooldown: float = 0.0
var attack_speed: float = 60.0

var anim_frame: float = 0.0
var width: float = 30.0
var height: float = 50.0
var scale: float = 1.0
var is_horse: bool = false
var dead: bool = false

var command: String = BattleConstants.CMD_CHARGE

func _init(
	entity_id: int,
	start_x: float,
	start_y: float,
	team_id: int,
	entity_type: String = BattleConstants.ENTITY_INFANTRY,
	rng: RandomNumberGenerator = null
) -> void:
	id = entity_id
	x = start_x
	y = start_y
	z = y
	team = team_id
	unit_type = entity_type
	_setup_type_stats(rng)

func _setup_type_stats(rng: RandomNumberGenerator) -> void:
	var local_rng := rng
	if local_rng == null:
		local_rng = RandomNumberGenerator.new()
		local_rng.randomize()

	var speed_scale := 1.0
	if unit_type == BattleConstants.ENTITY_ARCHER:
		hp = 15
		max_hp = 15
		attack_range = 300.0
		attack_speed = 120.0
		speed_scale = 0.8
	else:
		hp = 20
		max_hp = 20
		attack_range = 40.0
		attack_speed = 60.0

	speed = BattleConstants.DEFAULT_BASE_SPEED * (1.0 + local_rng.randf() * 0.5) * speed_scale

func is_general() -> bool:
	return unit_type == BattleConstants.ENTITY_GENERAL

func is_alive() -> bool:
	return not dead and hp > 0

func take_damage(amount: int) -> int:
	if dead or amount <= 0:
		return 0
	var before := hp
	hp = max(0, hp - amount)
	if hp <= 0:
		dead = true
		state = BattleConstants.STATE_DEAD
	var dealt := before - hp
	return dealt

func to_snapshot() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"x": x,
		"y": y,
		"z": z,
		"team": team,
		"unit_type": unit_type,
		"state": state,
		"hp": hp,
		"max_hp": max_hp,
		"mp": mp,
		"max_mp": max_mp,
		"target_id": target_id,
		"attack_cooldown": attack_cooldown,
		"dead": dead,
		"command": command,
		"is_horse": is_horse,
		"scale": scale
	}
