class_name BattleEntities
extends RefCounted

const TILE_SIZE = 40.0
const SPEED_MAP = {
	"slow": 0.8 * TILE_SIZE,
	"medium": 1.2 * TILE_SIZE,
	"fast": 1.8 * TILE_SIZE,
	"very fast": 2.5 * TILE_SIZE,
}

const COLOR_PLAYER = Color(0.2, 0.58, 1.0, 1.0)
const COLOR_AI = Color(1.0, 0.4, 0.4, 1.0)
const COLOR_GROUND_UNIT = Color(0.43, 0.43, 0.43, 1.0)
const COLOR_AIR_UNIT = Color(0.73, 0.73, 0.8, 1.0)
const COLOR_BUILDING = Color(0.6, 0.4, 0.22, 1.0)
const COLOR_SPELL = Color(0.78, 0.3, 0.78, 0.55)

static var _next_object_id = 1


static func next_object_id() -> int:
	var id = _next_object_id
	_next_object_id += 1
	return id


static func as_float(value: Variant, default_value: float = 0.0) -> float:
	match typeof(value):
		TYPE_FLOAT:
			return value
		TYPE_INT:
			return value * 1.0
		TYPE_STRING:
			var text = str(value).strip_edges()
			if text.is_empty():
				return default_value
			if not text.is_valid_float() and not text.is_valid_int():
				return default_value
			return text.to_float()
		_:
			return default_value


static func as_int(value: Variant, default_value: int = 0) -> int:
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			return roundi(value)
		TYPE_STRING:
			var text = str(value).strip_edges()
			if text.is_empty() or not text.is_valid_int():
				return default_value
			return text.to_int()
		_:
			return default_value


static func speed_from_label(speed_value: Variant) -> float:
	if typeof(speed_value) == TYPE_FLOAT:
		return speed_value
	if typeof(speed_value) == TYPE_INT:
		return speed_value * 1.0
	var key = str(speed_value).to_lower().strip_edges()
	return SPEED_MAP.get(key, SPEED_MAP["medium"])


static func color_from_any(raw: Variant, fallback: Color) -> Color:
	if typeof(raw) == TYPE_COLOR:
		return raw
	if raw is Array:
		var arr: Array = raw
		if arr.size() >= 3:
			var r = clampf(as_float(arr[0], 0.0) / 255.0, 0.0, 1.0)
			var g = clampf(as_float(arr[1], 0.0) / 255.0, 0.0, 1.0)
			var b = clampf(as_float(arr[2], 0.0) / 255.0, 0.0, 1.0)
			var a = 1.0
			if arr.size() >= 4:
				a = clampf(as_float(arr[3], 255.0) / 255.0, 0.0, 1.0)
			return Color(r, g, b, a)
	return fallback


static func draw_hp_bar(canvas: CanvasItem, center: Vector2, width: float, height: float, hp: float, max_hp: float, fill_color: Color) -> void:
	var pct = 0.0
	if max_hp > 0.0:
		pct = clampf(hp / max_hp, 0.0, 1.0)
	var bg = Rect2(center + Vector2(-width * 0.5, -height * 0.5), Vector2(width, height))
	canvas.draw_rect(bg, Color(0.12, 0.12, 0.12, 0.9), true)
	var fg = Rect2(bg.position, Vector2(width * pct, height))
	canvas.draw_rect(fg, fill_color, true)


static func create_tower(position: Vector2, is_friendly: bool, hp: float, damage: float, attack_range: float, is_king: bool, tower_name: String) -> Building:
	var card_data = {
		"type": "building",
		"name": tower_name,
		"hp": hp,
		"dmg": damage,
		"attackRange": attack_range,
		"targetType": "any",
		"movementType": "ground",
		"splashRadius": 0.0,
		"special": "",
	}
	var building = Building.new(position.x, position.y, is_friendly, card_data)
	building.is_tower = true
	building.is_king = is_king
	building.size = TILE_SIZE * (2.5 if is_king else 2.0)
	building.attack_speed = (1.0 if is_king else 1.0 / 0.8)
	building.color = (COLOR_PLAYER if is_friendly else COLOR_AI)
	return building


