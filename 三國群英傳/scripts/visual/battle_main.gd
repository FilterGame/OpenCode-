extends Node2D

const UNIT_SCENE: PackedScene = preload("res://scenes/prefabs/Unit.tscn")
const GENERAL_SCENE: PackedScene = preload("res://scenes/prefabs/General.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/prefabs/Projectile.tscn")
const HIT_PARTICLE_SCENE: PackedScene = preload("res://scenes/prefabs/HitParticle.tscn")
const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/prefabs/FloatingText.tscn")

const PLAYER_NAME := "???"
const ENEMY_NAME := "?頩?"
const ROUND_SECONDS := 99.0
const INITIAL_TROOPS_PER_SIDE := 12
const MAX_TROOPS_PER_SIDE := 25
const COMMAND_SLOWMO := 0.2
const SKILL_COST := 50

@onready var _unit_root: Node2D = $BattleLayer/UnitRoot
@onready var _projectile_root: Node2D = $BattleLayer/ProjectileRoot
@onready var _effect_root: Node2D = $BattleLayer/EffectRoot
@onready var _hud: BattleHUD = $UILayer/BattleHUD
@onready var _overlay: OverlayUI = $Overlay/OverlayUI

var _player_general: Node2D
var _enemy_general: Node2D

var _player_command: StringName = &"charge"
var _battle_time: float = ROUND_SECONDS
var _hud_update_cooldown: float = 0.0
var _reinforce_cooldown: float = 1.4
var _projectile_cooldown: float = 0.8
var _mana_cooldown: float = 0.65
var _speed_scale: float = 1.0
var _battle_ended: bool = false


func _ready() -> void:
	randomize()
	_wire_ui_events()
	_spawn_opening_forces()
	_refresh_hud()
	_overlay.show_start_text("???????")


func _process(delta: float) -> void:
	if _battle_ended:
		return

	var scaled_delta := delta * _speed_scale
	_battle_time = maxf(_battle_time - scaled_delta, 0.0)
	_reinforce_cooldown -= scaled_delta
	_projectile_cooldown -= scaled_delta
	_mana_cooldown -= scaled_delta
	_hud_update_cooldown -= scaled_delta

	if _reinforce_cooldown <= 0.0:
		_reinforce_cooldown = randf_range(1.8, 2.5)
		_try_spawn_reinforcement(1)
		_try_spawn_reinforcement(2)

	if _projectile_cooldown <= 0.0:
		_projectile_cooldown = randf_range(0.75, 1.05)
		_fire_volley(1)
		_fire_volley(2)

	if _mana_cooldown <= 0.0:
		_mana_cooldown = 0.65
		_tick_generals_mana()

	if _hud_update_cooldown <= 0.0:
		_hud_update_cooldown = 0.12
		_refresh_hud()

	_check_battle_end()


func _wire_ui_events() -> void:
	_hud.command_button_pressed.connect(_on_command_button_pressed)
	_overlay.menu_opened_changed.connect(_on_menu_opened_changed)
	_overlay.command_selected.connect(_on_command_selected)
	_overlay.skill_requested.connect(_on_skill_requested)


func _spawn_opening_forces() -> void:
	var viewport_size := get_viewport_rect().size
	var base_y := viewport_size.y * 0.62 + 22.0

	_player_general = _spawn_general(1, Vector2(154.0, base_y - 2.0), PLAYER_NAME)
	_enemy_general = _spawn_general(2, Vector2(viewport_size.x - 154.0, base_y - 2.0), ENEMY_NAME)

	for i in INITIAL_TROOPS_PER_SIDE:
		var left_pos := Vector2(randf_range(80.0, 280.0), base_y + randf_range(-70.0, 70.0))
		var right_pos := Vector2(viewport_size.x - randf_range(80.0, 280.0), base_y + randf_range(-70.0, 70.0))
		_spawn_unit(1, left_pos)
		_spawn_unit(2, right_pos)


func _spawn_general(team: int, pos: Vector2, name_text: String) -> Node2D:
	var general := GENERAL_SCENE.instantiate() as Node2D
	general.position = pos
	general.call("setup", team, name_text)
	if team == 1:
		general.call("set_command", _player_command)
	else:
		general.call("set_command", &"advance")
	_unit_root.add_child(general)
	_set_actor_speed(general)
	return general


