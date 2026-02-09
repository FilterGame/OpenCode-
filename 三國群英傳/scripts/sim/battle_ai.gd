class_name BattleAI
extends RefCounted

static func update_entity(
	entity: SimEntity,
	entities: Array,
	entity_index: Dictionary,
	frame_units: float,
	ground_y: float,
	lane_half_range: float,
	rng: RandomNumberGenerator
) -> Array:
	var actions: Array = []
	if entity == null or entity.dead:
		return actions

	# Player-side normal units obey formation commands.
	if entity.unit_type != BattleConstants.ENTITY_GENERAL and entity.team == BattleConstants.TEAM_PLAYER:
		if entity.command == BattleConstants.CMD_HOLD:
			entity.state = BattleConstants.STATE_IDLE
			entity.target_id = -1
			return actions
		if entity.command == BattleConstants.CMD_RETREAT:
			entity.state = BattleConstants.STATE_MOVE
			entity.vx = _retreat_direction(entity.team) * entity.speed
			entity.vy = 0.0
			entity.x += entity.vx * frame_units
			entity.anim_frame += frame_units
			entity.y = BattleConstants.clamp_lane_y(entity.y, ground_y, lane_half_range)
			return actions

	var target := _get_valid_target(entity, entity_index)
	if target == null:
		target = find_target(entity, entities)
		entity.target_id = target.id if target != null else -1

	if target != null:
		var dx := target.x - entity.x
		var dy := target.y - entity.y
		var dist := sqrt(dx * dx + dy * dy)

		if dist < entity.attack_range:
			entity.state = BattleConstants.STATE_ATTACK
			entity.attack_cooldown -= frame_units
			if entity.attack_cooldown <= 0.0:
				entity.attack_cooldown = entity.attack_speed
				entity.anim_frame = 0.0
				actions.append(_build_attack_action(entity, target, rng))
		else:
			entity.state = BattleConstants.STATE_MOVE
			var angle := atan2(dy, dx)
			entity.vx = cos(angle) * entity.speed
			entity.vy = sin(angle) * (entity.speed * 0.5)
			entity.x += entity.vx * frame_units
			entity.y += entity.vy * frame_units
			entity.anim_frame += frame_units
	else:
		entity.state = BattleConstants.STATE_MOVE
		entity.vx = _forward_direction(entity.team) * entity.speed
		entity.vy = 0.0
		entity.x += entity.vx * frame_units
		entity.anim_frame += frame_units

	entity.y = BattleConstants.clamp_lane_y(entity.y, ground_y, lane_half_range)
	return actions

static func find_target(entity: SimEntity, entities: Array) -> SimEntity:
	var closest: SimEntity = null
	var min_dist := INF
	for candidate in entities:
		if candidate == null or candidate.dead:
			continue
		if candidate.team == entity.team:
			continue
		var dist := absf(candidate.x - entity.x)
		if dist < min_dist:
			min_dist = dist
			closest = candidate
	return closest

static func _get_valid_target(entity: SimEntity, entity_index: Dictionary) -> SimEntity:
	if entity.target_id == -1:
		return null
	var target = entity_index.get(entity.target_id)
	if target == null:
		return null
	if target.dead:
		return null
	if target.team == entity.team:
		return null
	return target

static func _build_attack_action(entity: SimEntity, target: SimEntity, rng: RandomNumberGenerator) -> Dictionary:
	if entity.unit_type == BattleConstants.ENTITY_ARCHER:
		return {
			"kind": "spawn_projectile",
			"attacker_id": entity.id,
			"team": entity.team,
			"x": entity.x,
			"y": entity.y - 30.0,
			"target_id": target.id,
			"target_x": target.x,
			"target_y": target.y
		}

	var damage := BattleConstants.MELEE_MIN_DAMAGE + rng.randi_range(0, BattleConstants.MELEE_MAX_DAMAGE - BattleConstants.MELEE_MIN_DAMAGE)
	return {
		"kind": "melee_hit",
		"attacker_id": entity.id,
		"target_id": target.id,
		"damage": damage
	}

static func _forward_direction(team: int) -> float:
	return 1.0 if team == BattleConstants.TEAM_PLAYER else -1.0

static func _retreat_direction(team: int) -> float:
	return -1.0 if team == BattleConstants.TEAM_PLAYER else 1.0
