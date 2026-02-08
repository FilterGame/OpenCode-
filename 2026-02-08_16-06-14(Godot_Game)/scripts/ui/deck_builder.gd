class_name DeckBuilder
extends RefCounted

const CANVAS_WIDTH = 1280.0
const CANVAS_HEIGHT = 720.0
const MAX_DECK_SIZE = 8

const CARD_DISPLAY_HEIGHT = 60.0
const CARD_DISPLAY_WIDTH = CANVAS_WIDTH / 2.0 - 80.0
const CARD_ITEM_PADDING = 5.0
const DECK_SLOT_SIZE = 80.0
const DECK_SLOT_PADDING = 10.0
const DECK_CARDS_PER_ROW = 4

const LIST_X = 0.0
const LIST_Y = 50.0
const LIST_WIDTH = CANVAS_WIDTH / 2.0 - 20.0
const LIST_HEIGHT = CANVAS_HEIGHT - 150.0

const DECK_X = CANVAS_WIDTH / 2.0 + 20.0
const DECK_Y = 50.0
const DECK_WIDTH = CANVAS_WIDTH / 2.0 - 40.0

const CONFIRM_CENTER = Vector2(CANVAS_WIDTH - 150.0, CANVAS_HEIGHT - 80.0)
const CONFIRM_SIZE = Vector2(200.0, 60.0)

const COLOR_BG = Color8(60, 70, 80)
const COLOR_PANEL = Color8(40, 48, 56)
const COLOR_PANEL_BORDER = Color8(120, 130, 140)
const COLOR_CARD = Color8(120, 120, 120)
const COLOR_CARD_SELECTED = Color8(80, 80, 80)
const COLOR_SLOT_EMPTY = Color8(80, 80, 90)
const COLOR_TEXT = Color8(230, 230, 230)
const COLOR_TEXT_DARK = Color8(20, 20, 20)
const COLOR_HOVER = Color8(255, 220, 120)
const COLOR_CONFIRM_OK = Color8(100, 200, 100)
const COLOR_CONFIRM_DISABLED = Color8(80, 120, 80)
const COLOR_CONFIRM_BLOCK = Color8(220, 50, 50, 140)

var _card_pool: Array = []
var _selected_deck: Array = []
var _scroll_offset = 0.0
var _hovered_card: Dictionary = {}
var _mouse_pos = Vector2.ZERO


func _init(card_pool: Array) -> void:
	_card_pool = card_pool.duplicate(true)
	_card_pool.sort_custom(func(a, b):
		var elixir_a: float = _elixir_sort_value(a)
		var elixir_b: float = _elixir_sort_value(b)
		if is_equal_approx(elixir_a, elixir_b):
			return str(a.get("name", "")) < str(b.get("name", ""))
		return elixir_a < elixir_b
	)
	reset()


func set_selected_deck(deck: Array) -> void:
	_selected_deck.clear()
	for card in deck:
		if _selected_deck.size() >= MAX_DECK_SIZE:
			break
		if _has_card(_selected_deck, card):
			continue
		_selected_deck.append(card)


func update(_dt: float) -> void:
	_clamp_scroll()


func draw(canvas: CanvasItem) -> void:
	if canvas == null:
		return

	var text_style = _resolve_text_style(canvas)
	var font: Font = text_style["font"]

	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(CANVAS_WIDTH, CANVAS_HEIGHT)), COLOR_BG, true)

	_draw_centered_text(canvas, font, 24, "Deck Builder", Rect2(0.0, 10.0, CANVAS_WIDTH, 32.0), COLOR_TEXT)
	_draw_card_pool_list(canvas, font)
	_draw_selected_deck(canvas, font)

	var avg_text = "Average Elixir: %.1f" % _get_average_elixir()
	_draw_right_text(canvas, font, 20, avg_text, DECK_X + DECK_WIDTH - 20.0, CANVAS_HEIGHT - 120.0, COLOR_TEXT)

	var confirm_rect = _confirm_rect()
	var can_start = _selected_deck.size() == MAX_DECK_SIZE
	canvas.draw_rect(confirm_rect, COLOR_CONFIRM_OK if can_start else COLOR_CONFIRM_DISABLED, true)
	canvas.draw_rect(confirm_rect, COLOR_PANEL_BORDER, false, 2.0)
	_draw_centered_text(canvas, font, 24, "Start Battle", confirm_rect, COLOR_TEXT_DARK)

	if not can_start:
		canvas.draw_rect(confirm_rect, COLOR_CONFIRM_BLOCK, true)
		_draw_centered_text(canvas, font, 16, "Need 8 cards", confirm_rect, Color.WHITE)


