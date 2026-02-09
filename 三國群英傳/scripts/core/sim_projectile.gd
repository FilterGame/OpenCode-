class_name SimProjectile
extends RefCounted

var id: int = -1

var x: float = 0.0
var y: float = 0.0
var start_x: float = 0.0
var start_y: float = 0.0
var target_x: float = 0.0
var target_y: float = 0.0
var team: int = BattleConstants.TEAM_PLAYER

var life: float = 60.0
var progress: float = 0.0
var speed: float = 0.03
var arc_height: float = 150.0

func _init(
	projectile_id: int,
	from_x: float,
	from_y: float,
	to_x: float,
	to_y: float,
	team_id: int
) -> void:
	id = projectile_id
	x = from_x
	y = from_y
	start_x = from_x
	start_y = from_y
	target_x = to_x
	target_y = to_y
	team = team_id

func update(frame_units: float) -> bool:
	progress += speed * frame_units
	if progress >= 1.0:
		life = 0.0
		return true

	x = lerpf(start_x, target_x, progress)
	var linear_y := lerpf(start_y, target_y, progress)
	var arc := 4.0 * arc_height * progress * (1.0 - progress)
	y = linear_y - arc
	return false

func get_angle_radians() -> float:
	var dx := target_x - start_x
	var dy := (target_y - start_y) - 4.0 * arc_height * (1.0 - 2.0 * progress)
	return atan2(dy, dx)

func to_snapshot() -> Dictionary:
	return {
		"id": id,
		"x": x,
		"y": y,
		"team": team,
		"life": life,
		"progress": progress,
		"angle": get_angle_radians()
	}
