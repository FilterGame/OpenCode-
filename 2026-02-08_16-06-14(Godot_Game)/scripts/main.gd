extends Control

const Constants = preload("res://scripts/core/constants.gd")
const GameDataScript = preload("res://scripts/core/game_data.gd")
const StorageScript = preload("res://scripts/core/storage.gd")
const DeckBuilder = preload("res://scripts/ui/deck_builder.gd")
const BattleMatch = preload("res://scripts/battle/match.gd")
const BattleViewScene = preload("res://scenes/battle/battle_view.tscn")

var game_state: int = Constants.GameState.MENU
var game_data: RefCounted
var storage: RefCounted
var card_pool: Array = []

var deck_builder: DeckBuilder
var current_match: BattleMatch
var hovered_card: Dictionary = {}
var sound_enabled = true

var post_game_delay = -1.0
var mouse_pos = Vector2.ZERO
var view_scale = 1.0
var view_offset = Vector2.ZERO
var battle_view_node: Node2D = null

@onready var virtual_root: Control = $VirtualRoot
@onready var menu_layer: Control = $VirtualRoot/MenuLayer
@onready var menu_start_button: Button = $VirtualRoot/MenuLayer/StartButton
@onready var menu_version_label: Label = $VirtualRoot/MenuLayer/VersionLabel
@onready var post_game_layer: Control = $VirtualRoot/PostGameLayer
@onready var post_title_label: Label = $VirtualRoot/PostGameLayer/PostTitleLabel
@onready var post_message_label: Label = $VirtualRoot/PostGameLayer/PostMessageLabel
@onready var post_player_tower_label: Label = $VirtualRoot/PostGameLayer/PostPlayerTowerLabel
@onready var post_ai_tower_label: Label = $VirtualRoot/PostGameLayer/PostAiTowerLabel
@onready var post_player_cards_label: Label = $VirtualRoot/PostGameLayer/PostPlayerCardsLabel
@onready var post_ai_cards_label: Label = $VirtualRoot/PostGameLayer/PostAiCardsLabel
@onready var post_continue_label: Label = $VirtualRoot/PostGameLayer/PostContinueLabel
@onready var hud_layer: Control = $VirtualRoot/HudLayer
@onready var fps_label: Label = $VirtualRoot/HudLayer/FpsLabel
@onready var sound_label: Label = $VirtualRoot/HudLayer/SoundLabel
@onready var card_info_panel: Panel = $VirtualRoot/CardInfoPanel
@onready var card_info_label: Label = $VirtualRoot/CardInfoPanel/CardInfoLabel


func _ready() -> void:
	Engine.max_fps = Constants.FPS_TARGET
	mouse_filter = Control.MOUSE_FILTER_PASS
	game_data = GameDataScript.new()
	game_data.reload()
	storage = StorageScript.new()
	card_pool = game_data.get_card_pool()
	menu_start_button.pressed.connect(_on_menu_start_pressed)
	_update_view_transform()
	_init_game()
	_refresh_ui()
	set_process(true)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_view_transform()
		queue_redraw()


func _process(delta: float) -> void:
	match game_state:
		Constants.GameState.DECK_BUILDER:
			if deck_builder != null:
				deck_builder.update(delta)
		Constants.GameState.BATTLE:
			if current_match != null:
				current_match.update(delta)
				hovered_card = current_match.get_hovered_card()
				if current_match.winner != null and post_game_delay < 0.0:
					post_game_delay = 1.0
				if post_game_delay >= 0.0:
					post_game_delay -= delta
					if post_game_delay <= 0.0:
						game_state = Constants.GameState.POST_GAME
	queue_redraw()
	_refresh_ui()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _is_inside_virtual(event.position):
			mouse_pos = _screen_to_virtual(event.position)
			_handle_mouse_move(mouse_pos)
		return

	if event is InputEventMouseButton and event.pressed:
		if not _is_inside_virtual(event.position):
			return
		mouse_pos = _screen_to_virtual(event.position)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and deck_builder != null and game_state == Constants.GameState.DECK_BUILDER:
			deck_builder.handle_mouse_wheel(-1.0)
			hovered_card = deck_builder.get_hovered_card()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and deck_builder != null and game_state == Constants.GameState.DECK_BUILDER:
			deck_builder.handle_mouse_wheel(1.0)
			hovered_card = deck_builder.get_hovered_card()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(mouse_pos)
			return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			sound_enabled = not sound_enabled
			_refresh_ui()
			return
		if event.keycode == KEY_ESCAPE:
			if game_state == Constants.GameState.DECK_BUILDER or game_state == Constants.GameState.BATTLE or game_state == Constants.GameState.POST_GAME:
				_init_game()
				return
		if game_state == Constants.GameState.POST_GAME:
			_init_game()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK, true)
	_begin_virtual_draw()

	match game_state:
		Constants.GameState.DECK_BUILDER:
			if deck_builder != null:
				deck_builder.draw(self)
		Constants.GameState.BATTLE:
			if current_match != null:
				current_match.draw(self)
		Constants.GameState.POST_GAME:
			if current_match != null:
				current_match.draw(self)
	_end_virtual_draw()