func handle_mouse_moved(mx: float, my: float) -> void:
	_mouse_pos = Vector2(mx, my)
	_hovered_card = {}

	for i in _card_pool.size():
		var card_rect = _pool_card_rect(i)
		if card_rect.has_point(_mouse_pos) and _is_pool_card_visible(card_rect):
			if _card_pool[i] is Dictionary:
				_hovered_card = _card_pool[i]
			return

	for i in min(_selected_deck.size(), MAX_DECK_SIZE):
		var slot_rect = _deck_slot_rect(i)
		if slot_rect.has_point(_mouse_pos):
			if _selected_deck[i] is Dictionary:
				_hovered_card = _selected_deck[i]
			return


func handle_mouse_pressed(mx: float, my: float) -> Dictionary:
	_mouse_pos = Vector2(mx, my)

	if _confirm_rect().has_point(_mouse_pos):
		return {
			"start_battle": _selected_deck.size() == MAX_DECK_SIZE,
			"selected_deck": get_selected_deck()
		}

	var list_rect = Rect2(LIST_X, LIST_Y, LIST_WIDTH, LIST_HEIGHT)
	if list_rect.has_point(_mouse_pos):
		var step = CARD_DISPLAY_HEIGHT + CARD_ITEM_PADDING
		var click_index = floori((my - LIST_Y + _scroll_offset) / step)
		if click_index >= 0 and click_index < _card_pool.size():
			_add_card_to_deck(_card_pool[click_index])
		return {
			"start_battle": false,
			"selected_deck": get_selected_deck()
		}

	for i in _selected_deck.size():
		var slot_rect = _deck_slot_rect(i)
		if slot_rect.has_point(_mouse_pos):
			_selected_deck.remove_at(i)
			return {
				"start_battle": false,
				"selected_deck": get_selected_deck()
			}

	return {
		"start_battle": false,
		"selected_deck": get_selected_deck()
	}


func handle_mouse_wheel(delta: float) -> void:
	var list_rect = Rect2(LIST_X, LIST_Y, LIST_WIDTH, LIST_HEIGHT)
	if not list_rect.has_point(_mouse_pos):
		return
	var scroll_delta = delta
	if abs(scroll_delta) <= 2.0:
		scroll_delta *= 36.0
	_scroll_offset += scroll_delta
	_clamp_scroll()
	handle_mouse_moved(_mouse_pos.x, _mouse_pos.y)


func get_hovered_card() -> Dictionary:
	return _hovered_card


func get_selected_deck() -> Array:
	return _selected_deck.duplicate(true)


func reset() -> void:
	_selected_deck.clear()
	_scroll_offset = 0.0
	_hovered_card = {}
	_mouse_pos = Vector2.ZERO


func _add_card_to_deck(card_data: Variant) -> void:
	if _selected_deck.size() >= MAX_DECK_SIZE:
		return
	if _has_card(_selected_deck, card_data):
		return
	_selected_deck.append(card_data)


func _has_card(deck: Array, card: Variant) -> bool:
	var target_id = _card_identity(card)
	for item in deck:
		if _card_identity(item) == target_id:
			return true
	return false


func _card_identity(card: Variant) -> Variant:
	if card is Dictionary and card.has("id"):
		return card["id"]
	return card


func _content_height() -> float:
	return _card_pool.size() * (CARD_DISPLAY_HEIGHT + CARD_ITEM_PADDING)


