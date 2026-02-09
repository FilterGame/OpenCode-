class_name BattleSimulator
extends RefCounted

var world_width: float = BattleConstants.DEFAULT_WORLD_WIDTH
var ground_y: float = 0.0
var lane_half_range: float = BattleConstants.DEFAULT_LANE_HALF_RANGE

var entities: Array = []
var projectiles: Array = []
var particles: Array = []
var floating_texts: Array = []

var simulation_time_sec: float = 0.0

var _entity_seq: int = 1
var _projectile_seq: int = 1
var _particle_seq: int = 1
var _text_seq: int = 1
var _events: Array = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _skill_system: BattleSkillSystem = BattleSkillSystem.new()

func _init(seed: int = 0) -> void:
	if seed == 0:
		_rng.randomize()
	else:
		_rng.seed = seed

func reset(seed: int = 0) -> void:
	entities.clear()
	projectiles.clear()
	particles.clear()
	floating_texts.clear()
	_events.clear()
	_entity_seq = 1
	_projectile_seq = 1
	_particle_seq = 1
	_text_seq = 1
	simulation_time_sec = 0.0
	_skill_system.reset()
	if seed == 0:
		_rng.randomize()
	else:
		_rng.seed = seed

func set_battlefield(width_value: float, ground_y_value: float, lane_half_range_value: float = BattleConstants.DEFAULT_LANE_HALF_RANGE) -> void:
	world_width = maxf(1.0, width_value)
	ground_y = ground_y_value
	lane_half_range = maxf(0.0, lane_half_range_value)

func setup_default_battle(player_name: String = "Player General", enemy_name: String = "Enemy General") -> void:
	reset()
	if ground_y == 0.0:
		ground_y = 540.0

	create_general(200.0, ground_y, BattleConstants.TEAM_PLAYER, player_name)
	create_general(1800.0, ground_y, BattleConstants.TEAM_ENEMY, enemy_name)

	for i in range(4):
		for j in range(5):
			create_entity(50.0 + float(i) * 30.0, ground_y - 60.0 + float(j) * 30.0, BattleConstants.TEAM_PLAYER, BattleConstants.ENTITY_INFANTRY)
			create_entity(1900.0 - float(i) * 30.0, ground_y - 60.0 + float(j) * 30.0, BattleConstants.TEAM_ENEMY, BattleConstants.ENTITY_INFANTRY)

	for row in range(5):
		create_entity(0.0, ground_y - 60.0 + float(row) * 30.0, BattleConstants.TEAM_PLAYER, BattleConstants.ENTITY_ARCHER)
		create_entity(1950.0, ground_y - 60.0 + float(row) * 30.0, BattleConstants.TEAM_ENEMY, BattleConstants.ENTITY_ARCHER)

func create_entity(start_x: float, start_y: float, team: int, unit_type: String = BattleConstants.ENTITY_INFANTRY) -> SimEntity:
	var entity := SimEntity.new(_entity_seq, start_x, start_y, team, unit_type, _rng)
	_entity_seq += 1
	entities.append(entity)
	return entity

func create_general(start_x: float, start_y: float, team: int, general_name: String) -> SimGeneral:
	var general := SimGeneral.new(_entity_seq, start_x, start_y, team, general_name, _rng)
	_entity_seq += 1
	entities.append(general)
	return general

func spawn_projectile(from_x: float, from_y: float, to_x: float, to_y: float, team: int) -> SimProjectile:
	var projectile := SimProjectile.new(_projectile_seq, from_x, from_y, to_x, to_y, team)
	_projectile_seq += 1
	projectiles.append(projectile)
	return projectile

func add_particle(x: float, y: float, particle_type: String) -> SimParticle:
	var particle := SimParticle.new(_particle_seq, x, y, particle_type, _rng)
	_particle_seq += 1
	particles.append(particle)
	return particle

func add_floating_text(x: float, y: float, text: String, color: Color = Color.WHITE) -> SimFloatingText:
	var floating := SimFloatingText.new(_text_seq, x, y, text, color, 60.0)
	_text_seq += 1
	floating_texts.append(floating)
	return floating