class GameObject:
	var id: int = 0
	var pos: Vector2
	var is_friendly = true
	var card_data: Dictionary = {}
	var movement_type = "ground"
	var is_destroyed = false
	var max_hp = 0.0
	var hp = 0.0
	var attack_cooldown = 0.0
	var freeze_remaining = 0.0
	var _freeze_speed_backup = -1.0
	var target: Variant = null
	var duration = -1.0

	func _init(x: float, y: float, friendly: bool, source_card_data: Dictionary = {}) -> void:
		id = randi()
		pos = Vector2(x, y)
		is_friendly = friendly
		card_data = source_card_data.duplicate(true)
		if card_data.has("movementType"):
			movement_type = str(card_data["movementType"])

	func update(_dt: float, _match: Variant) -> void:
		pass

	func draw(_canvas: CanvasItem) -> void:
		pass

	func get_collision_radius() -> float:
		return TILE_SIZE * 0.4

	func get_move_speed() -> float:
		return 0.0

	func set_move_speed(_value: float) -> void:
		pass

	func apply_freeze(seconds: float) -> void:
		if seconds <= 0.0:
			return
		freeze_remaining = max(freeze_remaining, seconds)
		attack_cooldown = max(attack_cooldown, seconds)
		if _freeze_speed_backup < 0.0:
			_freeze_speed_backup = get_move_speed()
		set_move_speed(0.0)

	func _tick_freeze(dt: float) -> void:
		if freeze_remaining <= 0.0:
			return
		freeze_remaining = max(0.0, freeze_remaining - dt)
		if freeze_remaining <= 0.0 and _freeze_speed_backup >= 0.0:
			set_move_speed(_freeze_speed_backup)
			_freeze_speed_backup = -1.0

	func take_damage(amount: float) -> void:
		if amount <= 0.0:
			return
		hp -= amount
		if hp <= 0.0:
			hp = 0.0
			is_destroyed = true


