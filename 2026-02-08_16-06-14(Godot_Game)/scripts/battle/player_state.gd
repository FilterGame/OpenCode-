class_name BattlePlayerState
extends RefCounted

const Entities = preload("res://scripts/battle/entities.gd")

const ELIXIR_MAX = 10.0
const ELIXIR_RATE_NORMAL = 1.0 / 2.8

const KING_TOWER_Y_OFFSET = 50.0
const PRINCESS_TOWER_Y_OFFSET = 60.0
const PRINCESS_TOWER_X_SPACING = 200.0

const DEFAULT_UI = {
	"card_width": 118.0,
	"card_height": 160.0,
	"hand_center_y_offset": 110.0,
	"hand_spacing": 98.0,
	"fan_spread": 168.0,
	"fan_curve": 26.0,
	"fan_angle_max": 14.0,
	"selected_lift": 58.0,
	"elixir_bar_width": 300.0,
	"elixir_bar_height": 30.0,
	"elixir_bar_bottom_offset": 40.0,
}

var id = 0
var is_human = false
var name = "Player"

var elixir = 5.0
var elixir_rate = ELIXIR_RATE_NORMAL

var deck: Array = []
var hand: Array = []
var next_card: Dictionary = {}
var towers: Array = []
var selected_card_to_play: Dictionary = {}
var hovered_card: Dictionary = {}

var arena_size = Vector2(1280.0, 720.0)
var ui = DEFAULT_UI.duplicate(true)

var _rng = RandomNumberGenerator.new()


func _init(player_id: int, deck_cards: Array, human: bool = false, arena_bounds: Vector2 = Vector2(1280.0, 720.0), ui_params: Dictionary = {}) -> void:
	id = player_id
	is_human = human
	name = ("Player" if is_human else "AI")
	arena_size = arena_bounds
	ui.merge(ui_params, true)
	_rng.randomize()
	deck = _shuffle_deck(deck_cards)
	fill_hand()
	towers = init_towers()


func _shuffle_deck(cards: Array) -> Array:
	var shuffled = cards.duplicate(true)
	for i in range(shuffled.size() - 1, 0, -1):
		var j = _rng.randi_range(0, i)
		var temp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = temp
	return shuffled


func init_towers() -> Array:
	var list: Array = []
	var king_y = (arena_size.y - KING_TOWER_Y_OFFSET) if is_human else KING_TOWER_Y_OFFSET
	var princess_y = (arena_size.y - PRINCESS_TOWER_Y_OFFSET) if is_human else PRINCESS_TOWER_Y_OFFSET
	list.append(Entities.create_tower(Vector2(arena_size.x * 0.5, king_y), is_human, 4000.0, 100.0, 7.0 * Entities.TILE_SIZE, true, "KingTower"))
	list.append(Entities.create_tower(Vector2(arena_size.x * 0.5 - PRINCESS_TOWER_X_SPACING, princess_y), is_human, 2000.0, 120.0, 7.5 * Entities.TILE_SIZE, false, "PrincessTowerL"))
	list.append(Entities.create_tower(Vector2(arena_size.x * 0.5 + PRINCESS_TOWER_X_SPACING, princess_y), is_human, 2000.0, 120.0, 7.5 * Entities.TILE_SIZE, false, "PrincessTowerR"))
	return list


func fill_hand() -> void:
	while hand.size() < 4 and deck.size() > 0:
		hand.append(deck.pop_front())
	next_card = (deck[0] if deck.size() > 0 else {})


func cycle_card(played_card: Dictionary) -> void:
	var played_id = Entities.as_int(played_card.get("id", -1), -1)
	for i in hand.size():
		if Entities.as_int(hand[i].get("id", -2), -2) == played_id:
			hand.remove_at(i)
			break
	deck.append(played_card)
	if deck.size() > 0:
		hand.append(deck.pop_front())
	next_card = (deck[0] if deck.size() > 0 else {})


func update(dt: float, elixir_rate_multiplier: float, match: Variant) -> void:
	if elixir < ELIXIR_MAX:
		elixir = min(ELIXIR_MAX, elixir + elixir_rate * elixir_rate_multiplier * dt)
	for tower in towers:
		tower.update(dt, match)
	if match != null and match.has_method("get_view"):
		var battle_view = match.get_view()
		if battle_view != null and is_instance_valid(battle_view):
			notify_tower_update(battle_view)


