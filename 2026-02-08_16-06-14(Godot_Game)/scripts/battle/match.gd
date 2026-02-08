class_name BattleMatch
extends RefCounted

const Entities = preload("res://scripts/battle/entities.gd")
const PlayerState = preload("res://scripts/battle/player_state.gd")

const MATCH_DURATION_SECONDS = 3.0 * 60.0
const OVERTIME_DURATION_SECONDS = 2.0 * 60.0
const TIEBREAKER_DURATION_SECONDS = 30.0
const TIEBREAKER_HP_LOSS_PER_SECOND = 100.0

const ELIXIR_RATE_NORMAL = 1.0 / 2.8
const ELIXIR_RATE_OVERTIME = 3.0 / 2.8

const AI_PLAY_INTERVAL_MIN = 3.0
const AI_PLAY_INTERVAL_MAX = 7.0
const AI_DEFEND_HP_THRESHOLD = 0.3

const BRIDGE_WIDTH = 120.0
const BRIDGE_HEIGHT = 60.0
const PARTICLE_LIMIT = 200

enum MatchPhase {
	NORMAL,
	OVERTIME,
	TIEBREAKER
}

var arena_size = Vector2(1280.0, 720.0)
var bridge_y = 360.0

var players: Array = []
var game_objects: Array = []
var particles: Array = []

var card_pool: Array = []
var cards_by_id = {}
var cards_by_name = {}
var unit_templates = {}

var timer = MATCH_DURATION_SECONDS
var match_phase = MatchPhase.NORMAL
var elixir_rate_multiplier = 1.0

var winner: Variant = null
var game_over_message = ""
var event_log: Array = []
var cards_played_count = [0, 0]

var last_played_card_player: Dictionary = {}
var last_played_card_ai: Dictionary = {}

var ai_next_play_time = 0.0
var mouse_position = Vector2.ZERO
var hovered_card: Dictionary = {}
var view: Variant = null

var _rng = RandomNumberGenerator.new()


func _init(player_deck: Array = [], ai_deck: Array = [], arena_bounds: Vector2 = Vector2(1280.0, 720.0), battle_view: Variant = null) -> void:
	arena_size = arena_bounds
	bridge_y = arena_size.y * 0.5
	_rng.randomize()
	_load_battle_data()
	var human_deck = _resolve_deck(player_deck, false)
	var bot_deck = _resolve_deck(ai_deck, true)
	players = [
		PlayerState.new(0, human_deck, true, arena_size),
		PlayerState.new(1, bot_deck, false, arena_size),
	]
	timer = MATCH_DURATION_SECONDS
	match_phase = MatchPhase.NORMAL
	elixir_rate_multiplier = 1.0
	ai_next_play_time = _rng.randf_range(AI_PLAY_INTERVAL_MIN, AI_PLAY_INTERVAL_MAX)
	set_view(battle_view)


func update(dt: float) -> void:
	if winner != null:
		return
	_update_phase_timer(dt)
	for p in players:
		p.update(dt, elixir_rate_multiplier, self)
	update_ai(dt)
	for i in range(game_objects.size() - 1, -1, -1):
		var obj = game_objects[i]
		obj.update(dt, self)
		_notify_object_updated(obj)
		var expired = obj.duration >= 0.0 and obj.duration <= 0.0
		if obj.is_destroyed or expired:
			if obj is Entities.Unit and str(obj.card_data.get("special", "")) == "death_damage" and obj.hp <= 0.0:
				spawn_spell_effect(
					obj.card_data,
					obj.pos,
					(players[0] if obj.is_friendly else players[1]),
					Entities.as_float(obj.card_data.get("dmg", 0.0), 0.0) * 0.5,
					Entities.as_float(obj.card_data.get("attackRange", 0.0), 0.0) * 1.5,
					Entities.as_float(obj.card_data.get("splashRadius", 0.0), 0.0)
				)
			if obj is Entities.Unit:
				spawn_particle_effect(obj.pos, 12, (Entities.COLOR_PLAYER if obj.is_friendly else Entities.COLOR_AI), "death")
			_notify_object_removed(obj)
			game_objects.remove_at(i)
	for i in range(particles.size() - 1, -1, -1):
		var particle = particles[i]
		particle.update(dt)
		_notify_particle_updated(particle)
		if particle.is_finished():
			_notify_particle_removed(particle)
			particles.remove_at(i)
	if _has_view() and view.has_method("sync_from_match"):
		view.sync_from_match(self)
	_check_instant_win_conditions()


func draw(canvas: CanvasItem) -> void:
	_draw_arena_background(canvas)
	var draw_world_fallback = not _has_view()
	players[0].draw(canvas, self, draw_world_fallback)
	players[1].draw(canvas, self, draw_world_fallback)
	if draw_world_fallback:
		game_objects.sort_custom(func(a, b): return a.pos.y < b.pos.y)
		for obj in game_objects:
			obj.draw(canvas)
		for particle in particles:
			particle.draw(canvas)
	_draw_match_info(canvas)
	_draw_deploy_preview(canvas)


