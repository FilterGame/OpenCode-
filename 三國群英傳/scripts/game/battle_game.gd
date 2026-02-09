class_name BattleGame
extends Node2D

const GameConfig = preload("res://scripts/core/game_config.gd")
const BattleCameraScript = preload("res://scripts/core/battle_camera.gd")

const ENTITY_SCENE: PackedScene = preload("res://scenes/prefabs/entity.tscn")
const GENERAL_SCENE: PackedScene = preload("res://scenes/prefabs/general.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/prefabs/projectile.tscn")
const PARTICLE_SCENE: PackedScene = preload("res://scenes/prefabs/particle.tscn")
const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/prefabs/floating_text.tscn")

@onready var background: Node2D = $Background
@onready var world_layer: Node2D = $WorldLayer
@onready var unit_container: Node2D = $WorldLayer/UnitContainer
@onready var effect_container: Node2D = $WorldLayer/EffectContainer
@onready var ui: Control = $UILayer/BattleUI
@onready var second_timer: Timer = $SecondTimer

var camera_model = BattleCameraScript.new()

var entities: Array = []
var projectiles: Array = []
var particles: Array = []
var floating_texts: Array = []

var player_general: Node = null
var enemy_general: Node = null

var state: String = "intro"
var timer_value: int = GameConfig.TIMER_START
var frame_count: int = 0
var intro_time: int = 0
var game_speed: float = 1.0
var menu_open: bool = false
var ground_y: float = 540.0

func _ready() -> void:
	randomize()
	camera_model.setup(get_viewport_rect().size)
	compute_ground_y()
	setup_ui()
	init_battle()
	second_timer.timeout.connect(_on_second_tick)
	second_timer.start()
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func setup_ui() -> void:
	ui.menu_toggled.connect(toggle_menu)
	ui.command_selected.connect(send_command)
	ui.skill_cast_requested.connect(cast_skill)
	ui.update_timer(timer_value)
	ui.show_start_text(GameConfig.START_TEXT, 0.0)

func compute_ground_y() -> void:
	ground_y = get_viewport_rect().size.y - GameConfig.GROUND_UI_HEIGHT
	background.setup(ground_y)
	camera_model.setup(get_viewport_rect().size)
	camera_model.clamp_to_world()

func _on_viewport_size_changed() -> void:
	compute_ground_y()

func init_battle() -> void:
	entities.clear()
	projectiles.clear()
	particles.clear()
	floating_texts.clear()

	player_general = GENERAL_SCENE.instantiate()
	player_general.setup_general(Vector2(200, ground_y), GameConfig.TEAM_PLAYER, "\u5f35\u98db")
	bind_entity(player_general)
	unit_container.add_child(player_general)
	entities.append(player_general)

	enemy_general = GENERAL_SCENE.instantiate()
	enemy_general.setup_general(Vector2(1800, ground_y), GameConfig.TEAM_ENEMY, "\u5442\u5e03")
	bind_entity(enemy_general)
	unit_container.add_child(enemy_general)
	entities.append(enemy_general)

	for i in 4:
		for j in 5:
			spawn_unit(Vector2(50 + i * 30, ground_y - 60 + j * 30), GameConfig.TEAM_PLAYER, "infantry")
			spawn_unit(Vector2(1900 - i * 30, ground_y - 60 + j * 30), GameConfig.TEAM_ENEMY, "infantry")

	for j in 5:
		spawn_unit(Vector2(0, ground_y - 60 + j * 30), GameConfig.TEAM_PLAYER, "archer")
		spawn_unit(Vector2(1950, ground_y - 60 + j * 30), GameConfig.TEAM_ENEMY, "archer")

	update_ui()

func spawn_unit(start_pos: Vector2, team: int, unit_type: String) -> void:
	var unit = ENTITY_SCENE.instantiate()
	unit.setup(start_pos, team, unit_type)
	bind_entity(unit)
	unit_container.add_child(unit)
	entities.append(unit)

func bind_entity(entity: Node) -> void:
	entity.set_callbacks(spawn_projectile, add_floating_text)

func _process(_delta: float) -> void:
	var gs: float = 0.0 if state == "cutscene" else game_speed
	frame_count += 1

	handle_intro_camera()
	camera_model.clamp_to_world()
	world_layer.position = Vector2(-camera_model.x, -camera_model.y)
	background.tick(frame_count, camera_model.x)

	if state == "battle" or state == "cutscene":
		for e in entities:
			e.update_entity(entities, gs, ground_y)

	update_projectiles(gs)
	update_particles(gs)
	update_floating_texts(gs)
	update_ui()

func handle_intro_camera() -> void:
	if state != "intro":
		return
	intro_time += 1
	if intro_time < 100:
		camera_model.target_x = 0.0
	elif intro_time < 250:
		camera_model.x += ((GameConfig.WORLD_WIDTH - camera_model.width) - camera_model.x) * 0.02
	elif intro_time < 350:
		pass
	else:
		camera_model.x += (0.0 - camera_model.x) * 0.05
		if abs(camera_model.x) < 10.0:
			state = "battle"
			show_start_fade(GameConfig.START_TEXT, 1.5)