func get_general(team: int) -> SimGeneral:
	for entity in entities:
		if entity == null:
			continue
		if entity.team == team and entity is SimGeneral:
			return entity as SimGeneral
	return null

func get_team_alive_count(team: int, include_general: bool = true) -> int:
	var count := 0
	for entity in entities:
		if entity == null or entity.dead or entity.team != team:
			continue
		if not include_general and entity.is_horse:
			continue
		count += 1
	return count

func send_command(command: String, team: int = BattleConstants.TEAM_PLAYER) -> Dictionary:
	if not BattleConstants.is_valid_command(command):
		return {"ok": false, "reason": "invalid_command", "command": command}
	var affected := BattleCommands.apply_team_command(entities, team, command)
	var general := get_general(team)
	if general != null:
		add_floating_text(general.x, general.y - 100.0, "CMD: %s" % command, Color(1, 1, 0))
	_events.append({
		"type": "command_sent",
		"team": team,
		"command": command,
		"affected": affected
	})
	return {"ok": true, "command": command, "team": team, "affected": affected}

func cast_crescent(team: int = BattleConstants.TEAM_PLAYER) -> Dictionary:
	var general := get_general(team)
	if general == null:
		return {"ok": false, "reason": "general_not_found", "team": team}
	var result := _skill_system.cast_crescent(simulation_time_sec, general, general.x, general.y, team)
	if not result.get("ok", false):
		if result.get("reason", "") == "insufficient_mp":
			add_floating_text(general.x, general.y - 80.0, "Not enough MP", Color(0.6, 0.6, 0.6))
		return result
	_events.append({
		"type": "skill_cast",
		"skill": BattleSkillSystem.CRESCENT_NAME,
		"team": team,
		"caster_id": general.id
	})
	return result

func step(delta_sec: float, time_scale: float = 1.0) -> void:
	if delta_sec <= 0.0:
		return

	simulation_time_sec += delta_sec
	_process_skill_events()

	var frame_units := delta_sec * 60.0 * maxf(0.0, time_scale)
	if frame_units <= 0.0:
		return

	_update_entities(frame_units)
	_update_projectiles(frame_units)
	_update_particles(frame_units)
	_update_floating_texts(frame_units)

func get_snapshot() -> Dictionary:
	var entity_data: Array = []
	for entity in entities:
		entity_data.append(entity.to_snapshot())

	var projectile_data: Array = []
	for projectile in projectiles:
		projectile_data.append(projectile.to_snapshot())

	var particle_data: Array = []
	for particle in particles:
		particle_data.append(particle.to_snapshot())

	var text_data: Array = []
	for floating in floating_texts:
		text_data.append(floating.to_snapshot())

	return {
		"time_sec": simulation_time_sec,
		"entities": entity_data,
		"projectiles": projectile_data,
		"particles": particle_data,
		"floating_texts": text_data
	}

func consume_events() -> Array:
	var out := _events.duplicate(true)
	_events.clear()
	return out

func _update_entities(frame_units: float) -> void:
	var entity_index := {}
	for entity in entities:
		entity_index[entity.id] = entity

	for entity in entities:
		if entity.dead:
			continue

		var actions := BattleAI.update_entity(
			entity,
			entities,
			entity_index,
			frame_units,
			ground_y,
			lane_half_range,
			_rng
		)

		entity.x = clampf(entity.x, 0.0, world_width)

		for action in actions:
			_handle_entity_action(action, entity_index)

