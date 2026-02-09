class_name GameConfig
extends RefCounted

const WORLD_WIDTH: float = 2000.0
const CAMERA_SPEED: float = 10.0
const TIMER_START: int = 99
const GROUND_UI_HEIGHT: float = 180.0
const TEAM_PLAYER: int = 1
const TEAM_ENEMY: int = 2

const CMD_CHARGE: String = "charge"
const CMD_HOLD: String = "hold"
const CMD_RETREAT: String = "retreat"

const COLOR_PLAYER: Color = Color("4488ff")
const COLOR_PLAYER_SKIN: Color = Color("ffccaa")
const COLOR_PLAYER_ARMOR: Color = Color("0044aa")
const COLOR_ENEMY: Color = Color("ff4444")
const COLOR_ENEMY_SKIN: Color = Color("ffccaa")
const COLOR_ENEMY_ARMOR: Color = Color("880000")
const COLOR_HP_BAR: Color = Color("00ff00")
const COLOR_BG_SKY: Color = Color("66aacc")
const COLOR_BG_GROUND: Color = Color("8b5a2b")
const COLOR_BG_GRASS: Color = Color("4a7023")

const SKILL_COST: float = 30.0
const SKILL_TEXT: String = "\u9752\u9f8d\u5043\u6708"
const START_TEXT: String = "\u6230\u9b25\u958b\u59cb"
const WIN_TEXT: String = "\u6230\u9b25\u52dd\u5229"
const LOSE_TEXT: String = "\u6230\u9b25\u5931\u6557"
const COMMAND_TEXT: Dictionary = {
	CMD_CHARGE: "\u8ecd\u4ee4: \u7a81\u64ca",
	CMD_HOLD: "\u8ecd\u4ee4: \u5f85\u547d",
	CMD_RETREAT: "\u8ecd\u4ee4: \u64a4\u9000"
}
