class_name OverlayUI
extends Control

signal menu_opened_changed(is_open: bool)
signal command_selected(command: StringName)
signal skill_requested

@onready var _dimmer: ColorRect = $Dimmer
@onready var _command_window: Panel = $CommandWindow
@onready var _charge_button: Button = $CommandWindow/Margin/VBox/CommandRow/ChargeButton
@onready var _hold_button: Button = $CommandWindow/Margin/VBox/CommandRow/HoldButton
@onready var _retreat_button: Button = $CommandWindow/Margin/VBox/CommandRow/RetreatButton
@onready var _skill_button: Button = $CommandWindow/Margin/VBox/SkillRow/SkillButton

@onready var _cutscene_overlay: ColorRect = $CutsceneOverlay
@onready var _skill_name: Label = $CutsceneOverlay/SkillName

@onready var _start_overlay: ColorRect = $StartOverlay
@onready var _start_label: Label = $StartOverlay/StartLabel

var _menu_open: bool = false
var _skill_tween: Tween
var _start_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dimmer.visible = false
	_command_window.visible = false
	_cutscene_overlay.visible = false
	_start_overlay.visible = false

	_dimmer.gui_input.connect(_on_dimmer_gui_input)
	_charge_button.pressed.connect(func() -> void: _select_command(&"charge"))
	_hold_button.pressed.connect(func() -> void: _select_command(&"hold"))
	_retreat_button.pressed.connect(func() -> void: _select_command(&"retreat"))
	_skill_button.pressed.connect(_on_skill_button_pressed)


func toggle_command_menu() -> void:
	set_command_menu_open(not _menu_open)


func is_menu_open() -> bool:
	return _menu_open


func set_command_menu_open(open: bool) -> void:
	if _menu_open == open:
		return
	_menu_open = open
	_dimmer.visible = open
	_command_window.visible = open
	menu_opened_changed.emit(open)


func show_skill_cutscene(skill_name_text: String, duration: float = 1.8) -> void:
	set_command_menu_open(false)
	if _skill_tween != null:
		_skill_tween.kill()

	_cutscene_overlay.visible = true
	_cutscene_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_skill_name.text = skill_name_text
	_skill_name.scale = Vector2(0.35, 0.35)
	_skill_name.modulate = Color(1.0, 0.94, 0.36, 0.0)

	_skill_tween = create_tween()
	_skill_tween.tween_property(_cutscene_overlay, "modulate:a", 1.0, 0.08)
	_skill_tween.parallel().tween_property(_skill_name, "modulate:a", 1.0, 0.12)
	_skill_tween.parallel().tween_property(_skill_name, "scale", Vector2(1.14, 1.14), 0.16)
	_skill_tween.tween_property(_skill_name, "scale", Vector2(1.0, 1.0), 0.12)
	_skill_tween.tween_interval(maxf(duration - 0.65, 0.0))
	_skill_tween.tween_property(_skill_name, "modulate:a", 0.0, 0.24)
	_skill_tween.parallel().tween_property(_cutscene_overlay, "modulate:a", 0.0, 0.24)
	_skill_tween.finished.connect(func() -> void: _cutscene_overlay.visible = false)


func show_start_text(start_text: String = "???????", duration: float = 2.0) -> void:
	if _start_tween != null:
		_start_tween.kill()
	_start_overlay.visible = true
	_start_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_start_label.text = start_text
	_start_label.scale = Vector2(0.92, 0.92)
	_start_label.modulate = Color(1.0, 0.36, 0.28, 0.0)

	_start_tween = create_tween()
	_start_tween.tween_property(_start_overlay, "modulate:a", 1.0, 0.18)
	_start_tween.parallel().tween_property(_start_label, "modulate:a", 1.0, 0.2)
	_start_tween.parallel().tween_property(_start_label, "scale", Vector2(1.05, 1.05), 0.22)
	_start_tween.tween_property(_start_label, "scale", Vector2(1.0, 1.0), 0.16)
	_start_tween.tween_interval(maxf(duration - 0.9, 0.0))
	_start_tween.tween_property(_start_label, "modulate:a", 0.0, 0.28)
	_start_tween.parallel().tween_property(_start_overlay, "modulate:a", 0.0, 0.3)
	_start_tween.finished.connect(func() -> void: _start_overlay.visible = false)


func _select_command(command: StringName) -> void:
	command_selected.emit(command)
	set_command_menu_open(false)


func _on_skill_button_pressed() -> void:
	skill_requested.emit()


func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_command_menu_open(false)