func _spawn_unit(team: int, pos: Vector2) -> Node2D:
	var unit := UNIT_SCENE.instantiate() as Node2D
	unit.position = pos
	unit.call("setup", team, "?????)
	if team == 1:
		unit.call("set_command", _player_command)
	else:
		unit.call("set_command", &"advance")
	_unit_root.add_child(unit)
	_set_actor_speed(unit)
	return unit


func _try_spawn_reinforcement(team: int) -> void:
	if _troop_count(team) >= MAX_TROOPS_PER_SIDE:
		return
	var size := get_viewport_rect().size
	var base_y := size.y * 0.62 + 22.0
	if team == 1:
		_spawn_unit(team, Vector2(randf_range(68.0, 170.0), base_y + randf_range(-86.0, 86.0)))
	else:
		_spawn_unit(team, Vector2(size.x - randf_range(68.0, 170.0), base_y + randf_range(-86.0, 86.0)))


func _fire_volley(team: int) -> void:
	var source := _pick_random(_alive_entities(team))
	var target := _pick_random(_alive_entities(_enemy_team(team)))
	if source == null or target == null:
		return

	var projectile := PROJECTILE_SCENE.instantiate() as Node2D
	_projectile_root.add_child(projectile)
	projectile.call("launch", source.global_position + Vector2(0.0, -16.0), target.global_position + Vector2(0.0, -20.0), team, randi_range(10, 16))
	projectile.connect("impact", _on_projectile_impact)
	_set_actor_speed(projectile)


func _on_projectile_impact(hit_position: Vector2, team: int, damage: int) -> void:
	var victim := _nearest_entity(hit_position, _enemy_team(team))
	if victim == null:
		return
	victim.call("apply_damage", damage)
	_spawn_hit_effect(hit_position, team == 1, damage)

	if team == 1 and is_instance_valid(_player_general):
		_player_general.call("gain_mp", 4)
	elif team == 2 and is_instance_valid(_enemy_general):
		_enemy_general.call("gain_mp", 4)


func _spawn_hit_effect(world_pos: Vector2, is_player_attack: bool, damage: int) -> void:
	var particle := HIT_PARTICLE_SCENE.instantiate() as Node2D
	_effect_root.add_child(particle)
	var burst_color := Color(1.0, 0.78, 0.35) if is_player_attack else Color(1.0, 0.36, 0.3)
	particle.call("trigger", world_pos, burst_color)
	_set_actor_speed(particle)

	var text := FLOATING_TEXT_SCENE.instantiate() as Node2D
	_effect_root.add_child(text)
	var text_color := Color(1.0, 0.98, 0.82) if is_player_attack else Color(1.0, 0.85, 0.85)
	text.call("setup", "-%d" % damage, world_pos + Vector2(0.0, -18.0), text_color)
	_set_actor_speed(text)


func _tick_generals_mana() -> void:
	if is_instance_valid(_player_general):
		_player_general.call("gain_mp", 1)
	if is_instance_valid(_enemy_general):
		_enemy_general.call("gain_mp", 1)


func _refresh_hud() -> void:
	var p_hp := _value_from(_player_general, "hp")
	var p_max_hp := _value_from(_player_general, "max_hp", 1)
	var p_mp := _value_from(_player_general, "mp")
	var p_max_mp := _value_from(_player_general, "max_mp", 1)
	var p_troops := _troop_count(1)

	var e_hp := _value_from(_enemy_general, "hp")
	var e_max_hp := _value_from(_enemy_general, "max_hp", 1)
	var e_mp := _value_from(_enemy_general, "mp")
	var e_max_mp := _value_from(_enemy_general, "max_mp", 1)
	var e_troops := _troop_count(2)

	_hud.set_player_panel(PLAYER_NAME, p_hp, p_max_hp, p_mp, p_max_mp, p_troops)
	_hud.set_enemy_panel(ENEMY_NAME, e_hp, e_max_hp, e_mp, e_max_mp, e_troops)
	_hud.set_timer(int(ceili(_battle_time)))


func _check_battle_end() -> void:
	if _battle_time > 0.0 and is_instance_valid(_player_general) and is_instance_valid(_enemy_general):
		return

	_battle_ended = true
	_set_speed_scale(1.0)
	_overlay.set_command_menu_open(false)
	_hud.set_command_button_highlight(false)
	_overlay.show_start_text(_resolve_battle_result(), 2.6)
	_refresh_hud()


func _resolve_battle_result() -> String:
	if not is_instance_valid(_player_general) and not is_instance_valid(_enemy_general):
		return "????鞈?雓?
	if not is_instance_valid(_enemy_general):
		return "??????"
	if not is_instance_valid(_player_general):
		return "??????"

	var player_score := _troop_count(1) * 10 + _value_from(_player_general, "hp")
	var enemy_score := _troop_count(2) * 10 + _value_from(_enemy_general, "hp")
	if player_score > enemy_score:
		return "????鞊莎?"
	if enemy_score > player_score:
		return "????鞊莎?"
	return "????雓?豱?


func _on_command_button_pressed() -> void:
	if _battle_ended:
		return
	_overlay.toggle_command_menu()


func _on_menu_opened_changed(is_open: bool) -> void:
	if _battle_ended:
		return
	_hud.set_command_button_highlight(is_open)
	_set_speed_scale(COMMAND_SLOWMO if is_open else 1.0)


func _on_command_selected(command: StringName) -> void:
	if _battle_ended:
		return
	_player_command = command
	for entity in _alive_entities(1):
		entity.call("set_command", command)


func _on_skill_requested() -> void:
	if _battle_ended or not is_instance_valid(_player_general):
		return

	var current_mp := _value_from(_player_general, "mp")
	if current_mp < SKILL_COST:
		_overlay.show_skill_cutscene("????豲???)
		return

	var paid: bool = _player_general.call("spend_mp", SKILL_COST)
	if not paid:
		_overlay.show_skill_cutscene("????豲???)
		return

	_overlay.show_skill_cutscene("?蹎??????")
	for enemy in _alive_entities(2):
		var damage := 25 if enemy == _enemy_general else 16
		enemy.call("apply_damage", damage)
		_spawn_hit_effect(enemy.global_position + Vector2(0.0, -20.0), true, damage)

	_refresh_hud()


func _alive_entities(team: int) -> Array[Node2D]:
	var entities: Array[Node2D] = []
	for child in _unit_root.get_children():
		if child is Node2D and _value_from(child, "team") == team:
			entities.append(child)
	return entities


func _troop_count(team: int) -> int:
	var count := 0
	for entity in _alive_entities(team):
		if str(entity.get("unit_kind")) != "general":
			count += 1
	return count


func _enemy_team(team: int) -> int:
	return 2 if team == 1 else 1


func _pick_random(entities: Array[Node2D]) -> Node2D:
	if entities.is_empty():
		return null
	return entities[randi_range(0, entities.size() - 1)]


func _nearest_entity(world_pos: Vector2, team: int) -> Node2D:
	var best: Node2D
	var best_dist := INF
	for entity in _alive_entities(team):
		var dist := entity.global_position.distance_squared_to(world_pos)
		if dist < best_dist:
			best_dist = dist
			best = entity
	return best


func _set_speed_scale(value: float) -> void:
	_speed_scale = value
	for actor in get_tree().get_nodes_in_group(&"battle_actor"):
		_set_actor_speed(actor)


func _set_actor_speed(actor: Node) -> void:
	if _has_property(actor, &"speed_scale"):
		actor.set("speed_scale", _speed_scale)


func _has_property(actor: Object, property_name: StringName) -> bool:
	for info in actor.get_property_list():
		if info.has("name") and info["name"] == property_name:
			return true
	return false


func _value_from(target: Object, property_name: StringName, fallback: int = 0) -> int:
	if target == null or not is_instance_valid(target):
		return fallback
	if not _has_property(target, property_name):
		return fallback
	var value := target.get(property_name)
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return int(value)
	return fallback