class Unit extends GameObject:
	var unit_name = "Unit"
	var dmg = 0.0
	var speed = SPEED_MAP["medium"]
	var base_speed = SPEED_MAP["medium"]
	var attack_range = 1.5 * TILE_SIZE
	var target_type = "any"
	var splash_radius = 0.0
	var special = ""
	var attack_speed = 1.5
	var size = TILE_SIZE * 0.85
	var color = COLOR_GROUND_UNIT
	var is_charging = false
	var charge_speed_bonus = 2.0
	var charge_damage_bonus = 2.0
	var charge_distance = TILE_SIZE * 3.5
	var shield_hp = 0.0
	var is_shielded = false
	var base_hp_after_shield = 700.0
	var is_cart_broken = false

	func _init(x: float, y: float, friendly: bool, unit_props: Dictionary, source_card_data: Dictionary = {}) -> void:
		super(x, y, friendly, source_card_data)
		unit_name = str(unit_props.get("name", source_card_data.get("name", "Unit")))
		max_hp = max(1.0, _to_float(unit_props.get("hp", source_card_data.get("hp", 1.0)), 1.0))
		hp = max_hp
		dmg = _to_float(unit_props.get("dmg", source_card_data.get("dmg", 0.0)), 0.0)
		speed = _speed_from_label(unit_props.get("speed", source_card_data.get("speed", "medium")))
		base_speed = speed
		attack_range = max(1.0, _to_float(unit_props.get("attackRange", source_card_data.get("attackRange", 1.5 * TILE_SIZE)), 1.5 * TILE_SIZE))
		target_type = str(unit_props.get("targetType", source_card_data.get("targetType", "any")))
		movement_type = str(unit_props.get("movementType", source_card_data.get("movementType", "ground")))
		splash_radius = max(0.0, _to_float(unit_props.get("splashRadius", source_card_data.get("splashRadius", 0.0)), 0.0))
		special = str(unit_props.get("special", source_card_data.get("special", "")))
		var visual: Dictionary = unit_props.get("visual", {})
		size = _to_float(visual.get("size", TILE_SIZE * (0.8 if movement_type == "air" else 1.0)), TILE_SIZE * 0.85)
		var fallback = (COLOR_AIR_UNIT if movement_type == "air" else COLOR_GROUND_UNIT)
		color = _color_from_any(visual.get("color", fallback), fallback)
		color = color.lerp((COLOR_PLAYER if is_friendly else COLOR_AI), 0.25)
		if special == "charge":
			is_charging = true
		if special == "kamikaze":
			attack_speed = 2.0
		if special == "shield_to_building":
			is_shielded = true
			shield_hp = max_hp
			base_hp_after_shield = max(300.0, max_hp)

	func get_collision_radius() -> float:
		return size * 0.5

	func _to_float(value: Variant, default_value: float = 0.0) -> float:
		match typeof(value):
			TYPE_FLOAT:
				return value
			TYPE_INT:
				return value * 1.0
			TYPE_STRING:
				var text = str(value).strip_edges()
				if text.is_empty():
					return default_value
				if text.is_valid_int() or text.is_valid_float():
					return text.to_float()
				return default_value
			_:
				return default_value

	func _speed_from_label(speed_value: Variant) -> float:
		if speed_value is float:
			return speed_value
		if speed_value is int:
			return speed_value * 1.0
		var key = str(speed_value).to_lower().strip_edges()
		return SPEED_MAP.get(key, SPEED_MAP["medium"])

	func _color_from_any(raw: Variant, fallback: Color) -> Color:
		if raw is Color:
			return raw
		if raw is Array:
			var arr: Array = raw
			if arr.size() >= 3:
				var rr = clampf(_to_float(arr[0], 0.0) / 255.0, 0.0, 1.0)
				var gg = clampf(_to_float(arr[1], 0.0) / 255.0, 0.0, 1.0)
				var bb = clampf(_to_float(arr[2], 0.0) / 255.0, 0.0, 1.0)
				var aa = 1.0
				if arr.size() >= 4:
					aa = clampf(_to_float(arr[3], 255.0) / 255.0, 0.0, 1.0)
				return Color(rr, gg, bb, aa)
		return fallback

	func _draw_bar(canvas: CanvasItem, center: Vector2, width: float, height: float, cur_hp: float, max_hp_val: float, fill_color: Color) -> void:
		var pct = 0.0
		if max_hp_val > 0.0:
			pct = clampf(cur_hp / max_hp_val, 0.0, 1.0)
		var bg = Rect2(center + Vector2(-width * 0.5, -height * 0.5), Vector2(width, height))
		canvas.draw_rect(bg, Color(0.12, 0.12, 0.12, 0.9), true)
		canvas.draw_rect(Rect2(bg.position, Vector2(width * pct, height)), fill_color, true)

	func get_move_speed() -> float:
		return speed

	func set_move_speed(value: float) -> void:
		speed = max(0.0, value)

	func update(dt: float, ctx: Variant) -> void:
		_tick_freeze(dt)
		if hp <= 0.0:
			is_destroyed = true
			return
		if attack_cooldown > 0.0:
			attack_cooldown = max(0.0, attack_cooldown - dt)
		if special == "charge":
			speed = base_speed * (charge_speed_bonus if is_charging else 1.0)
		if target == null or not ctx.is_target_alive(target):
			target = ctx.find_targets(self)
			if special == "charge":
				is_charging = target != null
		if target != null:
			var dist_to_target = pos.distance_to(target.pos)
			if dist_to_target <= attack_range:
				var damage_override = dmg
				if special == "charge" and is_charging:
					damage_override = dmg * charge_damage_bonus
				attack(target, ctx, damage_override)
				if special == "charge":
					is_charging = false
				if special == "kamikaze":
					hp = 0.0
					is_destroyed = true
			else:
				_move_towards(target.pos, dt)
		else:
			var king = ctx.get_enemy_king_tower(is_friendly)
			if king != null:
				_move_towards(king.pos, dt)

	func _move_towards(target_pos: Vector2, dt: float) -> void:
		if speed <= 0.0:
			return
		var direction = target_pos - pos
		if direction.length_squared() < 0.001:
			return
		pos += direction.normalized() * speed * dt

	func attack(primary_target: Variant, ctx: Variant, damage_override: float = -1.0) -> void:
		if attack_cooldown > 0.0:
			return
		var actual_damage = (damage_override if damage_override >= 0.0 else dmg)
		if actual_damage <= 0.0:
			attack_cooldown = 1.0 / max(attack_speed, 0.01)
			return
		var is_ranged_attack = attack_range > 1.7 * TILE_SIZE
		if is_ranged_attack:
			var visual = {
				"type": "ellipse",
				"size": 8.0,
				"color": [200, 200, 255, 220] if is_friendly else [255, 200, 200, 220],
			}
			ctx.game_objects.append(Projectile.new(
				pos.x,
				pos.y,
				primary_target,
				10.0,
				actual_damage,
				is_friendly,
				visual,
				card_data
			))
			if special == "stun_split_attack":
				var second_target = ctx.find_secondary_target(self, primary_target)
				if second_target != null:
					ctx.game_objects.append(Projectile.new(
						pos.x,
						pos.y,
						second_target,
						10.0,
						actual_damage,
						is_friendly,
						visual,
						card_data
					))
		else:
			if splash_radius > 0.0:
				for victim in ctx.get_enemy_objects_and_towers(is_friendly):
					if not ctx.is_target_alive(victim):
						continue
					var threshold = splash_radius + ctx.get_target_radius(victim)
					if pos.distance_to(victim.pos) <= threshold:
						victim.take_damage(actual_damage)
						ctx.spawn_particle_effect(victim.pos, 3, Color(1.0, 0.6, 0.1, 0.9), "hit_splash")
			else:
				primary_target.take_damage(actual_damage)
				ctx.spawn_particle_effect(primary_target.pos, 5, Color(1.0, 1.0, 0.0, 0.9), "hit")
				if special == "stun_split_attack":
					primary_target.attack_cooldown = max(primary_target.attack_cooldown, 0.5)
		attack_cooldown = 1.0 / max(attack_speed, 0.01)

	func take_damage(amount: float) -> void:
		if amount <= 0.0:
			return
		if special == "shield_to_building" and is_shielded:
			shield_hp -= amount
			if shield_hp <= 0.0:
				is_shielded = false
				hp = base_hp_after_shield
				max_hp = base_hp_after_shield
				speed = 0.0
				base_speed = 0.0
				is_cart_broken = true
				color = COLOR_BUILDING
			return
		super(amount)

	func draw(canvas: CanvasItem) -> void:
		if is_destroyed:
			return
		var r = get_collision_radius()
		if movement_type == "air":
			canvas.draw_circle(pos + Vector2(0.0, r * 0.65), r * 0.75, Color(0, 0, 0, 0.2))
			canvas.draw_circle(pos, r, color)
		else:
			var rect = Rect2(pos - Vector2(r, r), Vector2(r * 2.0, r * 2.0))
			canvas.draw_rect(rect, color, true)
		var bar_pos = pos + Vector2(0.0, -r - 9.0)
		if special == "shield_to_building" and is_shielded:
			_draw_bar(canvas, bar_pos, max(20.0, r * 2.0), 5.0, shield_hp, max_hp, Color(0.8, 0.85, 1.0, 1.0))
		else:
			_draw_bar(canvas, bar_pos, max(20.0, r * 2.0), 5.0, hp, max_hp, Color(0.2, 1.0, 0.35, 1.0))


