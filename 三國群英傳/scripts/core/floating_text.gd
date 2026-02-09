class_name SimFloatingText
extends RefCounted

var id: int = -1
var x: float = 0.0
var y: float = 0.0
var text: String = ""
var color: Color = Color.WHITE
var life: float = 60.0
var rise_speed: float = 1.0

func _init(
	text_id: int,
	start_x: float,
	start_y: float,
	content: String,
	tint: Color = Color.WHITE,
	initial_life: float = 60.0
) -> void:
	id = text_id
	x = start_x
	y = start_y
	text = content
	color = tint
	life = initial_life

func update(frame_units: float) -> void:
	life -= frame_units
	y -= rise_speed * frame_units

func is_alive() -> bool:
	return life > 0.0

func to_snapshot() -> Dictionary:
	return {
		"id": id,
		"x": x,
		"y": y,
		"text": text,
		"color": color.to_html(),
		"life": life
	}