func _max_scroll() -> float:
	return max(0.0, _content_height() - LIST_HEIGHT)


func _clamp_scroll() -> void:
	_scroll_offset = clamp(_scroll_offset, 0.0, _max_scroll())


func _confirm_rect() -> Rect2:
	return Rect2(CONFIRM_CENTER - CONFIRM_SIZE * 0.5, CONFIRM_SIZE)


func _pool_card_rect(index: int) -> Rect2:
	var x = LIST_X + (LIST_WIDTH - CARD_DISPLAY_WIDTH) * 0.5
	var y = LIST_Y + index * (CARD_DISPLAY_HEIGHT + CARD_ITEM_PADDING) - _scroll_offset
	return Rect2(x, y, CARD_DISPLAY_WIDTH, CARD_DISPLAY_HEIGHT)


func _deck_slot_rect(index: int) -> Rect2:
	var row = floori(index / (DECK_CARDS_PER_ROW * 1.0))
	var col = index % DECK_CARDS_PER_ROW
	var slots_width = DECK_CARDS_PER_ROW * DECK_SLOT_SIZE + (DECK_CARDS_PER_ROW - 1) * DECK_SLOT_PADDING
	var start_x = DECK_X + (DECK_WIDTH - slots_width) * 0.5
	var x = start_x + col * (DECK_SLOT_SIZE + DECK_SLOT_PADDING)
	var y = DECK_Y + row * (DECK_SLOT_SIZE + DECK_SLOT_PADDING)
	return Rect2(x, y, DECK_SLOT_SIZE, DECK_SLOT_SIZE)


func _is_pool_card_visible(card_rect: Rect2) -> bool:
	return card_rect.position.y + card_rect.size.y >= LIST_Y and card_rect.position.y <= LIST_Y + LIST_HEIGHT


func _get_average_elixir() -> float:
	if _selected_deck.is_empty():
		return 0.0
	var total = 0.0
	for card in _selected_deck:
		total += _elixir_for_average(card)
	return total / _selected_deck.size()


func _elixir_for_average(card: Variant) -> float:
	if card is Dictionary and str(card.get("special", "")) == "mirror_last_card":
		return 3.0
	return _elixir_sort_value(card)


func _elixir_sort_value(card: Variant) -> float:
	if not (card is Dictionary):
		return 999.0
	var raw = card.get("elixir", 999)
	match typeof(raw):
		TYPE_INT, TYPE_FLOAT:
			return raw * 1.0
		TYPE_STRING:
			var text = str(raw).strip_edges()
			if text.is_valid_float():
				return text.to_float()
			if text.begins_with("+") and text.substr(1).is_valid_float():
				return text.substr(1).to_float()
			if text.length() > 1 and text.ends_with("+") and text.substr(0, text.length() - 1).is_valid_float():
				return text.substr(0, text.length() - 1).to_float()
	return 999.0


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"common":
			return Color8(190, 190, 190)
		"rare":
			return Color8(245, 170, 80)
		"epic":
			return Color8(190, 120, 235)
		"legendary":
			return Color8(130, 230, 230)
		_:
			return Color8(160, 160, 160)


