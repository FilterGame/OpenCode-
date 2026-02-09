class_name BattleCamera
extends RefCounted

const GameConfig = preload("res://scripts/core/game_config.gd")

var x: float = 0.0
var y: float = 0.0
var width: float = 1280.0
var height: float = 720.0
var target_x: float = 0.0
var is_dragging: bool = false
var last_mouse_x: float = 0.0

func setup(view_size: Vector2) -> void:
	width = view_size.x
	height = view_size.y

func clamp_to_world() -> void:
	x = clampf(x, 0.0, maxf(0.0, GameConfig.WORLD_WIDTH - width))

func drag_begin(mouse_x: float) -> void:
	is_dragging = true
	last_mouse_x = mouse_x

func drag_move(mouse_x: float) -> void:
	if not is_dragging:
		return
	var dx: float = mouse_x - last_mouse_x
	x -= dx
	last_mouse_x = mouse_x
	clamp_to_world()

func drag_end() -> void:
	is_dragging = false
