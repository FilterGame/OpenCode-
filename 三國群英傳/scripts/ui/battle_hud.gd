class_name BattleHUD
extends Control

signal command_button_pressed

@onready var _command_button: Button = $CommandButton

@onready var _player_name: Label = $BottomContainer/LeftPanel/Margin/HBox/Stats/PlayerName
@onready var _player_hp_bar: ProgressBar = $BottomContainer/LeftPanel/Margin/HBox/Stats/PlayerHPBar
@onready var _player_hp_text: Label = $BottomContainer/LeftPanel/Margin/HBox/Stats/PlayerHPText
@onready var _player_mp_bar: ProgressBar = $BottomContainer/LeftPanel/Margin/HBox/Stats/PlayerMPBar
@onready var _player_mp_text: Label = $BottomContainer/LeftPanel/Margin/HBox/Stats/PlayerMPText
@onready var _player_troops: Label = $BottomContainer/LeftPanel/Margin/HBox/Stats/PlayerTroops

@onready var _enemy_name: Label = $BottomContainer/RightPanel/Margin/HBox/Stats/EnemyName
@onready var _enemy_hp_bar: ProgressBar = $BottomContainer/RightPanel/Margin/HBox/Stats/EnemyHPBar
@onready var _enemy_hp_text: Label = $BottomContainer/RightPanel/Margin/HBox/Stats/EnemyHPText
@onready var _enemy_mp_bar: ProgressBar = $BottomContainer/RightPanel/Margin/HBox/Stats/EnemyMPBar
@onready var _enemy_mp_text: Label = $BottomContainer/RightPanel/Margin/HBox/Stats/EnemyMPText
@onready var _enemy_troops: Label = $BottomContainer/RightPanel/Margin/HBox/Stats/EnemyTroops

@onready var _timer_value: Label = $BottomContainer/CenterPanel/CenterVBox/TimerValue


func _ready() -> void:
	_command_button.pressed.connect(_on_command_button_pressed)
	_command_button.text = "?頩???


func set_timer(seconds_left: int) -> void:
	_timer_value.text = str(maxi(seconds_left, 0))


func set_player_panel(name_text: String, hp: int, max_hp: int, mp: int, max_mp: int, troops: int) -> void:
	_player_name.text = name_text
	_set_bar(_player_hp_bar, hp, max_hp)
	_set_bar(_player_mp_bar, mp, max_mp)
	_player_hp_text.text = "HP %d / %d" % [maxi(hp, 0), maxi(max_hp, 1)]
	_player_mp_text.text = "MP %d / %d" % [maxi(mp, 0), maxi(max_mp, 1)]
	_player_troops.text = "??? %d" % maxi(troops, 0)


func set_enemy_panel(name_text: String, hp: int, max_hp: int, mp: int, max_mp: int, troops: int) -> void:
	_enemy_name.text = name_text
	_set_bar(_enemy_hp_bar, hp, max_hp)
	_set_bar(_enemy_mp_bar, mp, max_mp)
	_enemy_hp_text.text = "HP %d / %d" % [maxi(hp, 0), maxi(max_hp, 1)]
	_enemy_mp_text.text = "MP %d / %d" % [maxi(mp, 0), maxi(max_mp, 1)]
	_enemy_troops.text = "??? %d" % maxi(troops, 0)


func set_command_button_highlight(active: bool) -> void:
	_command_button.modulate = Color(1.0, 0.9, 0.45) if active else Color(1.0, 1.0, 1.0)


func _set_bar(bar: ProgressBar, value: int, max_value: int) -> void:
	var safe_max := maxf(float(max_value), 1.0)
	bar.max_value = safe_max
	bar.value = clampf(float(value), 0.0, safe_max)


func _on_command_button_pressed() -> void:
	command_button_pressed.emit()
