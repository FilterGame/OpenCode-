extends Control

const Entities = preload("res://scripts/battle/entities.gd")
const HandCardScene = preload("res://scenes/ui/HandCard.tscn")

@onready var hand_root: Control = $HandRoot
@onready var elixir_fill: ColorRect = $ElixirBar/BarBg/BarFill
@onready var elixir_value: Label = $ElixirBar/ElixirValue
@onready var next_card_name: Label = $NextCardPanel/NextName
@onready var next_card_cost: Label = $NextCardPanel/NextCost

var _card_nodes: Dictionary = {}
var _previous_keys: Array[String] = []
var _mouse_virtual := Vector2.ZERO
var _selected_center := Vector2.ZERO
var _has_selected := false


func sync_from_match(match: Variant, mouse_virtual: Vector2) -> void:
	_mouse_virtual = mouse_virtual
	_has_selected = false
	if match == null:
		_clear_hand_nodes()
		queue_redraw()
		return
	if not (match.players is Array) or match.players.is_empty():
		_clear_hand_nodes()
		queue_redraw()
		return
	var human = match.players[0]
	_sync_elixir(human)
	_sync_next_card(human)
	_sync_hand(match, human)
	queue_redraw()


func _sync_elixir(player: Variant) -> void:
	var max_elixir = 10.0
	var value = clampf(Entities.as_float(player.elixir, 0.0), 0.0, max_elixir)
	var pct = clampf(value / max_elixir, 0.0, 1.0)
	elixir_fill.size.x = 360.0 * pct
	elixir_value.text = "Elixir  %d / %d" % [floori(value), floori(max_elixir)]


func _sync_next_card(player: Variant) -> void:
	if player.next_card.is_empty():
		next_card_name.text = "-"
		next_card_cost.text = "-"
		return
	next_card_name.text = str(player.next_card.get("name", ""))
	next_card_cost.text = str(player.next_card.get("elixir", ""))


func _sync_hand(match: Variant, player: Variant) -> void:
	var current_keys: Array[String] = []
	for i in player.hand.size():
		var card: Dictionary = player.hand[i]
		var key = _card_key(card)
		current_keys.append(key)
		var node: Control = _card_nodes.get(key)
		var is_new = node == null
		if is_new:
			node = HandCardScene.instantiate()
			hand_root.add_child(node)
			_card_nodes[key] = node
			node.size = node.custom_minimum_size
		var cost = match.get_card_elixir(card, player)
		var affordable = Entities.as_float(player.elixir, 0.0) >= cost * 1.0
		var selected = _is_selected(player, card)
		var hovered = _is_hovered(player, card)
		node.call("setup_card", card, cost, affordable, selected, hovered)
		var pose = player.get_hand_card_pose(i)
		var center: Vector2 = pose.get("center", Vector2.ZERO)
		var rotation_deg = Entities.as_float(pose.get("rotation_deg", 0.0), 0.0)
		var target_pos = center - node.size * 0.5
		var target_scale = (Vector2(1.08, 1.08) if selected else Vector2.ONE)
		node.z_index = i + (100 if selected else 0)
		if is_new or not _previous_keys.has(key):
			_play_entry_tween(node, target_pos, rotation_deg, target_scale)
		else:
			node.position = node.position.lerp(target_pos, 0.30)
			node.rotation_degrees = lerpf(node.rotation_degrees, rotation_deg, 0.30)
			node.scale = node.scale.lerp(target_scale, 0.30)
		if selected:
			_has_selected = true
			_selected_center = center + Vector2(0.0, -node.size.y * 0.42)

	for key in _card_nodes.keys():
		if not current_keys.has(key):
			var old_node: Node = _card_nodes[key]
			if old_node != null and is_instance_valid(old_node):
				old_node.queue_free()
			_card_nodes.erase(key)
	_previous_keys = current_keys.duplicate()


func _play_entry_tween(node: Control, target_pos: Vector2, target_rot: float, target_scale: Vector2) -> void:
	node.position = target_pos + Vector2(130.0, 85.0)
	node.rotation_degrees = target_rot + 12.0
	node.scale = Vector2(0.72, 0.72)
	node.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(node, "position", target_pos, 0.26)
	tween.parallel().tween_property(node, "rotation_degrees", target_rot, 0.26)
	tween.parallel().tween_property(node, "scale", target_scale, 0.26)
	tween.parallel().tween_property(node, "modulate", Color.WHITE, 0.24)


func _is_selected(player: Variant, card: Dictionary) -> bool:
	if player.selected_card_to_play.is_empty():
		return false
	var selected_id = Entities.as_int(player.selected_card_to_play.get("id", -1), -1)
	var card_id = Entities.as_int(card.get("id", -2), -2)
	return selected_id >= 0 and selected_id == card_id


func _is_hovered(player: Variant, card: Dictionary) -> bool:
	if player.hovered_card.is_empty():
		return false
	var hovered_id = Entities.as_int(player.hovered_card.get("id", -1), -1)
	var card_id = Entities.as_int(card.get("id", -2), -2)
	return hovered_id >= 0 and hovered_id == card_id


func _card_key(card: Dictionary) -> String:
	return "%s_%s" % [str(card.get("id", "")), str(card.get("name", ""))]


func _clear_hand_nodes() -> void:
	for key in _card_nodes.keys():
		var node: Node = _card_nodes[key]
		if node != null and is_instance_valid(node):
			node.queue_free()
	_card_nodes.clear()
	_previous_keys.clear()
	_has_selected = false


func _draw() -> void:
	if not _has_selected:
		return
	var start = _selected_center
	var end = _mouse_virtual
	var dist = start.distance_to(end)
	if dist < 12.0:
		return
	var dir = (end - start).normalized()
	var ortho = Vector2(-dir.y, dir.x)
	draw_line(start, end, Color(1.0, 0.95, 0.42, 0.92), 4.0, true)
	var tip = end
	var back = end - dir * 22.0
	var points = PackedVector2Array([tip, back + ortho * 10.0, back - ortho * 10.0])
	draw_colored_polygon(points, Color(1.0, 0.95, 0.42, 0.95))
