# Godot 4.6 Port Notes

## Run
1. Open this folder in Godot 4.6.
2. Run `scenes/Main.tscn` (already set as main scene in `project.godot`).

## Controls
- `Mouse Left`: menu/deck/battle interactions.
- `Mouse Wheel`: scroll card pool in deck builder.
- `ESC`: return to menu from deck/battle/post-game.
- `M`: toggle sound flag.

## Data
- `data/cards.csv`: card definitions.
- `data/unit_templates.csv`: spawned unit templates.
- `data/config.csv`: speed map and tower HP config.

## Code Split
- `scripts/main.gd`: app state machine and high-level flow.
- `scripts/core/*.gd`: constants/data loading/persistence.
- `scripts/ui/deck_builder.gd`: deck builder UI + interactions.
- `scripts/battle/*.gd`: battle loop, players, entities, AI.

## Completion Tracking
- Use `docs/CHECKLIST.md` at the end of every work cycle.