func handle_mouse_pressed(pos: Vector2) -> void:
	mouse_position = pos
	if winner != null:
		return
	var human: PlayerState = players[0]
	if not human.selected_card_to_play.is_empty():
		var card = human.selected_card_to_play
		if can_deploy_at(card, pos, human):
			if play_card(human, card, pos, pos):
				human.selected_card_to_play = {}
		else:
			human.selected_card_to_play = {}
	else:
		var index = human.get_clicked_card_index(pos)
		if index < 0:
			return
		var card: Dictionary = human.hand[index]
		var cost = get_card_elixir(card, human)
		if human.elixir < cost:
			return
		if str(card.get("special", "")) == "mirror_last_card" and last_played_card_player.is_empty():
			return
		human.selected_card_to_play = card


func handle_mouse_moved(pos: Vector2) -> void:
	mouse_position = pos
	hovered_card = players[0].handle_hand_hover(pos)


func get_hovered_card() -> Dictionary:
	return hovered_card.duplicate(true)


func get_post_game_stats() -> Dictionary:
	var p0_hp = _tower_hp_total(players[0])
	var p1_hp = _tower_hp_total(players[1])
	return {
		"winner": winner,
		"winner_name": _winner_name(),
		"phase": _phase_name(match_phase),
		"message": game_over_message,
		"player_tower_hp": p0_hp,
		"ai_tower_hp": p1_hp,
		"cards_played_player": cards_played_count[0],
		"cards_played_ai": cards_played_count[1],
		"elapsed_time": get_elapsed_time(),
	}


func get_card_elixir(card_data: Dictionary, player: PlayerState) -> int:
	if str(card_data.get("special", "")) == "mirror_last_card":
		var last = (last_played_card_player if player.id == 0 else last_played_card_ai)
		if last.is_empty():
			return 99
		return _elixir_value(last.get("elixir", 0)) + 1
	return _elixir_value(card_data.get("elixir", 0))


func play_card(player: PlayerState, card_data: Dictionary, position: Vector2, target_position: Vector2 = Vector2.ZERO) -> bool:
	var cost = get_card_elixir(card_data, player)
	if player.elixir < cost * 1.0:
		return false
	player.elixir -= cost * 1.0
	cards_played_count[player.id] += 1
	if str(card_data.get("special", "")) == "mirror_last_card":
		var last = (last_played_card_player if player.id == 0 else last_played_card_ai)
		if last.is_empty():
			player.elixir += cost * 1.0
			return false
		spawn_game_object(last, player, position, target_position)
		if player.id == 0:
			last_played_card_player = card_data
		else:
			last_played_card_ai = card_data
	else:
		spawn_game_object(card_data, player, position, target_position)
		if player.id == 0:
			last_played_card_player = card_data
		else:
			last_played_card_ai = card_data
	player.cycle_card(card_data)
	event_log.append({
		"time": get_elapsed_time(),
		"player": player.id,
		"card": card_data.get("name", ""),
		"x": position.x,
		"y": position.y,
	})
	return true


func spawn_game_object(card_data: Dictionary, player: PlayerState, position: Vector2, target_position: Vector2 = Vector2.ZERO) -> void:
	var card_type = str(card_data.get("type", ""))
	var friendly = player.is_human
	if card_type == "troop":
		var spawn_count = max(1, Entities.as_int(card_data.get("spawnCount", 1), 1))
		var spawn_unit_id = str(card_data.get("spawnUnitId", ""))
		for _i in spawn_count:
			var spawn_pos = position
			if spawn_count > 1:
				spawn_pos += Vector2(
					_rng.randf_range(-Entities.TILE_SIZE * 0.5, Entities.TILE_SIZE * 0.5),
					_rng.randf_range(-Entities.TILE_SIZE * 0.5, Entities.TILE_SIZE * 0.5)
				)
			var unit_props = _build_unit_props(card_data, spawn_unit_id)
			var unit = Entities.Unit.new(spawn_pos.x, spawn_pos.y, friendly, unit_props, card_data)
			game_objects.append(unit)
			_notify_object_spawned(unit)
	elif card_type == "building":
		var building = Entities.Building.new(position.x, position.y, friendly, card_data)
		game_objects.append(building)
		_notify_object_spawned(building)
	elif card_type == "spell":
		spawn_spell_effect(
			card_data,
			target_position,
			player,
			Entities.as_float(card_data.get("dmg", 0.0), 0.0),
			Entities.as_float(card_data.get("attackRange", Entities.TILE_SIZE), Entities.TILE_SIZE),
			Entities.as_float(card_data.get("splashRadius", 0.0), 0.0)
		)

func spawn_spell_effect(card_data: Dictionary, position: Vector2, caster_player: PlayerState, spell_dmg: float, spell_range: float, spell_splash_radius: float) -> void:
	var spell = Entities.Spell.new(position.x, position.y, caster_player.is_human, card_data, spell_dmg, spell_range, spell_splash_radius)
	game_objects.append(spell)
	_notify_object_spawned(spell)
	if spell.special != "linear_pushback" and spell.special != "area_spawn_over_time":
		spell.apply_effect(self)
		spell.applied = true
	var particle_kind = ("line" if str(card_data.get("special", "")) == "linear_pushback" else "explosion")
	spawn_particle_effect(position, 24, Entities.COLOR_SPELL, particle_kind)