func _draw_card_pool_list(canvas: CanvasItem, font: Font) -> void:
	var list_rect = Rect2(LIST_X, LIST_Y, LIST_WIDTH, LIST_HEIGHT)
	canvas.draw_rect(list_rect, COLOR_PANEL, true)
	canvas.draw_rect(list_rect, COLOR_PANEL_BORDER, false, 2.0)

	for i in _card_pool.size():
		var card = _card_pool[i]
		var card_rect = _pool_card_rect(i)
		if not _is_pool_card_visible(card_rect):
			continue

		var selected = _has_card(_selected_deck, card)
		canvas.draw_rect(card_rect, COLOR_CARD_SELECTED if selected else COLOR_CARD, true)
		canvas.draw_rect(card_rect, COLOR_PANEL_BORDER, false, 1.0)
		if not _hovered_card.is_empty() and _card_identity(_hovered_card) == _card_identity(card):
			canvas.draw_rect(card_rect.grow(1.0), COLOR_HOVER, false, 2.0)

		var name_text = "%s (%s)" % [str(card.get("name", "Unknown")), str(card.get("elixir", "?"))]
		var type_text = str(card.get("type", ""))
		_draw_left_text(canvas, font, 16, name_text, card_rect.position.x + 10.0, card_rect.position.y + 18.0, COLOR_TEXT, card_rect.size.x - 120.0)
		_draw_right_text(canvas, font, 12, type_text, card_rect.position.x + card_rect.size.x - 10.0, card_rect.position.y + 22.0, COLOR_TEXT)

	if _content_height() > LIST_HEIGHT:
		_draw_centered_text(canvas, font, 14, "Use mouse wheel to scroll", Rect2(LIST_X, LIST_Y + LIST_HEIGHT + 6.0, LIST_WIDTH, 24.0), Color8(180, 180, 180))


func _draw_selected_deck(canvas: CanvasItem, font: Font) -> void:
	_draw_centered_text(canvas, font, 20, "Selected Deck (8)", Rect2(DECK_X, DECK_Y - 34.0, DECK_WIDTH, 24.0), COLOR_TEXT)

	for i in MAX_DECK_SIZE:
		var slot_rect = _deck_slot_rect(i)
		var card = _selected_deck[i] if i < _selected_deck.size() else null

		if card == null:
			canvas.draw_rect(slot_rect, COLOR_SLOT_EMPTY, true)
			canvas.draw_rect(slot_rect, COLOR_PANEL_BORDER, false, 1.0)
			continue

		var rarity = str(card.get("rarity", ""))
		canvas.draw_rect(slot_rect, _rarity_color(rarity), true)
		canvas.draw_rect(slot_rect, COLOR_PANEL_BORDER, false, 1.0)
		if not _hovered_card.is_empty() and _card_identity(_hovered_card) == _card_identity(card):
			canvas.draw_rect(slot_rect.grow(1.0), COLOR_HOVER, false, 2.0)

		var card_name = str(card.get("name", "Unknown"))
		var elixir_text = str(card.get("elixir", "?"))
		_draw_centered_text(canvas, font, 12, card_name, Rect2(slot_rect.position.x + 4.0, slot_rect.position.y + 6.0, slot_rect.size.x - 8.0, 32.0), COLOR_TEXT_DARK)
		_draw_centered_text(canvas, font, 16, elixir_text, Rect2(slot_rect.position.x, slot_rect.position.y + 48.0, slot_rect.size.x, 20.0), COLOR_TEXT_DARK)


func _resolve_text_style(canvas: CanvasItem) -> Dictionary:
	var font: Font = null
	var size = ThemeDB.fallback_font_size
	if canvas is Control:
		var ctrl = canvas as Control
		font = ctrl.get_theme_default_font()
		size = ctrl.get_theme_default_font_size()
	if font == null:
		font = ThemeDB.fallback_font
	if size <= 0:
		size = 16
	return {"font": font, "size": size}


func _draw_left_text(canvas: CanvasItem, font: Font, size: int, text: String, x: float, y: float, color: Color, width: float = -1.0) -> void:
	if font == null:
		return
	var baseline = y + font.get_ascent(size)
	canvas.draw_string(font, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, width, size, color)


func _draw_right_text(canvas: CanvasItem, font: Font, size: int, text: String, x: float, y: float, color: Color) -> void:
	if font == null:
		return
	var baseline = y + font.get_ascent(size)
	canvas.draw_string(font, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_RIGHT, -1.0, size, color)


func _draw_centered_text(canvas: CanvasItem, font: Font, size: int, text: String, rect: Rect2, color: Color) -> void:
	if font == null:
		return
	var line_height = font.get_height(size)
	var y = rect.position.y + max(0.0, (rect.size.y - line_height) * 0.5)
	var baseline = y + font.get_ascent(size)
	canvas.draw_string(font, Vector2(rect.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)