func get_hand_layout() -> Dictionary:
	var card_width = Entities.as_float(ui["card_width"], 80.0)
	var card_height = Entities.as_float(ui["card_height"], 100.0)
	var spacing = Entities.as_float(ui["hand_spacing"], 10.0)
	var center_y = arena_size.y - Entities.as_float(ui["hand_center_y_offset"], 120.0)
	var center_x = arena_size.x * 0.5
	var total_width = card_width + max(0, hand.size() - 1) * spacing
	var start_x = center_x - total_width * 0.5
	return {
		"card_width": card_width,
		"card_height": card_height,
		"spacing": spacing,
		"center_x": center_x,
		"center_y": center_y,
		"start_x": start_x,
		"fan_spread": Entities.as_float(ui["fan_spread"], 168.0),
		"fan_curve": Entities.as_float(ui["fan_curve"], 26.0),
		"fan_angle_max": Entities.as_float(ui["fan_angle_max"], 14.0),
		"selected_lift": Entities.as_float(ui["selected_lift"], 58.0),
	}


func get_hand_card_pose(index: int) -> Dictionary:
	var layout = get_hand_layout()
	var center_x = Entities.as_float(layout.get("center_x", arena_size.x * 0.5), arena_size.x * 0.5)
	var center_y = Entities.as_float(layout.get("center_y", arena_size.y - 120.0), arena_size.y - 120.0)
	var fan_spread = Entities.as_float(layout.get("fan_spread", 168.0), 168.0)
	var fan_curve = Entities.as_float(layout.get("fan_curve", 26.0), 26.0)
	var fan_angle_max = Entities.as_float(layout.get("fan_angle_max", 14.0), 14.0)
	var selected_lift = Entities.as_float(layout.get("selected_lift", 58.0), 58.0)

	var count = hand.size()
	var t = 0.0
	if count > 1:
		var half = (count - 1) * 0.5
		t = (index - half) / max(half, 0.001)
	var center = Vector2(
		center_x + t * fan_spread,
		center_y + absf(t) * fan_curve
	)
	var rotation_deg = t * fan_angle_max

	if not selected_card_to_play.is_empty():
		var selected_id = Entities.as_int(selected_card_to_play.get("id", -1), -1)
		if index >= 0 and index < hand.size():
			var card_id = Entities.as_int(hand[index].get("id", -1), -1)
			if selected_id >= 0 and selected_id == card_id:
				center.y -= selected_lift

	return {
		"center": center,
		"rotation_deg": rotation_deg,
	}


func get_clicked_card_index(pos: Vector2) -> int:
	if not is_human:
		return -1
	var layout = get_hand_layout()
	var card_width = Entities.as_float(layout.get("card_width", 118.0), 118.0)
	var card_height = Entities.as_float(layout.get("card_height", 160.0), 160.0)
	var local_rect = Rect2(Vector2(-card_width * 0.5, -card_height * 0.5), Vector2(card_width, card_height))
	for i in range(hand.size() - 1, -1, -1):
		var pose = get_hand_card_pose(i)
		var center: Vector2 = pose.get("center", Vector2.ZERO)
		var rotation_deg = Entities.as_float(pose.get("rotation_deg", 0.0), 0.0)
		var local = Transform2D(deg_to_rad(rotation_deg), center).affine_inverse() * pos
		if local_rect.has_point(local):
			return i
	return -1


func handle_hand_hover(pos: Vector2) -> Dictionary:
	hovered_card = {}
	if not is_human:
		return hovered_card
	var index = get_clicked_card_index(pos)
	if index >= 0 and index < hand.size():
		hovered_card = hand[index]
	return hovered_card


func get_ui_parameters() -> Dictionary:
	return ui.duplicate(true)


func draw(canvas: CanvasItem, match: Variant, draw_world: bool = true, draw_ui: bool = true) -> void:
	if draw_world:
		for tower in towers:
			tower.draw(canvas)
	if not is_human or not draw_ui:
		return
	_draw_elixir_bar(canvas)
	_draw_hand(canvas, match)
	_draw_next_card(canvas)


func notify_tower_spawn(view: Variant) -> void:
	if view == null:
		return
	for tower in towers:
		if tower.is_destroyed or tower.hp <= 0.0:
			if view.has_method("on_tower_removed"):
				view.on_tower_removed(id, tower)
			continue
		if view.has_method("on_tower_spawned"):
			view.on_tower_spawned(id, tower)


func notify_tower_update(view: Variant) -> void:
	if view == null:
		return
	for tower in towers:
		if tower.is_destroyed or tower.hp <= 0.0:
			if view.has_method("on_tower_removed"):
				view.on_tower_removed(id, tower)
			continue
		if view.has_method("on_tower_updated"):
			view.on_tower_updated(id, tower)


