# Dark Fantasy Hex 4X

Turn-based dark fantasy 4X for Android, built in Godot 4.3 (GDScript). Every round
is one season on a hex map; depth comes from food, logistics, stamina and morale.

The design lives in `docs/design.md` (a snapshot of the living Claude Docs design doc;
the live doc is the source of truth). Read the relevant section before building a system.

## Layout

```
data/        Tunable numbers (JSON). Balance changes go here, never in code.
src/sim/     Game rules. Pure RefCounted scripts: no Nodes, no UI, no input.
src/view/    Drawing and camera (Node2D / Camera2D). 2.5D isometric; settings in data/view.json.
src/ui/      HUD controls, built in code.
src/main.gd  Wires sim -> view/ui. Only place that knows about all three.
scenes/      main.tscn (just Main + script).
tests/       Headless tests for src/sim (and pure view math).
docs/        Design doc snapshot.
```

## Conventions

- **Simulation is separate from display.** `src/sim` must run headless (tests, AI-vs-AI,
  balance sims). It may use engine value types (Vector2i, FastNoiseLite, RNG) but never
  Nodes. The view listens to sim signals (e.g. `GameState.season_changed`).
- **Data-driven.** Races, units, tiers, districts, techs, seasonal multipliers and
  balance numbers belong in `data/*.json`. Every JSON file has a `_notes` key
  explaining its fields. `GameData` loads and validates them; add validation for new files.
- **No `class_name`.** Scripts reference each other with
  `const Foo = preload("res://...")`, which works in headless `--script` runs
  without an editor class cache. Use the preloaded const as a type hint.
- **Determinism.** Map generation and any randomness take an explicit seed. Sorts break
  ties by coordinate. Same seed => same game.
- **Hex coords** are axial `Vector2i(q, r)`, pointy-top. Rectangular maps are stored as
  odd-r offset rows. All hex math is in `src/sim/hex.gd`; pixel conversion is in
  `src/view/hex_layout.gd`.
- **Isometric view.** The grid is squashed vertically (`iso_y_scale`) and each tile is a
  block raised by its terrain `elevation`. `src/view/iso_map_geometry.gd` owns the shapes,
  back-to-front draw order and picking (front-most visible tile wins). Use its `centers`
  to place anything drawn on a tile, not `HexLayout.to_pixel`, which ignores elevation.
- **Typed GDScript.** Type variables and returns. Don't use `:=` on values from
  untyped variables (inference fails at parse time); write the type explicitly.
- **Mobile first.** Landscape, `canvas_items` stretch from 1280x720, touch input
  (mouse is emulated as touch on desktop). Buttons at least ~60 px tall.

## Commands

```sh
godot --headless --import                              # first run / after adding files
godot --headless --script res://tests/run_tests.gd     # run tests (exit 1 on failure)
godot --path .                                         # run the game
```

New test files go in `TEST_FILES` in `tests/run_tests.gd`; test methods start with `test_`.
CI (`.github/workflows/tests.yml`) runs the same tests on every push.

## Build order (design doc section 15)

1. [x] Hex map, tile data and season flipping
2. [x] One city: resources, food balance, storage cap
3. [ ] Pace, rations, stamina and morale for cities
4. [ ] City expansion: adjacent districts, farms, mines, camps
5. [ ] Units, engineers and movement
6. [ ] Supply network: radius, camps, roads overlay, connectivity check, starvation
7. [ ] Auto-resolved combat with the battle preview
8. [ ] Commanders, officers and XP
9. [ ] Savages and lair spawning
10. [ ] Mercenaries and the bounty purse
11. [ ] City states (mini-AI)
12. [ ] Rival player AI
13. [ ] Tech tree depth and victory conditions
14. [ ] Art, audio and polish
15. [ ] Additional races, then Grey Aliens

Step 2 notes: until farms/mines exist (step 4) every tile a city claims yields its raw
terrain stats. Food and manpower live in the city; wood, stone and gold in the faction
treasury. Economy math is in `src/sim/economy.gd` (`project` = report, `apply` = commit).

Commit after each step works. Hooks for later steps are marked in code
(e.g. `GameState._resolve_end_of_round`).