func spawn_particle_effect(position: Vector2, count: int, color: Variant, particle_type: String = "explosion") -> void:
	var c = (color if color is Color else Entities.color_from_any(color, Color.WHITE))
	var safe_count = count
	if particles.size() + safe_count > PARTICLE_LIMIT:
		safe_count = max(0, PARTICLE_LIMIT - particles.size())
	for _i in safe_count:
		var particle = Entities.Particle.new(position.x, position.y, c, particle_type)
		particles.append(particle)
		_notify_particle_spawned(particle)


func spawn_template_unit(template_id: String, source_card_data: Dictionary, friendly: bool, position: Vector2) -> void:
	if not unit_templates.has(template_id):
		return
	var template: Dictionary = unit_templates[template_id]
	var props = template.duplicate(true)
	var unit = Entities.Unit.new(position.x, position.y, friendly, props, source_card_data)
	game_objects.append(unit)
	_notify_object_spawned(unit)


func set_view(battle_view: Variant) -> void:
	if _has_view() and view != battle_view and view.has_method("clear_all"):
		view.clear_all()
	view = battle_view
	if not _has_view():
		return
	if view.has_method("configure_arena"):
		view.configure_arena(arena_size, bridge_y)
	for player in players:
		player.notify_tower_spawn(view)
	for obj in game_objects:
		_notify_object_spawned(obj)
	for particle in particles:
		_notify_particle_spawned(particle)


func get_view() -> Variant:
	return view


func _has_view() -> bool:
	return view != null and is_instance_valid(view)


func _notify_object_spawned(obj: Variant) -> void:
	if not _has_view():
		return
	if view.has_method("on_object_spawned"):
		view.on_object_spawned(obj)


func _notify_object_updated(obj: Variant) -> void:
	if not _has_view():
		return
	if view.has_method("on_object_updated"):
		view.on_object_updated(obj)


func _notify_object_removed(obj: Variant) -> void:
	if not _has_view():
		return
	if view.has_method("on_object_removed"):
		view.on_object_removed(obj)


func _notify_particle_spawned(particle: Variant) -> void:
	if not _has_view():
		return
	if view.has_method("on_particle_spawned"):
		view.on_particle_spawned(particle)


func _notify_particle_updated(particle: Variant) -> void:
	if not _has_view():
		return
	if view.has_method("on_particle_updated"):
		view.on_particle_updated(particle)


func _notify_particle_removed(particle: Variant) -> void:
	if not _has_view():
		return
	if view.has_method("on_particle_removed"):
		view.on_particle_removed(particle)


func can_deploy_at(card_data: Dictionary, position: Vector2, player: PlayerState) -> bool:
	if position.x <= Entities.TILE_SIZE or position.x >= arena_size.x - Entities.TILE_SIZE:
		return false
	var card_type = str(card_data.get("type", ""))
	var special = str(card_data.get("special", ""))
	var is_friendly_side = (position.y > bridge_y if player.is_human else position.y < bridge_y)
	var is_friendly_territory = (position.y > bridge_y - Entities.TILE_SIZE * 2.0 if player.is_human else position.y < bridge_y + Entities.TILE_SIZE * 2.0)
	if special == "deploy_anywhere_ground":
		return true
	if card_type == "spell":
		return true
	if card_type == "building":
		return is_friendly_side
	return is_friendly_territory


func update_ai(dt: float) -> void:
	var ai: PlayerState = players[1]
	ai_next_play_time -= dt
	if ai_next_play_time > 0.0:
		return
	ai_next_play_time = _rng.randf_range(AI_PLAY_INTERVAL_MIN, AI_PLAY_INTERVAL_MAX)
	var playable = []
	for card in ai.hand:
		if ai.elixir >= get_card_elixir(card, ai) * 1.0:
			if str(card.get("special", "")) == "mirror_last_card" and last_played_card_ai.is_empty():
				continue
			playable.append(card)
	if playable.is_empty():
		return
	var critical_tower = false
	for t in ai.towers:
		if t.hp > 0.0 and t.max_hp > 0.0 and (t.hp / t.max_hp) < AI_DEFEND_HP_THRESHOLD:
			critical_tower = true
			break
	var player_threats = false
	for obj in game_objects:
		if obj is Entities.Unit and obj.is_friendly and obj.target != null and ai.towers.has(obj.target):
			player_threats = true
			break
	var card_to_play: Dictionary = {}
	if critical_tower or player_threats:
		playable.sort_custom(func(a, b): return get_card_elixir(a, ai) < get_card_elixir(b, ai))
		card_to_play = playable[0]
	else:
		card_to_play = playable[_rng.randi_range(0, playable.size() - 1)]
	var placement = Vector2.ZERO
	var target_pos = Vector2.ZERO
	var deploy_y = bridge_y - Entities.TILE_SIZE * 1.5
	var spawn_x = clampf(arena_size.x * 0.5 + _rng.randf_range(-arena_size.x / 3.0, arena_size.x / 3.0), Entities.TILE_SIZE, arena_size.x - Entities.TILE_SIZE)
	var card_type = str(card_to_play.get("type", ""))
	if card_type == "troop" or card_type == "building":
		placement = Vector2(spawn_x, deploy_y)
		if str(card_to_play.get("special", "")) == "deploy_anywhere_ground":
			var enemy_towers = []
			for t in players[0].towers:
				if t.hp > 0.0:
					enemy_towers.append(t)
			if not enemy_towers.is_empty():
				placement = enemy_towers[_rng.randi_range(0, enemy_towers.size() - 1)].pos
	elif card_type == "spell":
		var possible_targets = []
		for obj in game_objects:
			if obj.is_friendly and obj.hp > 0.0:
				possible_targets.append(obj)
		if not possible_targets.is_empty():
			target_pos = possible_targets[_rng.randi_range(0, possible_targets.size() - 1)].pos
		else:
			var towers_alive = []
			for t in players[0].towers:
				if t.hp > 0.0:
					towers_alive.append(t)
			target_pos = (towers_alive[_rng.randi_range(0, towers_alive.size() - 1)].pos if not towers_alive.is_empty() else Vector2(arena_size.x * 0.5, arena_size.y - 50.0))
		placement = target_pos
	if placement != Vector2.ZERO:
		play_card(ai, card_to_play, placement, target_pos)