func _handle_entity_action(action: Dictionary, entity_index: Dictionary) -> void:
	var kind := action.get("kind", "")
	match kind:
		"spawn_projectile":
			var projectile_target = entity_index.get(action.get("target_id", -1))
			var to_x := action.get("target_x", 0.0)
			var to_y := action.get("target_y", 0.0)
			if projectile_target != null and not projectile_target.dead:
				to_x = projectile_target.x
				to_y = projectile_target.y
			var projectile := spawn_projectile(
				action.get("x", 0.0),
				action.get("y", 0.0),
				to_x,
				to_y,
				action.get("team", BattleConstants.TEAM_PLAYER)
			)
			_events.append({
				"type": "projectile_spawned",
				"projectile_id": projectile.id,
				"attacker_id": action.get("attacker_id", -1)
			})
		"melee_hit":
			var melee_target = entity_index.get(action.get("target_id", -1))
			if melee_target != null and not melee_target.dead:
				_apply_damage(melee_target, int(action.get("damage", 0)), "melee", {
					"attacker_id": action.get("attacker_id", -1)
				})

func _update_projectiles(frame_units: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var projectile: SimProjectile = projectiles[i]
		var hit_ground := projectile.update(frame_units)
		if hit_ground or projectile.life <= 0.0:
			projectiles.remove_at(i)
			continue

		for entity in entities:
			if entity.dead or entity.team == projectile.team:
				continue
			if absf(entity.x - projectile.x) < BattleConstants.PROJECTILE_HIT_X and absf(entity.y - projectile.y) < BattleConstants.PROJECTILE_HIT_Y:
				_apply_damage(entity, BattleConstants.ARROW_DAMAGE, "arrow", {"projectile_id": projectile.id})
				projectile.life = 0.0
				break

		if projectile.life <= 0.0:
			projectiles.remove_at(i)

func _update_particles(frame_units: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var particle: SimParticle = particles[i]
		particle.update(frame_units)
		if not particle.is_alive():
			particles.remove_at(i)

func _update_floating_texts(frame_units: float) -> void:
	for i in range(floating_texts.size() - 1, -1, -1):
		var floating: SimFloatingText = floating_texts[i]
		floating.update(frame_units)
		if not floating.is_alive():
			floating_texts.remove_at(i)

func _process_skill_events() -> void:
	var due_events := _skill_system.consume_due_events(simulation_time_sec)
	for event_data in due_events:
		var kind := event_data.get("kind", "")
		match kind:
			"crescent_wave":
				add_particle(event_data.get("x", 0.0), event_data.get("y", 0.0), BattleConstants.PARTICLE_WAVE)
				_events.append({
					"type": "skill_wave",
					"skill": BattleSkillSystem.CRESCENT_NAME,
					"team": event_data.get("team", BattleConstants.TEAM_PLAYER)
				})
			"crescent_damage":
				_apply_crescent_damage(event_data)

func _apply_crescent_damage(event_data: Dictionary) -> void:
	var caster_team := int(event_data.get("team", BattleConstants.TEAM_PLAYER))
	var origin_y := float(event_data.get("origin_y", ground_y))
	var damage := int(event_data.get("damage", BattleSkillSystem.CRESCENT_DAMAGE))
	var vertical_range := float(event_data.get("vertical_range", BattleSkillSystem.CRESCENT_VERTICAL_RANGE))

	var hit_count := 0
	for entity in entities:
		if entity.dead:
			continue
		if entity.team == caster_team:
			continue
		if absf(entity.y - origin_y) >= vertical_range:
			continue
		if _apply_damage(entity, damage, "crescent", {"skill": BattleSkillSystem.CRESCENT_NAME}) > 0:
			hit_count += 1

	_events.append({
		"type": "skill_damage",
		"skill": BattleSkillSystem.CRESCENT_NAME,
		"team": caster_team,
		"hit_count": hit_count
	})
	_events.append({
		"type": "camera_impulse",
		"x": 0.0,
		"y": 10.0,
		"duration_sec": 0.2
	})

func _apply_damage(target: SimEntity, amount: int, source: String, extra: Dictionary = {}) -> int:
	var dealt := target.take_damage(amount)
	if dealt <= 0:
		return 0

	add_floating_text(target.x, target.y - 60.0, "-%d" % dealt, Color(1, 0, 0))
	var event_payload := {
		"type": "damage",
		"source": source,
		"target_id": target.id,
		"amount": dealt,
		"killed": target.dead
	}
	for key in extra.keys():
		event_payload[key] = extra[key]
	_events.append(event_payload)
	return dealt
