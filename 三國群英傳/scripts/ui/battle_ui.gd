class_name BattleUI
extends Control

const GameConfig = preload("res://scripts/core/game_config.gd")

signal menu_toggled
signal command_selected(cmd: String)
signal skill_cast_requested

@onready var menu_btn: Button = %MenuBtn
@onready var timer_label: Label = %TimerValue
@onready var timer_title: Label = $BottomBar/Margin/HBox/CenterBox/TimerTitle
@onready var menu_title: Label = $CommandOverlay/Center/VBox/MenuTitle
@onready var left_name: Label = $BottomBar/Margin/HBox/LeftBox/Stats/Name
@onready var right_name: Label = $BottomBar/Margin/HBox/RightBox/Stats/Name

@onready var p1_hp_bar: ProgressBar = %P1HpBar
@onready var p1_hp_text: Label = %P1HpText
@onready var p1_mp_bar: ProgressBar = %P1MpBar
@onready var p1_troops: Label = %P1Troops

@onready var p2_hp_bar: ProgressBar = %P2HpBar
@onready var p2_hp_text: Label = %P2HpText
@onready var p2_troops: Label = %P2Troops

@onready var command_overlay: ColorRect = %CommandOverlay
@onready var command_center: CenterContainer = $CommandOverlay/Center
@onready var cutscene_overlay: ColorRect = %CutsceneOverlay
@onready var start_overlay: ColorRect = %StartOverlay
@onready var start_text: Label = %StartText
@onready var skill_text: Label = %SkillText

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_btn.pressed.connect(_on_menu_pressed)
	%CmdCharge.pressed.connect(func() -> void: emit_signal("command_selected", GameConfig.CMD_CHARGE))
	%CmdHold.pressed.connect(func() -> void: emit_signal("command_selected", GameConfig.CMD_HOLD))
	%CmdRetreat.pressed.connect(func() -> void: emit_signal("command_selected", GameConfig.CMD_RETREAT))
	%CmdSkill.pressed.connect(func() -> void: emit_signal("skill_cast_requested"))
	command_overlay.gui_input.connect(_on_command_overlay_input)
	command_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	start_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cutscene_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	menu_btn.text = "\u8ecd\u4ee4"
	timer_title.text = "\u5269\u9918\u6642\u9593"
	menu_title.text = "\u8ecd\u4ee4\u9078\u55ae"
	left_name.text = "\u5f35\u98db"
	right_name.text = "\u5442\u5e03"
	%CmdCharge.text = "\u7a81\u64ca"
	%CmdHold.text = "\u5f85\u547d"
	%CmdRetreat.text = "\u64a4\u9000"
	%CmdSkill.text = "\u6b66\u5c07\u6280"

	command_overlay.visible = false
	cutscene_overlay.visible = false
	start_overlay.visible = false
	start_overlay.modulate.a = 0.0
	skill_text.text = GameConfig.SKILL_TEXT

func _on_menu_pressed() -> void:
	emit_signal("menu_toggled")

func update_timer(value: int) -> void:
	timer_label.text = str(value)

func update_player_panel(hp: float, max_hp: float, mp: float, troops: int) -> void:
	p1_hp_bar.max_value = max_hp
	p1_hp_bar.value = maxf(0.0, hp)
	p1_hp_text.text = str(int(maxf(0.0, hp)))
	p1_mp_bar.max_value = 100.0
	p1_mp_bar.value = clampf(mp, 0.0, 100.0)
	p1_troops.text = "\u5175\u529b %d" % troops

func update_enemy_panel(hp: float, max_hp: float, troops: int) -> void:
	p2_hp_bar.max_value = max_hp
	p2_hp_bar.value = maxf(0.0, hp)
	p2_hp_text.text = str(int(maxf(0.0, hp)))
	p2_troops.text = "\u5175\u529b %d" % troops

func set_command_overlay(active: bool) -> void:
	command_overlay.visible = active

func set_cutscene(active: bool, text_value: String = "") -> void:
	cutscene_overlay.visible = active
	if text_value != "":
		skill_text.text = text_value

func show_start_text(text_value: String, alpha: float) -> void:
	start_text.text = text_value
	start_overlay.modulate.a = alpha
	if alpha <= 0.001:
		start_overlay.visible = false
	else:
		start_overlay.visible = true

func set_start_overlay_visible(visible_flag: bool) -> void:
	start_overlay.visible = visible_flag

func _on_command_overlay_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if command_center.get_global_rect().has_point(get_global_mouse_position()):
		return
	emit_signal("menu_toggled")
