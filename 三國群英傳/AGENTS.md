# Repository Guidelines

## Project Structure & Module Organization
- `project.godot`: Godot 4.6 project entry.
- `scenes/`: runtime scenes. Main entry is `scenes/main.tscn`; UI is `scenes/ui.tscn`; reusable prefabs are under `scenes/prefabs/`.
- `scripts/`: gameplay code split by responsibility:
  - `scripts/core/`: shared constants/camera/data models.
  - `scripts/sim/`: battle simulation entities and logic.
  - `scripts/game/`: scene orchestration (`battle_game.gd`, background rendering).
  - `scripts/ui/`: HUD/overlay/portrait UI behavior.
  - `scripts/visual/`: legacy/alternate visual scripts; avoid new work here unless refactoring.
- `docs/`: delivery and verification docs (`MIGRATION_CHECKLIST.md`, `DELIVERY_STATUS.md`).
- `.godot/`: editor cache; do not hand-edit.

## Build, Test, and Development Commands
- Run editor: `Godot_v4.6-stable_win64.exe --path .`
- Quick parse/run check: `Godot_v4.6-stable_win64_console.exe --headless --path . --quit`
- Smoke test a few seconds: `Godot_v4.6-stable_win64_console.exe --headless --path . --quit-after 300`
- Re-import assets if needed: open once in editor and let import complete.

## Coding Style & Naming Conventions
- Language: GDScript (Godot 4).
- Indentation: tabs (Godot default). Keep lines focused and functions small.
- File names: `snake_case.gd`; scene names: `snake_case.tscn`; classes: `PascalCase` via `class_name`.
- Constants: `UPPER_SNAKE_CASE`; signals/functions/variables: `snake_case`.
- Prefer deterministic text encoding; if CJK text shows mojibake, use Unicode escapes (`\uXXXX`).

## Testing Guidelines
- No formal unit-test suite currently; use headless checks plus manual gameplay QA.
- Validate against `docs/MIGRATION_CHECKLIST.md` (input, UI, AI, skills, camera, win/lose).
- For bug fixes, include a reproducible scenario and confirm both: parse check + in-game interaction.

## Commit & Pull Request Guidelines
- This workspace may not include full Git history; use Conventional Commit style by default:
  - `feat:`, `fix:`, `refactor:`, `docs:`.
- Keep commits scoped (one logical change per commit).
- PRs should include: purpose, key file paths changed, test commands run, and screenshots/GIFs for UI changes.
- Note any remaining checklist gaps explicitly.

## Configuration & Safety Tips
- Do not manually edit `.godot/*` cache files or `*.uid` unless necessary.
- Avoid introducing duplicate prefab names that differ only by case (e.g., `General.tscn` vs `general.tscn`).