class Building extends GameObject:
	var dmg = 0.0
	var attack_range = 6.0 * TILE_SIZE
	var target_type = "any"
	var splash_radius = 0.0
	var special = ""
	var attack_speed = 1.0
	var size = TILE_SIZE * 1.5
	var color = COLOR_BUILDING
	var is_tower = false
	var is_king = false
	var ramp_dmg_stages: Array = []
	var current_ramp_stage = 0
	var ramp_up_time = 2.0
	var time_on_target = 0.0

	func _init(x: float, y: float, friendly: bool, source_card_data: Dictionary = {}) -> void:
		super(x, y, friendly, source_card_data)
		max_hp = max(1.0, _to_float(source_card_data.get("hp", 1000.0), 1000.0))
		hp = max_hp
		dmg = _to_float(source_card_data.get("dmg", 100.0), 100.0)
		attack_range = max(20.0, _to_float(source_card_data.get("attackRange", 6.0 * TILE_SIZE), 6.0 * TILE_SIZE))
		target_type = str(source_card_data.get("targetType", "any"))
		splash_radius = max(0.0, _to_float(source_card_data.get("splashRadius", 0.0), 0.0))
		special = str(source_card_data.get("special", ""))
		color = COLOR_BUILDING.lerp((COLOR_PLAYER if is_friendly else COLOR_AI), 0.35)
		attack_speed = 1.0
		if special == "ramping_damage":
			ramp_dmg_stages = [dmg, dmg * 4.0, dmg * 20.0]
			attack_speed = 4.0
		elif special == "fast_attack_rate":
			attack_speed = 3.33

	func get_collision_radius() -> float:
		return size * 0.45

	func _to_float(value: Variant, default_value: float = 0.0) -> float:
		match typeof(value):
			TYPE_FLOAT:
				return value
			TYPE_INT:
				return value * 1.0
			TYPE_STRING:
				var text = str(value).strip_edges()
				if text.is_empty():
					return default_value
				if text.is_valid_int() or text.is_valid_float():
					return text.to_float()
				return default_value
			_:
				return default_value

	func _draw_bar(canvas: CanvasItem, center: Vector2, width: float, height: float, cur_hp: float, max_hp_val: float, fill_color: Color) -> void:
		var pct = 0.0
		if max_hp_val > 0.0:
			pct = clampf(cur_hp / max_hp_val, 0.0, 1.0)
		var bg = Rect2(center + Vector2(-width * 0.5, -height * 0.5), Vector2(width, height))
		canvas.draw_rect(bg, Color(0.12, 0.12, 0.12, 0.9), true)
		canvas.draw_rect(Rect2(bg.position, Vector2(width * pct, height)), fill_color, true)

	func update(dt: float, ctx: Variant) -> void:
		_tick_freeze(dt)
		if hp <= 0.0:
			is_destroyed = true
			return
		if attack_cooldown > 0.0:
			attack_cooldown = max(0.0, attack_cooldown - dt)
		if target == null or not ctx.is_target_alive(target):
			target = ctx.find_targets_for_building(self)
			if special == "ramping_damage":
				current_ramp_stage = 0
				time_on_target = 0.0
		if target == null:
			return
		var dist_to_target = pos.distance_to(target.pos)
		if dist_to_target > attack_range:
			target = null
			if special == "ramping_damage":
				current_ramp_stage = 0
				time_on_target = 0.0
			return
		var current_damage = dmg
		if special == "ramping_damage":
			time_on_target += dt
			if time_on_target >= ramp_up_time and current_ramp_stage < ramp_dmg_stages.size() - 1:
				current_ramp_stage += 1
				time_on_target = 0.0
			current_damage = ramp_dmg_stages[current_ramp_stage]
		attack(target, ctx, current_damage)

	func attack(target_obj: Variant, ctx: Variant, damage_to_deal: float) -> void:
		if attack_cooldown > 0.0:
			return
		if damage_to_deal <= 0.0:
			return
		var projectile_speed = 12.0
		var visual = {
			"type": "ellipse",
			"size": (10.0 if is_tower and is_king else 8.0),
			"color": ([100, 150, 255, 220] if is_friendly else [255, 120, 120, 220]),
		}
		if special == "ramping_damage":
			projectile_speed = 15.0
			visual["size"] = 6.0 + current_ramp_stage * 2.0
			visual["color"] = [255, max(40, 150 - current_ramp_stage * 40), 0, 240]
		elif special == "fast_attack_rate":
			projectile_speed = 18.0
			visual["size"] = 6.0
			visual["color"] = [210, 210, 210, 220]
		ctx.game_objects.append(Projectile.new(
			pos.x,
			pos.y,
			target_obj,
			projectile_speed,
			damage_to_deal,
			is_friendly,
			visual,
			card_data
		))
		attack_cooldown = 1.0 / max(attack_speed, 0.01)

	func draw(canvas: CanvasItem) -> void:
		if is_destroyed:
			return
		var body_color = color
		var half = size * 0.5
		if is_tower and is_king:
			var points = PackedVector2Array([
				pos + Vector2(-half * 0.45, half * 0.5),
				pos + Vector2(half * 0.45, half * 0.5),
				pos + Vector2(half * 0.75, -half * 0.55),
				pos + Vector2(-half * 0.75, -half * 0.55),
			])
			canvas.draw_colored_polygon(points, body_color)
		else:
			var rect = Rect2(pos - Vector2(half * 0.55, half), Vector2(half * 1.1, half * 1.6 if is_tower else half * 1.2))
			canvas.draw_rect(rect, body_color, true)
		var bar_pos = pos + Vector2(0.0, -half - 14.0)
		_draw_bar(canvas, bar_pos, max(28.0, size * 0.85), 7.0, hp, max_hp, Color(0.2, 1.0, 0.35, 1.0))


