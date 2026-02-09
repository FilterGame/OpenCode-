class_name BattleConstants
extends RefCounted

const TEAM_PLAYER := 1
const TEAM_ENEMY := 2

const ENTITY_INFANTRY := "infantry"
const ENTITY_ARCHER := "archer"
const ENTITY_GENERAL := "general"

const STATE_IDLE := "idle"
const STATE_MOVE := "move"
const STATE_ATTACK := "attack"
const STATE_DEAD := "dead"

const CMD_CHARGE := "charge"
const CMD_HOLD := "hold"
const CMD_RETREAT := "retreat"

const PARTICLE_BLOOD := "blood"
const PARTICLE_SPARK := "spark"
const PARTICLE_WAVE := "wave"

const DEFAULT_WORLD_WIDTH := 2000.0
const DEFAULT_LANE_HALF_RANGE := 100.0
const DEFAULT_BASE_SPEED := 1.0

const MELEE_MIN_DAMAGE := 5
const MELEE_MAX_DAMAGE := 9
const ARROW_DAMAGE := 10
const PROJECTILE_HIT_X := 20.0
const PROJECTILE_HIT_Y := 40.0

static func is_valid_command(value: String) -> bool:
	return value == CMD_CHARGE or value == CMD_HOLD or value == CMD_RETREAT

static func command_label(value: String) -> String:
	match value:
		CMD_CHARGE:
			return "charge"
		CMD_HOLD:
			return "hold"
		CMD_RETREAT:
			return "retreat"
		_:
			return value

static func clamp_lane_y(y: float, ground_y: float, lane_half_range: float) -> float:
	return clampf(y, ground_y - lane_half_range, ground_y + lane_half_range)
