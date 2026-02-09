class_name BattleSkillSystem
extends RefCounted

const CRESCENT_NAME := "crescent"
const CRESCENT_MP_COST := 30.0
const CRESCENT_DAMAGE := 50
const CRESCENT_VERTICAL_RANGE := 100.0
const CRESCENT_WAVE_COUNT := 10
const CRESCENT_WAVE_INTERVAL_SEC := 0.05
const CRESCENT_DAMAGE_DELAY_SEC := 0.5

var _pending_events: Array = []

func reset() -> void:
	_pending_events.clear()

func cast_crescent(
	sim_time_sec: float,
	caster: SimGeneral,
	origin_x: float,
	origin_y: float,
	team: int
) -> Dictionary:
	if caster == null or caster.dead:
		return {"ok": false, "reason": "invalid_caster"}
	if caster.mp < CRESCENT_MP_COST:
		return {"ok": false, "reason": "insufficient_mp", "required": CRESCENT_MP_COST, "mp": caster.mp}

	caster.mp -= CRESCENT_MP_COST
	var direction := 1.0 if team == BattleConstants.TEAM_PLAYER else -1.0

	for i in range(CRESCENT_WAVE_COUNT):
		_pending_events.append({
			"time": sim_time_sec + float(i) * CRESCENT_WAVE_INTERVAL_SEC,
			"kind": "crescent_wave",
			"skill": CRESCENT_NAME,
			"team": team,
			"x": origin_x + direction * (50.0 + float(i) * 20.0),
			"y": origin_y
		})

	_pending_events.append({
		"time": sim_time_sec + CRESCENT_DAMAGE_DELAY_SEC,
		"kind": "crescent_damage",
		"skill": CRESCENT_NAME,
		"team": team,
		"origin_y": origin_y,
		"damage": CRESCENT_DAMAGE,
		"vertical_range": CRESCENT_VERTICAL_RANGE
	})

	return {"ok": true, "skill": CRESCENT_NAME, "mp_left": caster.mp}

func consume_due_events(sim_time_sec: float) -> Array:
	if _pending_events.is_empty():
		return []

	var due: Array = []
	var remain: Array = []
	for event_data in _pending_events:
		if event_data.get("time", INF) <= sim_time_sec:
			due.append(event_data)
		else:
			remain.append(event_data)
	_pending_events = remain
	return due