class Spell extends GameObject:
	var dmg = 0.0
	var radius = 120.0
	var splash_radius = 120.0
	var applied = false
	var special = ""
	var freeze_duration = 0.0
	var log_speed = TILE_SIZE * 8.0
	var log_width = TILE_SIZE * 0.8
	var log_travel_distance = 0.0
	var distance_traveled = 0.0
	var direction = Vector2.UP
	var hit_units = {}
	var spawn_interval = 0.5
	var skeletons_to_spawn = 0
	var spawn_timer = 0.0

	func _init(x: float, y: float, friendly: bool, source_card_data: Dictionary, spell_dmg: float, spell_range: float, spell_splash_radius: float) -> void:
		super(x, y, friendly, source_card_data)
		movement_type = "spell"
		dmg = spell_dmg
		radius = max(1.0, spell_range)
		splash_radius = max(1.0, spell_splash_radius if spell_splash_radius > 0.0 else spell_range)
		special = str(source_card_data.get("special", ""))
		duration = 0.5
		if special == "linear_pushback":
			log_travel_distance = radius
			duration = log_travel_distance / max(log_speed, 0.01)
			direction = (Vector2.UP if is_friendly else Vector2.DOWN)
			pos.y += (log_travel_distance * 0.5 if is_friendly else -log_travel_distance * 0.5)
		elif special == "area_spawn_over_time":
			skeletons_to_spawn = 10
			duration = skeletons_to_spawn * spawn_interval
			spawn_timer = 0.0
		elif special == "freeze":
			freeze_duration = 4.0
			duration = freeze_duration + 0.5

	func get_collision_radius() -> float:
		return splash_radius

	func update(dt: float, ctx: Variant) -> void:
		duration -= dt
		if not applied and special != "linear_pushback" and special != "area_spawn_over_time":
			apply_effect(ctx)
			applied = true
		if special == "linear_pushback":
			var step = log_speed * dt
			pos += direction * step
			distance_traveled += step
			apply_log_effect(ctx)
			if distance_traveled >= log_travel_distance:
				duration = 0.0
		elif special == "area_spawn_over_time":
			spawn_timer -= dt
			if spawn_timer <= 0.0 and skeletons_to_spawn > 0:
				spawn_graveyard_skeleton(ctx)
				skeletons_to_spawn -= 1
				spawn_timer = spawn_interval
		if duration <= 0.0:
			is_destroyed = true

	func apply_log_effect(ctx: Variant) -> void:
		var rect = Rect2(
			Vector2(pos.x - splash_radius * 0.5, pos.y - log_width * 0.5),
			Vector2(splash_radius, log_width)
		)
		for obj in ctx.get_enemy_objects_and_towers(is_friendly):
			if not ctx.is_target_alive(obj):
				continue
			if obj.movement_type != "ground":
				continue
			if hit_units.has(obj.id):
				continue
			if rect.has_point(obj.pos):
				obj.take_damage(dmg)
				hit_units[obj.id] = true
				obj.attack_cooldown = max(obj.attack_cooldown, 0.2)
				obj.target = null

	func spawn_graveyard_skeleton(ctx: Variant) -> void:
		var angle = randf() * TAU
		var radius_scale = randf() * radius * 0.8
		var spawn_pos = pos + Vector2(cos(angle), sin(angle)) * radius_scale
		ctx.spawn_template_unit("skeleton_basic", card_data, is_friendly, spawn_pos)
		ctx.spawn_particle_effect(spawn_pos, 5, Color(0.6, 1.0, 0.6, 0.9), "spawn")

	func _can_hit_target(obj: Variant) -> bool:
		var card_target_type = str(card_data.get("targetType", "any"))
		if card_target_type == "any":
			return true
		if card_target_type == "buildings":
			return obj is Building and obj.is_tower
		if card_target_type == "ground":
			return obj.movement_type != "air"
		if card_target_type == "air":
			return obj.movement_type == "air"
		return true

	func apply_effect(ctx: Variant) -> void:
		var candidates = ctx.get_enemy_objects_and_towers(is_friendly)
		if special == "multi_target_3":
			var valid = []
			for obj in candidates:
				if not ctx.is_target_alive(obj):
					continue
				if pos.distance_to(obj.pos) > radius:
					continue
				if not _can_hit_target(obj):
					continue
				valid.append(obj)
			valid.sort_custom(func(a, b): return a.hp > b.hp)
			var count = min(3, valid.size())
			for i in count:
				var target = valid[i]
				target.take_damage(dmg)
				ctx.spawn_particle_effect(target.pos, 12, Color(1.0, 1.0, 0.2, 0.9), "lightning_bolt")
			return
		for obj in candidates:
			if not ctx.is_target_alive(obj):
				continue
			if pos.distance_to(obj.pos) > splash_radius:
				continue
			if not _can_hit_target(obj):
				continue
			obj.take_damage(dmg)
			if special == "freeze":
				obj.apply_freeze(freeze_duration)

	func draw(canvas: CanvasItem) -> void:
		if is_destroyed:
			return
		var alpha = clampf(duration / 0.5, 0.0, 1.0)
		var base = Color(COLOR_SPELL.r, COLOR_SPELL.g, COLOR_SPELL.b, COLOR_SPELL.a * alpha)
		if special == "linear_pushback":
			var rect = Rect2(pos - Vector2(splash_radius * 0.5, log_width * 0.5), Vector2(splash_radius, log_width))
			canvas.draw_rect(rect, Color(0.55, 0.3, 0.12, 0.8 * alpha), true)
		elif special == "area_spawn_over_time":
			canvas.draw_circle(pos, radius, Color(0.2, 0.8, 0.2, 0.15 * alpha))
			canvas.draw_arc(pos, radius, 0.0, TAU, 48, Color(0.2, 0.9, 0.2, 0.7 * alpha), 2.0)
		elif special == "freeze":
			canvas.draw_circle(pos, splash_radius, Color(0.4, 0.65, 1.0, 0.25 * alpha))
			canvas.draw_arc(pos, splash_radius, 0.0, TAU, 56, Color(0.85, 0.93, 1.0, 0.75 * alpha), 3.0)
		else:
			canvas.draw_circle(pos, splash_radius, base)


