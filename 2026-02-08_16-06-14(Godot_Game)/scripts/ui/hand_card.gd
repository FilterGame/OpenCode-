extends Control

@onready var name_label: Label = $NameLabel
@onready var type_label: Label = $TypeLabel
@onready var cost_label: Label = $CostBadge/CostLabel

var _rarity := "common"
var _affordable := true
var _selected := false
var _hovered := false
var _card_name := ""
var _card_type := ""
var _card_cost := ""


func setup_card(card: Dictionary, cost: int, affordable: bool, selected: bool, hovered: bool) -> void:
	_rarity = str(card.get("rarity", "common"))
	_affordable = affordable
	_selected = selected
	_hovered = hovered
	_card_name = str(card.get("name", "Card"))
	_card_type = str(card.get("type", ""))
	_card_cost = str(cost)
	name_label.text = _card_name
	type_label.text = _card_type
	cost_label.text = _card_cost
	modulate = Color(1.0, 1.0, 1.0, 1.0 if _affordable else 0.62)
	queue_redraw()


func _draw() -> void:
	var card_rect = Rect2(Vector2.ZERO, size)
	var fill = _rarity_color(_rarity)
	var border = Color(0.18, 0.18, 0.2, 1.0)
	if _selected:
		border = Color(1.0, 0.95, 0.45, 1.0)
	elif _hovered:
		border = Color(0.92, 0.92, 0.98, 1.0)
	elif _affordable:
		border = Color(0.35, 1.0, 0.45, 1.0)

	draw_rect(card_rect.grow(3.0), border, true)
	draw_rect(card_rect, fill, true)
	draw_rect(card_rect.grow(-6.0), Color(1.0, 1.0, 1.0, 0.08), false, 1.0)

	if _selected:
		draw_rect(card_rect.grow(8.0), Color(1.0, 0.95, 0.35, 0.18), false, 2.0)


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"common":
			return Color(0.79, 0.79, 0.81, 1.0)
		"rare":
			return Color(0.99, 0.67, 0.2, 1.0)
		"epic":
			return Color(0.7, 0.33, 0.9, 1.0)
		"legendary":
			return Color(0.25, 0.92, 0.92, 1.0)
		_:
			return Color(0.68, 0.68, 0.72, 1.0)