func update_projectiles(gs: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p = projectiles[i]
		var reached: bool = p.update_projectile(gs)
		if reached:
			remove_projectile(i)
			continue

		if p.life > 0.0:
			for e in entities:
				if e.team != p.team and not e.dead and abs(e.position.x - p.position.x) < 20.0 and abs(e.position.y - p.position.y) < 40.0:
					e.take_damage(10.0)
					p.life = 0.0
					break

		if p.life <= 0.0:
			remove_projectile(i)

func remove_projectile(index: int) -> void:
	var p = projectiles[index]
	projectiles.remove_at(index)
	p.queue_free()

func update_particles(gs: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p = particles[i]
		p.update_particle(gs)
		if p.life <= 0.0:
			particles.remove_at(i)
			p.queue_free()

func update_floating_texts(gs: float) -> void:
	for i in range(floating_texts.size() - 1, -1, -1):
		var ft = floating_texts[i]
		if ft.update_floating(gs):
			floating_texts.remove_at(i)
			ft.queue_free()

func spawn_projectile(x: float, y: float, tx: float, ty: float, team: int) -> void:
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.setup_projectile(Vector2(x, y), Vector2(tx, ty), team)
	effect_container.add_child(projectile)
	projectiles.append(projectile)

func spawn_particle(p_position: Vector2, particle_type: String) -> void:
	var particle = PARTICLE_SCENE.instantiate()
	particle.setup_particle(p_position, particle_type)
	effect_container.add_child(particle)
	particles.append(particle)

func add_floating_text(world_pos: Vector2, text_value: String, color: Color) -> void:
	var text_node = FLOATING_TEXT_SCENE.instantiate()
	text_node.position = world_pos
	text_node.setup_text(text_value, color)
	effect_container.add_child(text_node)
	floating_texts.append(text_node)

func send_command(cmd: String) -> void:
	if state != "battle" and state != "cutscene":
		return
	player_general.set_command(cmd)
	for e in entities:
		if e.team == GameConfig.TEAM_PLAYER and not e.dead:
			e.set_command(cmd)
	add_floating_text(player_general.position + Vector2(0, -100), GameConfig.COMMAND_TEXT.get(cmd, cmd), Color.YELLOW)

func toggle_menu() -> void:
	if state != "battle" and state != "cutscene":
		return
	menu_open = not menu_open
	game_speed = 0.1 if menu_open else 1.0
	ui.set_command_overlay(menu_open)

func cast_skill() -> void:
	if state != "battle" and state != "cutscene":
		return
	if player_general == null or player_general.dead:
		return
	if player_general.mp < GameConfig.SKILL_COST:
		add_floating_text(player_general.position + Vector2(0, -80), "\u6280\u529b\u4e0d\u8db3", Color(0.6, 0.6, 0.6))
		return

	player_general.mp -= GameConfig.SKILL_COST
	state = "cutscene"
	ui.set_cutscene(true, GameConfig.SKILL_TEXT)
	play_skill_sequence()

func play_skill_sequence() -> void:
	await get_tree().create_timer(2.0).timeout
	ui.set_cutscene(false)
	state = "battle"
	execute_skill_effect("crescent", player_general.position, player_general.team)

func execute_skill_effect(effect_type: String, center_pos: Vector2, caster_team: int) -> void:
	if effect_type != "crescent":
		return
	for i in 10:
		spawn_particle(Vector2(center_pos.x + 50 + i * 20, center_pos.y), "wave")

	await get_tree().create_timer(0.5).timeout
	for e in entities:
		if e.team != caster_team and not e.dead and abs(e.position.y - center_pos.y) < 100.0:
			e.take_damage(50.0)
	camera_model.y = 10.0
	await get_tree().create_timer(0.2).timeout
	camera_model.y = 0.0

func update_ui() -> void:
	if player_general == null or enemy_general == null:
		return
	var p1_troops: int = count_alive_troops(GameConfig.TEAM_PLAYER)
	var p2_troops: int = count_alive_troops(GameConfig.TEAM_ENEMY)
	ui.update_player_panel(player_general.hp, player_general.max_hp, player_general.mp, p1_troops)
	ui.update_enemy_panel(enemy_general.hp, enemy_general.max_hp, p2_troops)
	ui.update_timer(timer_value)

	if state != "end":
		if player_general.dead:
			end_game(GameConfig.LOSE_TEXT)
		elif enemy_general.dead:
			end_game(GameConfig.WIN_TEXT)

func count_alive_troops(team_value: int) -> int:
	var count: int = 0
	for e in entities:
		if e.team == team_value and not e.dead and not e.is_horse:
			count += 1
	return count

func end_game(result_text: String) -> void:
	state = "end"
	ui.set_command_overlay(false)
	menu_open = false
	game_speed = 1.0
	ui.set_start_overlay_visible(true)
	ui.show_start_text(result_text, 1.0)

func show_start_fade(text_value: String, duration: float) -> void:
	ui.set_start_overlay_visible(true)
	ui.show_start_text(text_value, 1.0)
	var tween: Tween = create_tween()
	tween.tween_method(_set_start_overlay_alpha, 1.0, 0.0, duration)

func _set_start_overlay_alpha(alpha: float) -> void:
	ui.show_start_text(ui.start_text.text, alpha)

func _on_second_tick() -> void:
	if state == "battle" and timer_value > 0 and not menu_open:
		timer_value -= 1
	ui.update_timer(timer_value)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		toggle_menu()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			camera_model.drag_begin(event.position.x)
		else:
			camera_model.drag_end()
		return

	if event is InputEventMouseMotion:
		camera_model.drag_move(event.position.x)
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			camera_model.drag_begin(event.position.x)
		else:
			camera_model.drag_end()
		return

	if event is InputEventScreenDrag:
		camera_model.drag_move(event.position.x)