func _handle_mouse_move(position: Vector2) -> void:
	match game_state:
		Constants.GameState.DECK_BUILDER:
			if deck_builder != null:
				deck_builder.handle_mouse_moved(position.x, position.y)
				hovered_card = deck_builder.get_hovered_card()
		Constants.GameState.BATTLE:
			if current_match != null:
				current_match.handle_mouse_moved(position)
				hovered_card = current_match.get_hovered_card()


func _handle_left_click(position: Vector2) -> void:
	match game_state:
		Constants.GameState.DECK_BUILDER:
			if deck_builder == null:
				return
			var result: Dictionary = deck_builder.handle_mouse_pressed(position.x, position.y)
			hovered_card = deck_builder.get_hovered_card()
			if bool(result.get("start_battle", false)):
				var selected_deck: Array = result.get("selected_deck", [])
				_start_battle(selected_deck)
		Constants.GameState.BATTLE:
			if current_match != null:
				current_match.handle_mouse_pressed(position)
		Constants.GameState.POST_GAME:
			_init_game()


func _start_battle(selected_deck: Array) -> void:
	_ensure_battle_view()
	current_match = BattleMatch.new(
		selected_deck,
		[],
		Vector2(Constants.CANVAS_WIDTH, Constants.CANVAS_HEIGHT),
		battle_view_node
	)
	post_game_delay = -1.0
	hovered_card = {}
	game_state = Constants.GameState.BATTLE
	var deck_ids: Array = []
	for card in selected_deck:
		if card is Dictionary and card.has("id"):
			deck_ids.append(card["id"])
	storage.save_last_deck(deck_ids)
	_refresh_ui()


func _init_game() -> void:
	game_state = Constants.GameState.MENU
	current_match = null
	_clear_battle_view()
	post_game_delay = -1.0
	hovered_card = {}
	deck_builder = DeckBuilder.new(card_pool)
	var last_ids: Array = storage.load_last_deck()
	if last_ids.size() == 8:
		var restored: Array = []
		for id in last_ids:
			var card = game_data.get_card_by_id(id)
			if not card.is_empty():
				restored.append(card)
		if restored.size() == 8:
			deck_builder.set_selected_deck(restored)
	_refresh_ui()


func _update_view_transform() -> void:
	var sx = size.x / _to_float(Constants.CANVAS_WIDTH, 1280.0)
	var sy = size.y / _to_float(Constants.CANVAS_HEIGHT, 720.0)
	view_scale = min(sx, sy)
	if view_scale <= 0.0:
		view_scale = 1.0
	var target = Vector2(Constants.CANVAS_WIDTH, Constants.CANVAS_HEIGHT) * view_scale
	view_offset = (size - target) * 0.5
	if virtual_root != null:
		virtual_root.position = view_offset
		virtual_root.scale = Vector2(view_scale, view_scale)
		virtual_root.size = Vector2(Constants.CANVAS_WIDTH, Constants.CANVAS_HEIGHT)


func _begin_virtual_draw() -> void:
	draw_set_transform(view_offset, 0.0, Vector2(view_scale, view_scale))


func _end_virtual_draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _is_inside_virtual(screen_pos: Vector2) -> bool:
	var local = screen_pos - view_offset
	var target = Vector2(Constants.CANVAS_WIDTH, Constants.CANVAS_HEIGHT) * view_scale
	return local.x >= 0.0 and local.y >= 0.0 and local.x <= target.x and local.y <= target.y


func _screen_to_virtual(screen_pos: Vector2) -> Vector2:
	return (screen_pos - view_offset) / view_scale