class Particle:
	var pos: Vector2
	var vel: Vector2
	var lifespan = 0.5
	var color = Color(1, 1, 1, 1)
	var size = 4.0
	var kind = "explosion"

	func _init(x: float, y: float, particle_color: Color, particle_type: String = "explosion") -> void:
		pos = Vector2(x, y)
		color = particle_color
		kind = particle_type
		size = randf_range(3.0, 8.0)
		if kind == "line" or kind == "lightning_bolt":
			vel = Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))
			lifespan = 0.25
		elif kind == "hit" or kind == "hit_splash":
			vel = Vector2(randf_range(-75.0, 75.0), randf_range(-75.0, 75.0))
			lifespan = 0.35
		else:
			vel = Vector2(randf_range(-120.0, 120.0), randf_range(-120.0, 120.0))
			lifespan = randf_range(0.45, 0.8)

	func update(dt: float) -> void:
		pos += vel * dt
		if kind == "explosion" or kind == "death":
			vel *= 0.95
		lifespan -= dt

	func is_finished() -> bool:
		return lifespan <= 0.0

	func draw(canvas: CanvasItem) -> void:
		var alpha = clampf(lifespan / 0.8, 0.0, 1.0)
		var c = Color(color.r, color.g, color.b, color.a * alpha)
		if kind == "line" or kind == "lightning_bolt":
			canvas.draw_rect(Rect2(pos - Vector2(size * 0.8, size * 0.3), Vector2(size * 1.6, size * 0.6)), c, true)
		else:
			canvas.draw_circle(pos, size * 0.5, c)


