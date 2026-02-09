class_name SimGeneral
extends SimEntity

func _init(
	entity_id: int,
	start_x: float,
	start_y: float,
	team_id: int,
	general_name: String,
	rng: RandomNumberGenerator = null
) -> void:
	super._init(entity_id, start_x, start_y, team_id, BattleConstants.ENTITY_GENERAL, rng)
	name = general_name
	max_hp = 500 if team == BattleConstants.TEAM_PLAYER else 800
	hp = max_hp
	max_mp = 100.0
	mp = max_mp
	width = 60.0
	height = 100.0
	attack_range = 80.0
	attack_speed = 40.0
	scale = 1.5
	is_horse = true