func find_targets(unit: Variant) -> Variant:
	var candidates = []
	var enemy_index = (1 if unit.is_friendly else 0)
	for obj in game_objects:
		if obj.is_friendly == unit.is_friendly:
			continue
		if not is_target_alive(obj):
			continue
		if not (obj is Entities.Unit or obj is Entities.Building):
			continue
		if not _unit_can_target(unit, obj):
			continue
		candidates.append(obj)
	for tower in players[enemy_index].towers:
		if tower.hp <= 0.0:
			continue
		if _unit_can_target(unit, tower):
			candidates.append(tower)
	if candidates.is_empty():
		return null
	_sort_targets_for_unit(unit, candidates)
	for target in candidates:
		if _unit_card_target_filter(unit, target):
			return target
	return null


func find_targets_for_building(building: Variant) -> Variant:
	var candidates = []
	for obj in game_objects:
		if obj.is_friendly == building.is_friendly:
			continue
		if not is_target_alive(obj):
			continue
		if obj is Entities.Unit:
			if building.target_type == "any" or building.target_type == obj.movement_type:
				candidates.append(obj)
			continue
		if obj is Entities.Building:
			if building.target_type == "any" or building.target_type == "ground" or building.target_type == "buildings":
				candidates.append(obj)
	var enemy_towers = players[(1 if building.is_friendly else 0)].towers
	for tower in enemy_towers:
		if tower.hp <= 0.0:
			continue
		if building.target_type == "any" or building.target_type == "ground" or building.target_type == "buildings":
			candidates.append(tower)
	if candidates.is_empty():
		return null
	if str(building.special) == "fast_attack_rate":
		candidates.sort_custom(func(a, b):
			var pa = _building_xbow_priority(a)
			var pb = _building_xbow_priority(b)
			if pa != pb:
				return pa < pb
			return building.pos.distance_to(a.pos) < building.pos.distance_to(b.pos)
		)
	else:
		candidates.sort_custom(func(a, b):
			var pa = _building_general_priority(a)
			var pb = _building_general_priority(b)
			if pa != pb:
				return pa < pb
			return building.pos.distance_to(a.pos) < building.pos.distance_to(b.pos)
		)
	for target in candidates:
		if target.movement_type == "air":
			if building.target_type == "any" or building.target_type == "air":
				return target
			continue
		if building.target_type == "any" or building.target_type == "ground" or building.target_type == "buildings":
			return target
	return null


func find_secondary_target(attacker: Variant, primary_target: Variant) -> Variant:
	var best = null
	var best_dist = INF
	for target in get_enemy_objects_and_towers(attacker.is_friendly):
		if target == primary_target:
			continue
		if not is_target_alive(target):
			continue
		var d = attacker.pos.distance_to(target.pos)
		if d > attacker.attack_range:
			continue
		if d < best_dist:
			best_dist = d
			best = target
	return best


func get_enemy_objects_and_towers(from_friendly: bool) -> Array:
	var list = []
	for obj in game_objects:
		if obj.is_friendly != from_friendly and is_target_alive(obj):
			list.append(obj)
	var enemy_index = (1 if from_friendly else 0)
	for tower in players[enemy_index].towers:
		if tower.hp > 0.0:
			list.append(tower)
	return list


func get_enemy_king_tower(from_friendly: bool) -> Variant:
	var enemy_index = (1 if from_friendly else 0)
	for tower in players[enemy_index].towers:
		if tower.is_king and tower.hp > 0.0:
			return tower
	return null


func is_target_alive(target: Variant) -> bool:
	if target == null:
		return false
	if target.is_destroyed:
		return false
	return target.hp > 0.0


func get_target_radius(target: Variant) -> float:
	if target == null:
		return Entities.TILE_SIZE * 0.3
	if target.has_method("get_collision_radius"):
		return Entities.as_float(target.get_collision_radius(), Entities.TILE_SIZE * 0.3)
	return Entities.TILE_SIZE * 0.3


