class_name BattleVisualNode
extends Node2D

const Entities = preload("res://scripts/battle/entities.gd")

@export_enum("unit", "building", "spell", "projectile", "particle") var visual_kind: String = "unit"

var object_id := -1
var owner_player_id := -1

var _hp := 1.0
var _max_hp := 1.0
var _shield_hp := 0.0
var _shield_max_hp := 0.0
var _show_hp := false
var _is_shielded := false

var _unit_radius := Entities.TILE_SIZE * 0.45
var _unit_color := Color.WHITE
var _unit_is_air := false
var _unit_name := ""

var _building_size := Entities.TILE_SIZE * 1.5
var _building_color := Color.WHITE
var _building_is_king := false

var _spell_radius := Entities.TILE_SIZE
var _spell_color := Entities.COLOR_SPELL
var _spell_alpha := 1.0
var _spell_special := ""
var _spell_line_width := Entities.TILE_SIZE * 2.0
var _spell_log_width := Entities.TILE_SIZE * 0.8

var _projectile_size := 8.0
var _projectile_color := Color.WHITE
var _projectile_type := "ellipse"
var _projectile_rotation := 0.0

var _particle_size := 4.0
var _particle_color := Color.WHITE
var _particle_alpha := 1.0
var _particle_kind := "explosion"


func bind_to_object(new_object_id: int, source: Variant, player_id: int = -1) -> void:
	object_id = new_object_id
	owner_player_id = player_id
	update_from_object(source)


func update_from_object(source: Variant) -> void:
	if source == null:
		visible = false
		return
	visible = true
	match visual_kind:
		"unit":
			_update_from_unit(source)
		"building":
			_update_from_building(source)
		"spell":
			_update_from_spell(source)
		"projectile":
			_update_from_projectile(source)
		"particle":
			_update_from_particle(source)
	queue_redraw()


func _update_from_unit(unit: Variant) -> void:
	position = unit.pos
	z_index = int(position.y)
	_unit_radius = max(2.0, unit.get_collision_radius())
	_unit_color = unit.color
	_unit_is_air = unit.movement_type == "air"
	_unit_name = str(unit.unit_name)
	_hp = max(0.0, unit.hp)
	_max_hp = max(0.01, unit.max_hp)
	_show_hp = true
	_is_shielded = unit.special == "shield_to_building" and unit.is_shielded
	_shield_hp = max(0.0, unit.shield_hp)
	_shield_max_hp = max(0.01, unit.max_hp)
	rotation = 0.0


func _update_from_building(building: Variant) -> void:
	position = building.pos
	z_index = int(position.y)
	_building_size = max(4.0, building.size)
	_building_color = building.color
	_building_is_king = building.is_tower and building.is_king
	_hp = max(0.0, building.hp)
	_max_hp = max(0.01, building.max_hp)
	_show_hp = true
	rotation = 0.0


func _update_from_spell(spell: Variant) -> void:
	position = spell.pos
	z_index = int(position.y)
	_spell_radius = max(1.0, spell.splash_radius if spell.special != "area_spawn_over_time" else spell.radius)
	_spell_special = spell.special
	_spell_alpha = clampf(spell.duration / 0.5, 0.0, 1.0)
	_spell_line_width = max(4.0, spell.splash_radius)
	_spell_log_width = max(4.0, spell.log_width)
	_spell_color = Entities.COLOR_SPELL
	_show_hp = false
	rotation = 0.0


func _update_from_projectile(projectile: Variant) -> void:
	position = projectile.pos
	z_index = int(position.y)
	_projectile_size = max(2.0, projectile.visual_size)
	_projectile_color = projectile.visual_color
	_projectile_type = projectile.visual_type
	_projectile_rotation = projectile.rotation
	rotation = (_projectile_rotation if _projectile_type == "rect" else 0.0)
	_show_hp = false


func _update_from_particle(particle: Variant) -> void:
	position = particle.pos
	z_index = int(position.y)
	_particle_size = max(1.0, particle.size * 0.5)
	_particle_color = particle.color
	_particle_kind = particle.kind
	_particle_alpha = clampf(particle.lifespan / 0.8, 0.0, 1.0)
	_show_hp = false
	rotation = 0.0


func _draw() -> void:
	match visual_kind:
		"unit":
			_draw_unit()
		"building":
			_draw_building()
		"spell":
			_draw_spell()
		"projectile":
			_draw_projectile()
		"particle":
			_draw_particle()


