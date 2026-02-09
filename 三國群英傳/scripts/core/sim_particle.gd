class_name SimParticle
extends RefCounted

var id: int = -1
var x: float = 0.0
var y: float = 0.0
var particle_type: String = BattleConstants.PARTICLE_BLOOD

var life: float = 30.0
var vx: float = 0.0
var vy: float = 0.0
var size: float = 2.0

func _init(
	particle_id: int,
	start_x: float,
	start_y: float,
	type_name: String,
	rng: RandomNumberGenerator = null
) -> void:
	id = particle_id
	x = start_x
	y = start_y
	particle_type = type_name

	var local_rng := rng
	if local_rng == null:
		local_rng = RandomNumberGenerator.new()
		local_rng.randomize()

	vx = (local_rng.randf() - 0.5) * 5.0
	vy = (local_rng.randf() - 0.5) * 5.0
	size = local_rng.randf() * 5.0 + 2.0

func update(frame_units: float) -> void:
	x += vx * frame_units
	y += vy * frame_units
	life -= frame_units
	if particle_type == BattleConstants.PARTICLE_WAVE:
		size += 5.0 * frame_units
		x += 15.0 * frame_units

func is_alive() -> bool:
	return life > 0.0

func to_snapshot() -> Dictionary:
	return {
		"id": id,
		"x": x,
		"y": y,
		"particle_type": particle_type,
		"life": life,
		"size": size
	}