func get_elapsed_time() -> float:
	match match_phase:
		MatchPhase.NORMAL:
			return MATCH_DURATION_SECONDS - timer
		MatchPhase.OVERTIME:
			return MATCH_DURATION_SECONDS + (OVERTIME_DURATION_SECONDS - timer)
		_:
			return MATCH_DURATION_SECONDS + OVERTIME_DURATION_SECONDS + (TIEBREAKER_DURATION_SECONDS - timer)

func _update_phase_timer(dt: float) -> void:
	timer -= dt
	if match_phase == MatchPhase.NORMAL and timer <= 0.0:
		match_phase = MatchPhase.OVERTIME
		timer = OVERTIME_DURATION_SECONDS
		elixir_rate_multiplier = ELIXIR_RATE_OVERTIME / ELIXIR_RATE_NORMAL
		event_log.append({"time": get_elapsed_time(), "event": "OVERTIME_START"})
		_check_tower_count_win()
		return
	if match_phase == MatchPhase.OVERTIME and timer <= 0.0:
		match_phase = MatchPhase.TIEBREAKER
		timer = TIEBREAKER_DURATION_SECONDS
		event_log.append({"time": get_elapsed_time(), "event": "TIEBREAKER_START"})
		_check_tower_count_win()
		return
	if match_phase == MatchPhase.TIEBREAKER:
		if timer <= 0.0:
			_check_tiebreaker_win()
		else:
			var hp_loss = TIEBREAKER_HP_LOSS_PER_SECOND * dt
			for p in players:
				for tower in p.towers:
					if tower.hp > 0.0:
						tower.take_damage(hp_loss)


func _check_instant_win_conditions() -> void:
	if winner != null:
		return
	for i in players.size():
		for tower in players[i].towers:
			if tower.is_king and tower.hp <= 0.0:
				winner = 1 - i
				game_over_message = "%s destroyed the king tower" % players[_to_int(winner, 0)].name
				_end_match()
				return


func _check_tower_count_win() -> void:
	if winner != null:
		return
	if match_phase == MatchPhase.NORMAL:
		return
	var p0_alive = _alive_princess_towers(players[0])
	var p1_alive = _alive_princess_towers(players[1])
	if p0_alive < p1_alive:
		winner = 1
		game_over_message = "%s wins by tower count" % players[1].name
		_end_match()
	elif p1_alive < p0_alive:
		winner = 0
		game_over_message = "%s wins by tower count" % players[0].name
		_end_match()


func _check_tiebreaker_win() -> void:
	if winner != null:
		return
	var p0_hp = _tower_hp_total(players[0])
	var p1_hp = _tower_hp_total(players[1])
	if p0_hp <= 0.0 and p1_hp <= 0.0:
		winner = "TIE"
		game_over_message = "Both sides collapsed in tiebreaker"
	elif p0_hp <= 0.0:
		winner = 1
		game_over_message = "%s wins in tiebreaker" % players[1].name
	elif p1_hp <= 0.0:
		winner = 0
		game_over_message = "%s wins in tiebreaker" % players[0].name
	elif p0_hp < p1_hp:
		winner = 1
		game_over_message = "%s wins by remaining HP" % players[1].name
	elif p1_hp < p0_hp:
		winner = 0
		game_over_message = "%s wins by remaining HP" % players[0].name
	else:
		winner = "TIE"
		game_over_message = "Draw"
	_end_match()


func _end_match() -> void:
	event_log.append({"time": get_elapsed_time(), "event": "MATCH_END", "winner": winner})


func _draw_arena_background(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(arena_size.x, arena_size.y * 0.5)), Color(0.24, 0.35, 0.24, 1.0), true)
	canvas.draw_rect(Rect2(Vector2(0.0, arena_size.y * 0.5), Vector2(arena_size.x, arena_size.y * 0.5)), Color(0.28, 0.4, 0.28, 1.0), true)
	canvas.draw_rect(Rect2(Vector2(0.0, bridge_y - BRIDGE_HEIGHT * 0.75), Vector2(arena_size.x, BRIDGE_HEIGHT * 1.5)), Color(0.39, 0.3, 0.2, 1.0), true)
	canvas.draw_rect(Rect2(Vector2(arena_size.x * 0.25 - BRIDGE_WIDTH * 0.5, bridge_y - BRIDGE_HEIGHT * 0.5), Vector2(BRIDGE_WIDTH, BRIDGE_HEIGHT)), Color(0.72, 0.6, 0.46, 1.0), true)
	canvas.draw_rect(Rect2(Vector2(arena_size.x * 0.75 - BRIDGE_WIDTH * 0.5, bridge_y - BRIDGE_HEIGHT * 0.5), Vector2(BRIDGE_WIDTH, BRIDGE_HEIGHT)), Color(0.72, 0.6, 0.46, 1.0), true)