func _build_card_info_text(card: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Name: %s" % str(card.get("name", "")))
	lines.append("Elixir: %s" % str(card.get("elixir", "")))
	lines.append("Rarity: %s" % str(card.get("rarity", "")))
	lines.append("Type: %s" % str(card.get("type", "")))
	if _to_float(card.get("hp", 0.0)) > 0.0:
		lines.append("HP: %s" % str(_to_int(card.get("hp", 0.0))))
	if _to_float(card.get("dmg", 0.0)) > 0.0:
		lines.append("Damage: %s" % str(_to_int(card.get("dmg", 0.0))))
	var speed = str(card.get("speed", ""))
	if speed != "" and speed != "n/a":
		lines.append("Speed: %s" % speed)
	var ar = _to_float(card.get("attackRange", 0.0))
	if ar > 0.0:
		lines.append("Range: %.1f tiles" % (ar / Constants.TILE_SIZE))
	var target = str(card.get("targetType", ""))
	if target != "" and target != "n/a":
		lines.append("Target: %s" % target)
	var splash = _to_float(card.get("splashRadius", 0.0))
	if splash > 0.0:
		lines.append("Splash: %.1f tiles" % (splash / Constants.TILE_SIZE))
	var special = str(card.get("special", ""))
	if special != "":
		lines.append("Special: %s" % special)

	var desc = str(card.get("description", ""))
	if desc != "":
		lines.append("")
		lines.append(desc)
	return "\n".join(lines)


func _refresh_ui() -> void:
	menu_layer.visible = game_state == Constants.GameState.MENU
	post_game_layer.visible = game_state == Constants.GameState.POST_GAME
	hud_layer.visible = true

	menu_version_label.text = "Version %s" % Constants.APP_VERSION
	fps_label.text = "FPS: %d" % floori(Engine.get_frames_per_second())
	sound_label.text = "Sound: %s (M)" % ("ON" if sound_enabled else "OFF")

	if hovered_card.is_empty():
		card_info_panel.visible = false
		card_info_label.text = ""
	else:
		card_info_panel.visible = true
		card_info_label.text = _build_card_info_text(hovered_card)

	if post_game_layer.visible:
		_refresh_post_game_labels()


func _refresh_post_game_labels() -> void:
	if current_match == null:
		post_title_label.text = "Game Over"
		post_title_label.modulate = Color.WHITE
		post_message_label.text = ""
		post_player_tower_label.text = ""
		post_ai_tower_label.text = ""
		post_player_cards_label.text = ""
		post_ai_cards_label.text = ""
		post_continue_label.text = "Click or press any key to return to menu"
		return

	var stats: Dictionary = current_match.get_post_game_stats()
	var winner: Variant = stats.get("winner", null)
	var title = "Game Over"
	var title_color = Color.WHITE
	if typeof(winner) == TYPE_STRING and winner == "TIE":
		title = "Draw"
		title_color = Color8(220, 220, 20)
	elif typeof(winner) == TYPE_INT and winner == 0:
		title = "Victory"
		title_color = Color8(50, 255, 80)
	elif typeof(winner) == TYPE_INT and winner == 1:
		title = "Defeat"
		title_color = Color8(255, 90, 90)

	post_title_label.text = title
	post_title_label.modulate = title_color
	post_message_label.text = str(stats.get("message", ""))
	post_player_tower_label.text = "Player Tower HP: %s" % str(_to_int(stats.get("player_tower_hp", 0.0)))
	post_ai_tower_label.text = "AI Tower HP: %s" % str(_to_int(stats.get("ai_tower_hp", 0.0)))
	post_player_cards_label.text = "Player Cards Played: %s" % str(_to_int(stats.get("cards_played_player", 0)))
	post_ai_cards_label.text = "AI Cards Played: %s" % str(_to_int(stats.get("cards_played_ai", 0)))
	post_continue_label.text = "Click or press any key to return to menu"


func _on_menu_start_pressed() -> void:
	if game_state != Constants.GameState.MENU:
		return
	game_state = Constants.GameState.DECK_BUILDER
	hovered_card = {}
	_refresh_ui()


func _ensure_battle_view() -> void:
	if battle_view_node != null and is_instance_valid(battle_view_node):
		return
	var instance = BattleViewScene.instantiate()
	if instance is Node2D:
		battle_view_node = instance
		virtual_root.add_child(battle_view_node)
		virtual_root.move_child(battle_view_node, 0)


func _clear_battle_view() -> void:
	if battle_view_node == null:
		return
	if is_instance_valid(battle_view_node):
		battle_view_node.queue_free()
	battle_view_node = null


func _to_float(value: Variant, default_value: float = 0.0) -> float:
	match typeof(value):
		TYPE_FLOAT:
			return value
		TYPE_INT:
			return value * 1.0
		TYPE_STRING:
			var t = str(value).strip_edges()
			if t == "":
				return default_value
			if t.is_valid_int() or t.is_valid_float():
				return t.to_float()
			return default_value
		_:
			return default_value


func _to_int(value: Variant, default_value: int = 0) -> int:
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			return roundi(value)
		TYPE_STRING:
			var t = str(value).strip_edges()
			if t == "":
				return default_value
			if t.is_valid_int():
				return t.to_int()
			if t.is_valid_float():
				return roundi(t.to_float())
			return default_value
		_:
			return default_value
