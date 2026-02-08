# Port Checklist (p5.js -> Godot 4.6)

## Core State Flow
- [x] `MENU` screen exists and can enter deck builder.
- [x] `DECK_BUILDER` screen exists.
- [x] `BATTLE` screen exists.
- [x] `POST_GAME` screen exists.
- [x] `ESC` from deck/battle/post-game returns to menu.

## Deck Builder
- [x] Card pool rendered from CSV data.
- [x] Pool sorted by elixir.
- [x] Mouse wheel scroll works in pool area.
- [x] Click card to add to deck.
- [x] Duplicate cards are prevented.
- [x] Click selected slot to remove card.
- [x] Exactly 8 cards required to start.
- [x] Average elixir displayed.

## Battle Core
- [x] Player/AI towers initialized.
- [x] Elixir regeneration up to cap.
- [x] Hand selection and deploy preview.
- [x] Deploy validation by card type and side.
- [x] Unit movement and targeting.
- [x] Ranged attacks via projectile.
- [x] Melee and splash handling.
- [x] Building targeting/attacks.
- [x] AI periodic card play.
- [x] Match phases NORMAL/OVERTIME/TIEBREAKER.
- [x] Basic win conditions and post-game stats.

## Special Cards/Effects
- [x] `mirror_last_card`
- [x] `multi_target_3` (Lightning style)
- [x] `linear_pushback` (Log style)
- [x] `area_spawn_over_time` (Graveyard style)
- [x] `freeze`
- [x] `kamikaze`
- [x] `charge`
- [x] `ramping_damage`
- [x] `fast_attack_rate`
- [x] `deploy_anywhere_ground`

## Data Layer
- [x] `data/cards.csv`
- [x] `data/unit_templates.csv`
- [x] `data/config.csv`
- [x] Runtime CSV loader.
- [x] Last deck persistence (`user://save.cfg`).

## Validation Status
- [x] Static script integration completed.
- [x] Godot 4.6 headless project boot check passed.
- [x] Headless smoke test for `BattleMatch.update()` passed.
- [ ] Full in-editor gameplay parity playtest (manual) still required.

## Node/Prefab Migration
- [x] Main menu converted from `draw_*` to scene UI nodes.
- [x] Post-game overlay converted from `draw_*` to scene UI nodes.
- [x] HUD (FPS/Sound) converted from `draw_*` to scene UI nodes.
- [x] Hover card info converted from `draw_*` to scene UI nodes.
- [x] Battle object visual prefabs added (`unit/building/spell/projectile/particle`).
- [x] `BattleView` node manager added and wired to match lifecycle.
- [x] Tower visuals wired as node-based objects.
- [x] Fallback rendering path retained when no `BattleView` is attached.
- [x] Headless smoke test confirms battle view create/bind/clear flow.
- [ ] Deck builder hand/elixir UI still procedural (next phase if required).