class Projectile extends GameObject:
	var speed = TILE_SIZE * 10.0
	var damage = 100.0
	var visual_type = "ellipse"
	var visual_size = 8.0
	var visual_color = Color(1, 1, 1, 1)
	var rotation = 0.0
	var has_arrived = false

	func _init(start_x: float, start_y: float, target_object: Variant, speed_scale: float, hit_damage: float, friendly: bool, visual_options: Dictionary = {}, shooter_card_data: Dictionary = {}) -> void:
		super(start_x, start_y, friendly, shooter_card_data)
		target = target_object
		movement_type = "projectile"
		speed = speed_scale * TILE_SIZE
		damage = hit_damage
		visual_type = str(visual_options.get("type", "ellipse"))
		visual_size = _to_float(visual_options.get("size", 8.0), 8.0)
		visual_color = _color_from_any(
			visual_options.get("color", ([180, 180, 255, 220] if friendly else [255, 180, 180, 220])),
			Color(0.9, 0.9, 1.0, 1.0)
		)
		if target != null:
			rotation = (target.pos - pos).angle()

	func _to_float(value: Variant, default_value: float = 0.0) -> float:
		match typeof(value):
			TYPE_FLOAT:
				return value
			TYPE_INT:
				return value * 1.0
			TYPE_STRING:
				var text = str(value).strip_edges()
				if text.is_empty():
					return default_value
				if text.is_valid_int() or text.is_valid_float():
					return text.to_float()
				return default_value
			_:
				return default_value

	func _color_from_any(raw: Variant, fallback: Color) -> Color:
		if raw is Color:
			return raw
		if raw is Array:
			var arr: Array = raw
			if arr.size() >= 3:
				var rr = clampf(_to_float(arr[0], 0.0) / 255.0, 0.0, 1.0)
				var gg = clampf(_to_float(arr[1], 0.0) / 255.0, 0.0, 1.0)
				var bb = clampf(_to_float(arr[2], 0.0) / 255.0, 0.0, 1.0)
				var aa = 1.0
				if arr.size() >= 4:
					aa = clampf(_to_float(arr[3], 255.0) / 255.0, 0.0, 1.0)
				return Color(rr, gg, bb, aa)
		return fallback

	func get_collision_radius() -> float:
		return visual_size * 0.5

	func update(dt: float, ctx: Variant) -> void:
		if has_arrived or target == null or not ctx.is_target_alive(target):
			is_destroyed = true
			return
		var dir = target.pos - pos
		var dist = dir.length()
		var target_radius = ctx.get_target_radius(target)
		if dist <= max(4.0, target_radius):
			has_arrived = true
			target.take_damage(damage)
			ctx.spawn_particle_effect(target.pos, 5, visual_color, "hit")
			is_destroyed = true
			return
		var step = dir.normalized() * speed * dt
		pos += step
		if visual_type == "rect":
			rotation = step.angle()

	func draw(canvas: CanvasItem) -> void:
		if is_destroyed:
			return
		if visual_type == "rect":
			var basis = Transform2D(rotation, pos)
			var points = PackedVector2Array([
				basis * Vector2(-visual_size * 0.6, -visual_size * 0.15),
				basis * Vector2(visual_size * 0.6, -visual_size * 0.15),
				basis * Vector2(visual_size * 0.6, visual_size * 0.15),
				basis * Vector2(-visual_size * 0.6, visual_size * 0.15),
			])
			canvas.draw_colored_polygon(points, visual_color)
		else:
			canvas.draw_circle(pos, visual_size * 0.5, visual_color)
