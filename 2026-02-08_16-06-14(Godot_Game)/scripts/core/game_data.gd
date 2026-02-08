extends RefCounted


const CARDS_PATH = "res://data/cards.csv"
const UNIT_TEMPLATES_PATH = "res://data/unit_templates.csv"
const CONFIG_PATH = "res://data/config.csv"

var _loaded = false

var _card_pool: Array[Dictionary] = []
var _cards_by_id: Dictionary = {}
var _unit_templates: Dictionary = {}
var _starting_hp: Dictionary = {}
var _speed_map: Dictionary = {}



func reload() -> void:
	_load_cards()
	_load_unit_templates()
	_load_config()
	_loaded = true


func get_card_pool() -> Array[Dictionary]:
	_ensure_loaded()
	return _card_pool.duplicate(true)


func get_unit_templates() -> Dictionary:
	_ensure_loaded()
	return _unit_templates.duplicate(true)


func get_starting_hp() -> Dictionary:
	_ensure_loaded()
	return _starting_hp.duplicate(true)


func get_speed_map() -> Dictionary:
	_ensure_loaded()
	return _speed_map.duplicate(true)


func get_card_by_id(id: Variant) -> Dictionary:
	_ensure_loaded()
	var card_id = _normalize_id(id)
	if _cards_by_id.has(card_id):
		return (_cards_by_id[card_id] as Dictionary).duplicate(true)
	return {}


func _ensure_loaded() -> void:
	if not _loaded:
		reload()


func _load_cards() -> void:
	_card_pool.clear()
	_cards_by_id.clear()

	var rows = _read_csv_rows(CARDS_PATH)
	for row in rows:
		var card: Dictionary = {}
		for key in row.keys():
			card[key] = _coerce_value(str(row[key]))

		var card_id = _normalize_id(card.get("id"))
		if card_id == null:
			continue

		card["id"] = card_id
		_card_pool.append(card)
		_cards_by_id[card_id] = card


func _load_unit_templates() -> void:
	_unit_templates.clear()

	var rows = _read_csv_rows(UNIT_TEMPLATES_PATH)
	for row in rows:
		var unit: Dictionary = {}
		for key in row.keys():
			unit[key] = _coerce_value(str(row[key]))

		var unit_id = str(unit.get("id", "")).strip_edges()
		if unit_id == "":
			continue

		var visual_value = unit.get("visual")
		if visual_value is String and str(visual_value).strip_edges() != "":
			var parsed_visual = JSON.parse_string(str(visual_value))
			if typeof(parsed_visual) == TYPE_DICTIONARY:
				unit["visual"] = parsed_visual

		_unit_templates[unit_id] = unit


func _load_config() -> void:
	_starting_hp.clear()
	_speed_map.clear()

	var rows = _read_csv_rows(CONFIG_PATH)
	for row in rows:
		var section = str(row.get("section", "")).strip_edges()
		var key = str(row.get("key", "")).strip_edges()
		var value = _coerce_value(str(row.get("value", "")))

		if section == "" or key == "":
			continue

		match section:
			"STARTING_HP":
				_starting_hp[key] = value
			"SPEED_MAP":
				_speed_map[key] = value


func _read_csv_rows(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Cannot open CSV: %s" % path)
		return rows

	if file.eof_reached():
		return rows

	var headers = file.get_csv_line()
	if headers.is_empty():
		return rows

	while not file.eof_reached():
		var values = file.get_csv_line()
		if values.is_empty():
			continue

		if values.size() == 1 and str(values[0]).strip_edges() == "":
			continue

		var row: Dictionary = {}
		for i in headers.size():
			var key = str(headers[i]).strip_edges()
			var value = ""
			if i < values.size():
				value = str(values[i])
			row[key] = value
		rows.append(row)

	return rows


func _coerce_value(raw: String) -> Variant:
	var text = raw.strip_edges()
	if text == "":
		return null
	if text.to_lower() == "true":
		return true
	if text.to_lower() == "false":
		return false
	if text.is_valid_int():
		return text.to_int()
	if text.is_valid_float():
		return text.to_float()
	return text


func _normalize_id(value: Variant) -> Variant:
	if value == null:
		return null
	if value is int:
		return value
	if value is float:
		return roundi(value)

	var text = str(value).strip_edges()
	if text.is_valid_int():
		return text.to_int()
	return null
