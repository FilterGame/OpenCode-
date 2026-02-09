class_name BattleCommands
extends RefCounted

static func apply_team_command(entities: Array, team: int, command: String) -> int:
	if not BattleConstants.is_valid_command(command):
		return 0
	var affected := 0
	for entity in entities:
		if entity == null:
			continue
		if entity.team != team:
			continue
		if entity.dead:
			continue
		entity.command = command
		affected += 1
	return affected