func _draw_match_info(canvas: CanvasItem) -> void:
	var safe_time = max(0.0, timer)
	var minutes = floori(safe_time / 60.0)
	var seconds = floori(fmod(safe_time, 60.0))
	var text = "%d:%02d" % [minutes, seconds]
	_draw_text(canvas, Vector2(arena_size.x * 0.5, 30.0), text, 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	if match_phase == MatchPhase.OVERTIME:
		_draw_text(canvas, Vector2(arena_size.x * 0.5, 58.0), "OVERTIME", 22, Color(1.0, 0.85, 0.3, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	elif match_phase == MatchPhase.TIEBREAKER:
		_draw_text(canvas, Vector2(arena_size.x * 0.5, 58.0), "TIEBREAKER", 22, Color(1.0, 0.35, 0.35, 1.0), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_deploy_preview(canvas: CanvasItem) -> void:
	var human: PlayerState = players[0]
	if human.selected_card_to_play.is_empty():
		return
	var card = human.selected_card_to_play
	var valid = can_deploy_at(card, mouse_position, human)
	var color = (Color(0.2, 1.0, 0.2, 0.35) if valid else Color(1.0, 0.2, 0.2, 0.35))
	if str(card.get("type", "")) == "spell":
		var r = max(20.0, Entities.as_float(card.get("attackRange", Entities.TILE_SIZE), Entities.TILE_SIZE))
		canvas.draw_circle(mouse_position, r, color)
	else:
		var rect = Rect2(mouse_position - Vector2(Entities.TILE_SIZE * 0.5, Entities.TILE_SIZE * 0.5), Vector2(Entities.TILE_SIZE, Entities.TILE_SIZE))
		canvas.draw_rect(rect, color, true)
		var attack_range = Entities.as_float(card.get("attackRange", 0.0), 0.0)
		if attack_range > 0.0:
			canvas.draw_arc(mouse_position, attack_range, 0.0, TAU, 48, Color(1.0, 1.0, 0.3, 0.35), 1.0)


func _draw_text(canvas: CanvasItem, pos: Vector2, text: String, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, max_width: float = -1.0) -> void:
	var font = canvas.get_theme_default_font()
	if font == null:
		return
	canvas.draw_string(font, pos, text, align, max_width, font_size, color)


func _load_battle_data() -> void:
	_load_cards_csv("res://data/cards.csv")
	_load_unit_templates_csv("res://data/unit_templates.csv")
	if card_pool.is_empty():
		_build_fallback_cards()


func _load_cards_csv(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var headers = file.get_csv_line()
	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.is_empty():
			continue
		var raw = {}
		var col_count = min(headers.size(), row.size())
		for i in col_count:
			raw[str(headers[i])] = str(row[i]).strip_edges()
		if raw.is_empty():
			continue
		var card = _normalize_card_row(raw)
		card_pool.append(card)
		cards_by_id[Entities.as_int(card["id"], 0)] = card
		cards_by_name[str(card["name"])] = card


func _normalize_card_row(raw: Dictionary) -> Dictionary:
	var elixir_raw = str(raw.get("elixir", "0"))
	var elixir_value: Variant = 0
	if elixir_raw.begins_with("+"):
		elixir_value = elixir_raw
	elif elixir_raw.is_valid_int():
		elixir_value = elixir_raw.to_int()
	elif elixir_raw.is_valid_float():
		elixir_value = roundi(elixir_raw.to_float())
	return {
		"id": Entities.as_int(raw.get("id", "0"), 0),
		"name": str(raw.get("name", "")),
		"type": str(raw.get("type", "")),
		"elixir": elixir_value,
		"rarity": str(raw.get("rarity", "common")),
		"hp": Entities.as_float(raw.get("hp", "0"), 0.0),
		"dmg": Entities.as_float(raw.get("dmg", "0"), 0.0),
		"speed": str(raw.get("speed", "medium")),
		"attackRange": Entities.as_float(raw.get("attackRange", "0"), 0.0),
		"description": str(raw.get("description", "")),
		"movementType": str(raw.get("movementType", "ground")),
		"targetType": str(raw.get("targetType", "any")),
		"splashRadius": Entities.as_float(raw.get("splashRadius", "0"), 0.0),
		"spawnCount": str(raw.get("spawnCount", "")).to_int() if str(raw.get("spawnCount", "")).is_valid_int() else 0,
		"spawnUnitId": str(raw.get("spawnUnitId", "")),
		"special": str(raw.get("special", "")),
	}


func _load_unit_templates_csv(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var headers = file.get_csv_line()
	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.is_empty():
			continue
		var raw = {}
		var col_count = min(headers.size(), row.size())
		for i in col_count:
			raw[str(headers[i])] = str(row[i]).strip_edges()
		var key = str(raw.get("id", ""))
		if key.is_empty():
			continue
		var visual_data = {}
		var visual_text = str(raw.get("visual", ""))
		if not visual_text.is_empty():
			var parsed = JSON.parse_string(visual_text)
			if parsed is Dictionary:
				visual_data = parsed
		unit_templates[key] = {
			"name": str(raw.get("name", key)),
			"hp": Entities.as_float(raw.get("hp", "1"), 1.0),
			"shieldHp": Entities.as_float(raw.get("shieldHp", "0"), 0.0),
			"dmg": Entities.as_float(raw.get("dmg", "0"), 0.0),
			"speed": str(raw.get("speed", "medium")),
			"attackRange": Entities.as_float(raw.get("attackRange", "48"), 48.0),
			"movementType": str(raw.get("movementType", "ground")),
			"targetType": str(raw.get("targetType", "any")),
			"splashRadius": Entities.as_float(raw.get("splashRadius", "0"), 0.0),
			"visual": visual_data,
		}

func _build_fallback_cards() -> void:
	card_pool = [
		{"id": 5, "name": "Prince", "type": "troop", "elixir": 5, "hp": 1500.0, "dmg": 350.0, "speed": "medium", "attackRange": 64.0, "movementType": "ground", "targetType": "any", "splashRadius": 0.0, "special": "charge", "rarity": "epic"},
		{"id": 9, "name": "The Log", "type": "spell", "elixir": 2, "hp": 0.0, "dmg": 240.0, "speed": "n/a", "attackRange": 400.0, "movementType": "n/a", "targetType": "ground", "splashRadius": 120.0, "special": "linear_pushback", "rarity": "legendary"},
		{"id": 11, "name": "Lightning", "type": "spell", "elixir": 6, "hp": 0.0, "dmg": 860.0, "speed": "n/a", "attackRange": 140.0, "movementType": "n/a", "targetType": "any", "splashRadius": 0.0, "special": "multi_target_3", "rarity": "epic"},
		{"id": 12, "name": "Inferno Tower", "type": "building", "elixir": 5, "hp": 1500.0, "dmg": 50.0, "speed": "n/a", "attackRange": 240.0, "movementType": "n/a", "targetType": "any", "splashRadius": 0.0, "special": "ramping_damage", "rarity": "rare"},
		{"id": 15, "name": "Graveyard", "type": "spell", "elixir": 5, "hp": 0.0, "dmg": 0.0, "speed": "n/a", "attackRange": 140.0, "movementType": "n/a", "targetType": "ground", "splashRadius": 140.0, "spawnCount": 1, "spawnUnitId": "skeleton_basic", "special": "area_spawn_over_time", "rarity": "legendary"},
		{"id": 16, "name": "Freeze", "type": "spell", "elixir": 4, "hp": 0.0, "dmg": 100.0, "speed": "n/a", "attackRange": 120.0, "movementType": "n/a", "targetType": "any", "splashRadius": 120.0, "special": "freeze", "rarity": "epic"},
		{"id": 22, "name": "Spirit", "type": "troop", "elixir": 1, "hp": 190.0, "dmg": 150.0, "speed": "very fast", "attackRange": 100.0, "movementType": "ground", "targetType": "any", "splashRadius": 60.0, "special": "kamikaze", "rarity": "common"},
		{"id": 24, "name": "X-Bow", "type": "building", "elixir": 6, "hp": 1300.0, "dmg": 40.0, "speed": "n/a", "attackRange": 460.0, "movementType": "n/a", "targetType": "ground", "splashRadius": 0.0, "special": "fast_attack_rate", "rarity": "epic"},
		{"id": 27, "name": "Mirror", "type": "spell", "elixir": "+1", "hp": 0.0, "dmg": 0.0, "speed": "n/a", "attackRange": 0.0, "movementType": "n/a", "targetType": "n/a", "splashRadius": 0.0, "special": "mirror_last_card", "rarity": "epic"},
		{"id": 30, "name": "Miner", "type": "troop", "elixir": 3, "hp": 1000.0, "dmg": 130.0, "speed": "fast", "attackRange": 48.0, "movementType": "ground", "targetType": "any", "splashRadius": 0.0, "special": "deploy_anywhere_ground", "rarity": "legendary"},
	]
	for card in card_pool:
		cards_by_id[Entities.as_int(card["id"], 0)] = card
		cards_by_name[str(card["name"])] = card
	unit_templates["skeleton_basic"] = {
		"name": "Skeleton",
		"hp": 67.0,
		"dmg": 67.0,
		"speed": "fast",
		"attackRange": 48.0,
		"movementType": "ground",
		"targetType": "any",
		"splashRadius": 0.0,
		"visual": {"size": 15, "color": [200, 200, 200]},
	}


func _resolve_deck(source: Array, is_ai: bool) -> Array:
	var picked = []
	for item in source:
		var card = _resolve_card(item)
		if card.is_empty():
			continue
		if is_ai and str(card.get("special", "")) == "mirror_last_card":
			continue
		picked.append(card.duplicate(true))
		if picked.size() >= 8:
			break
	if picked.size() >= 8:
		return picked
	var available = []
	for card in card_pool:
		if is_ai and str(card.get("special", "")) == "mirror_last_card":
			continue
		available.append(card)
	while picked.size() < 8 and not available.is_empty():
		var index = _rng.randi_range(0, available.size() - 1)
		picked.append(available[index].duplicate(true))
		available.remove_at(index)
	if picked.is_empty():
		for i in min(8, card_pool.size()):
			picked.append(card_pool[i].duplicate(true))
	return picked


func _resolve_card(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	if typeof(value) == TYPE_INT and cards_by_id.has(value):
		return cards_by_id[value]
	if typeof(value) == TYPE_STRING and cards_by_name.has(str(value)):
		return cards_by_name[str(value)]
	return {}


func _build_unit_props(card_data: Dictionary, spawn_unit_id: String) -> Dictionary:
	if not spawn_unit_id.is_empty() and unit_templates.has(spawn_unit_id):
		var from_template: Dictionary = unit_templates[spawn_unit_id].duplicate(true)
		from_template["special"] = str(card_data.get("special", from_template.get("special", "")))
		return from_template
	return {
		"name": str(card_data.get("name", "Unit")),
		"hp": Entities.as_float(card_data.get("hp", 1.0), 1.0),
		"dmg": Entities.as_float(card_data.get("dmg", 0.0), 0.0),
		"speed": str(card_data.get("speed", "medium")),
		"attackRange": Entities.as_float(card_data.get("attackRange", 1.5 * Entities.TILE_SIZE), 1.5 * Entities.TILE_SIZE),
		"movementType": str(card_data.get("movementType", "ground")),
		"targetType": str(card_data.get("targetType", "any")),
		"splashRadius": Entities.as_float(card_data.get("splashRadius", 0.0), 0.0),
		"special": str(card_data.get("special", "")),
		"visual": {
			"size": (Entities.TILE_SIZE * (0.8 if str(card_data.get("movementType", "ground")) == "air" else 1.0)),
			"color": ([180, 180, 200] if str(card_data.get("movementType", "ground")) == "air" else [110, 110, 110]),
		},
	}


func _unit_can_target(unit: Variant, target: Variant) -> bool:
	if unit.target_type == "any":
		return true
	if unit.target_type == "buildings":
		return target is Entities.Building
	if unit.target_type == "ground":
		return target.movement_type != "air"
	if unit.target_type == "air":
		return target.movement_type == "air"
	return true


func _unit_card_target_filter(unit: Variant, target: Variant) -> bool:
	var card_target_type = str(unit.card_data.get("targetType", unit.target_type))
	if target.movement_type == "air":
		return card_target_type == "any" or card_target_type == "air"
	return card_target_type == "any" or card_target_type == "ground" or card_target_type == "buildings"


func _sort_targets_for_unit(unit: Variant, candidates: Array) -> void:
	candidates.sort_custom(func(a, b):
		var dist_a = unit.pos.distance_to(a.pos)
		var dist_b = unit.pos.distance_to(b.pos)
		if unit.target_type == "buildings":
			var ap = _building_priority_for_units(a)
			var bp = _building_priority_for_units(b)
			if ap != bp:
				return ap < bp
			return dist_a < dist_b
		var a_is_unit = a is Entities.Unit
		var b_is_unit = b is Entities.Unit
		if a_is_unit != b_is_unit:
			return a_is_unit
		var pa = _building_priority_for_units(a)
		var pb = _building_priority_for_units(b)
		if pa != pb:
			return pa < pb
		return dist_a < dist_b
	)


func _building_priority_for_units(target: Variant) -> int:
	if target is Entities.Unit:
		return 0
	if target is Entities.Building and not target.is_tower:
		return 1
	if target is Entities.Building and target.is_tower and not target.is_king:
		return 2
	if target is Entities.Building and target.is_tower and target.is_king:
		return 3
	return 4


func _building_general_priority(target: Variant) -> int:
	if target is Entities.Unit:
		return 0
	if target is Entities.Building and not target.is_tower:
		return 1
	if target is Entities.Building and target.is_tower and not target.is_king:
		return 2
	if target is Entities.Building and target.is_tower and target.is_king:
		return 3
	return 4


func _building_xbow_priority(target: Variant) -> int:
	if target is Entities.Building and target.is_tower and target.is_king:
		return 1
	if target is Entities.Building and target.is_tower and not target.is_king:
		return 2
	if target is Entities.Building and not target.is_tower:
		return 3
	if target is Entities.Unit:
		return 4
	return 5


func _alive_princess_towers(player: PlayerState) -> int:
	var alive = 0
	for t in player.towers:
		if not t.is_king and t.hp > 0.0:
			alive += 1
	return alive


func _tower_hp_total(player: PlayerState) -> float:
	var total = 0.0
	for t in player.towers:
		total += max(0.0, t.hp)
	return total


func _elixir_value(raw: Variant) -> int:
	if typeof(raw) == TYPE_INT:
		return raw
	if typeof(raw) == TYPE_FLOAT:
		return roundi(raw)
	var text = str(raw).strip_edges()
	if text.is_valid_int():
		return text.to_int()
	if text.is_valid_float():
		return roundi(text.to_float())
	return 0


func _winner_name() -> String:
	if typeof(winner) == TYPE_STRING and winner == "TIE":
		return "TIE"
	if typeof(winner) == TYPE_INT and (winner == 0 or winner == 1):
		return players[_to_int(winner, 0)].name
	return ""


func _to_int(value: Variant, default_value: int = 0) -> int:
	return Entities.as_int(value, default_value)


func _phase_name(phase: int) -> String:
	match phase:
		MatchPhase.NORMAL:
			return "NORMAL"
		MatchPhase.OVERTIME:
			return "OVERTIME"
		_:
			return "TIEBREAKER"