func _draw_elixir_bar(canvas: CanvasItem) -> void:
	var width = Entities.as_float(ui["elixir_bar_width"], 300.0)
	var height = Entities.as_float(ui["elixir_bar_height"], 30.0)
	var center = Vector2(arena_size.x * 0.5, arena_size.y - Entities.as_float(ui["elixir_bar_bottom_offset"], 40.0))
	var bar_rect = Rect2(center - Vector2(width * 0.5, height * 0.5), Vector2(width, height))
	canvas.draw_rect(bar_rect, Color(0.58, 0.2, 0.78, 0.55), true)
	var fill_width = width * clampf(elixir / ELIXIR_MAX, 0.0, 1.0)
	canvas.draw_rect(Rect2(bar_rect.position, Vector2(fill_width, height)), Color(0.86, 0.45, 1.0, 0.95), true)
	_draw_text(canvas, center + Vector2(-6.0, 7.0), str(floori(elixir)), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_hand(canvas: CanvasItem, match: Variant) -> void:
	var layout = get_hand_layout()
	var card_width = Entities.as_float(layout["card_width"], 80.0)
	var card_height = Entities.as_float(layout["card_height"], 100.0)
	var start_x = Entities.as_float(layout["start_x"], 0.0)
	var center_y = Entities.as_float(layout["center_y"], 0.0)
	var spacing = Entities.as_float(layout["spacing"], 10.0)
	for i in hand.size():
		var card: Dictionary = hand[i]
		var card_center = Vector2(start_x + i * (card_width + spacing) + card_width * 0.5, center_y)
		var rect = Rect2(card_center - Vector2(card_width * 0.5, card_height * 0.5), Vector2(card_width, card_height))
		var cost = match.get_card_elixir(card, self)
		var affordable = elixir >= cost
		var border = Color(0.4, 0.4, 0.4, 0.9)
		if not selected_card_to_play.is_empty() and Entities.as_int(selected_card_to_play.get("id", -1), -1) == Entities.as_int(card.get("id", -2), -2):
			border = Color(1.0, 0.95, 0.2, 1.0)
		elif affordable:
			border = Color(0.25, 1.0, 0.35, 0.95)
		canvas.draw_rect(rect.grow(2.0), border, true)
		canvas.draw_rect(rect, _rarity_color(str(card.get("rarity", "common")), affordable), true)
		_draw_text(canvas, card_center + Vector2(0.0, -card_height * 0.28), str(card.get("name", "Card")), 11, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, card_width - 4.0)
		_draw_text(canvas, card_center + Vector2(0.0, card_height * 0.34), str(cost), 18, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_text(canvas, card_center + Vector2(0.0, card_height * 0.15), str(card.get("type", "")), 10, Color(0.07, 0.07, 0.07, 0.9), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_next_card(canvas: CanvasItem) -> void:
	if next_card.is_empty():
		return
	var layout = get_hand_layout()
	var card_width = Entities.as_float(layout["card_width"], 80.0) * 0.8
	var card_height = Entities.as_float(layout["card_height"], 100.0) * 0.8
	var total_hand_width = hand.size() * Entities.as_float(layout["card_width"], 80.0) + max(0, hand.size() - 1) * Entities.as_float(layout["spacing"], 10.0)
	var x = Entities.as_float(layout["start_x"], 0.0) + total_hand_width + Entities.as_float(layout["spacing"], 10.0) + card_width * 0.5 + 20.0
	var y = Entities.as_float(layout["center_y"], 0.0)
	var rect = Rect2(Vector2(x, y) - Vector2(card_width * 0.5, card_height * 0.5), Vector2(card_width, card_height))
	canvas.draw_rect(rect, _rarity_color(str(next_card.get("rarity", "common")), false), true)
	_draw_text(canvas, Vector2(x, y - card_height * 0.56), "Next", 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_text(canvas, Vector2(x, y - card_height * 0.18), str(next_card.get("name", "")), 10, Color(0.12, 0.12, 0.12, 1.0), HORIZONTAL_ALIGNMENT_CENTER, card_width - 4.0)
	_draw_text(canvas, Vector2(x, y + card_height * 0.35), str(next_card.get("elixir", "")), 14, Color(0.12, 0.12, 0.12, 1.0), HORIZONTAL_ALIGNMENT_CENTER)


func _rarity_color(rarity: String, affordable: bool) -> Color:
	var alpha = (1.0 if affordable else 0.45)
	match rarity:
		"common":
			return Color(0.82, 0.82, 0.82, alpha)
		"rare":
			return Color(1.0, 0.68, 0.18, alpha)
		"epic":
			return Color(0.73, 0.25, 0.95, alpha)
		"legendary":
			return Color(0.15, 0.95, 0.95, alpha)
		_:
			return Color(0.65, 0.65, 0.65, alpha)


func _draw_text(canvas: CanvasItem, pos: Vector2, text: String, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, max_width: float = -1.0) -> void:
	var font = canvas.get_theme_default_font()
	if font == null:
		return
	canvas.draw_string(font, pos, text, align, max_width, font_size, color)