func _draw_unit() -> void:
	if _unit_is_air:
		draw_circle(Vector2(0.0, _unit_radius * 0.65), _unit_radius * 0.75, Color(0.0, 0.0, 0.0, 0.2))
		draw_circle(Vector2.ZERO, _unit_radius, _unit_color)
	else:
		var rect = Rect2(Vector2(-_unit_radius, -_unit_radius), Vector2(_unit_radius * 2.0, _unit_radius * 2.0))
		draw_rect(rect, _unit_color, true)
	if _show_hp:
		var bar_pos = Vector2(0.0, -_unit_radius - 9.0)
		if _is_shielded:
			_draw_hp_bar(bar_pos, max(20.0, _unit_radius * 2.0), 5.0, _shield_hp, _shield_max_hp, Color(0.8, 0.85, 1.0, 1.0))
		else:
			_draw_hp_bar(bar_pos, max(20.0, _unit_radius * 2.0), 5.0, _hp, _max_hp, Color(0.2, 1.0, 0.35, 1.0))
	_draw_unit_name()


func _draw_building() -> void:
	var half = _building_size * 0.5
	if _building_is_king:
		var points = PackedVector2Array([
			Vector2(-half * 0.45, half * 0.5),
			Vector2(half * 0.45, half * 0.5),
			Vector2(half * 0.75, -half * 0.55),
			Vector2(-half * 0.75, -half * 0.55),
		])
		draw_colored_polygon(points, _building_color)
	else:
		var rect = Rect2(Vector2(-half * 0.55, -half), Vector2(half * 1.1, half * 1.2))
		draw_rect(rect, _building_color, true)
	if _show_hp:
		_draw_hp_bar(Vector2(0.0, -half - 14.0), max(28.0, _building_size * 0.85), 7.0, _hp, _max_hp, Color(0.2, 1.0, 0.35, 1.0))


func _draw_spell() -> void:
	var alpha = clampf(_spell_alpha, 0.0, 1.0)
	if _spell_special == "linear_pushback":
		var rect = Rect2(Vector2(-_spell_line_width * 0.5, -_spell_log_width * 0.5), Vector2(_spell_line_width, _spell_log_width))
		draw_rect(rect, Color(0.55, 0.3, 0.12, 0.8 * alpha), true)
	elif _spell_special == "area_spawn_over_time":
		draw_circle(Vector2.ZERO, _spell_radius, Color(0.2, 0.8, 0.2, 0.15 * alpha))
		draw_arc(Vector2.ZERO, _spell_radius, 0.0, TAU, 48, Color(0.2, 0.9, 0.2, 0.7 * alpha), 2.0)
	elif _spell_special == "freeze":
		draw_circle(Vector2.ZERO, _spell_radius, Color(0.4, 0.65, 1.0, 0.25 * alpha))
		draw_arc(Vector2.ZERO, _spell_radius, 0.0, TAU, 56, Color(0.85, 0.93, 1.0, 0.75 * alpha), 3.0)
	else:
		draw_circle(Vector2.ZERO, _spell_radius, Color(_spell_color.r, _spell_color.g, _spell_color.b, _spell_color.a * alpha))


func _draw_projectile() -> void:
	if _projectile_type == "rect":
		var rect = Rect2(Vector2(-_projectile_size * 0.6, -_projectile_size * 0.15), Vector2(_projectile_size * 1.2, _projectile_size * 0.3))
		draw_rect(rect, _projectile_color, true)
	else:
		draw_circle(Vector2.ZERO, _projectile_size * 0.5, _projectile_color)


func _draw_particle() -> void:
	var c = Color(_particle_color.r, _particle_color.g, _particle_color.b, _particle_color.a * _particle_alpha)
	if _particle_kind == "line" or _particle_kind == "lightning_bolt":
		var rect = Rect2(Vector2(-_particle_size * 0.8, -_particle_size * 0.3), Vector2(_particle_size * 1.6, _particle_size * 0.6))
		draw_rect(rect, c, true)
	else:
		draw_circle(Vector2.ZERO, _particle_size, c)


func _draw_hp_bar(center: Vector2, width: float, height: float, hp: float, max_hp: float, fill_color: Color) -> void:
	var pct = 0.0
	if max_hp > 0.0:
		pct = clampf(hp / max_hp, 0.0, 1.0)
	var bg = Rect2(center + Vector2(-width * 0.5, -height * 0.5), Vector2(width, height))
	draw_rect(bg, Color(0.12, 0.12, 0.12, 0.9), true)
	draw_rect(Rect2(bg.position, Vector2(width * pct, height)), fill_color, true)


func _draw_unit_name() -> void:
	if _unit_name == "":
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var font_size = 12
	var w = font.get_string_size(_unit_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var base = Vector2(-w * 0.5, -_unit_radius - 18.0)
	draw_string(font, base + Vector2(1.0, 1.0), _unit_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.8))
	draw_string(font, base, _unit_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.96, 0.96, 0.96, 1.0))
