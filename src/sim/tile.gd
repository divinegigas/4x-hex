## One hex of the world map. Holds state only; stats are derived on demand
## from terrain data plus the current season, so a season flip needs no
## per-tile rewrite.
extends RefCounted

const YIELD_KEYS := ["food", "wood", "stone", "gold"]

var coord: Vector2i
var terrain: String
## Faction id; -1 means unclaimed.
var owner_id: int = -1
## Id of the city this tile belongs to and yields for; -1 when none.
var city_id: int = -1
## "", "city", "district", "farm", "mine", "camp" or "road" (from build step 2 on).
var improvement: String = ""
## Savage lair: savages spawn here (build step 9).
var savage_spawn: bool = false
## Seasons of reduced yield left after pillaging or ravaging.
var ravaged_seasons: int = 0


func _init(c: Vector2i = Vector2i.ZERO, terrain_id: String = "") -> void:
	coord = c
	terrain = terrain_id


func is_ravaged() -> bool:
	return ravaged_seasons > 0


## Called once per season flip.
func tick_season() -> void:
	if ravaged_seasons > 0:
		ravaged_seasons -= 1


## Effective stat block for `season_id`:
## terrain base -> terrain season override -> global season multipliers -> ravaged.
## Returns {passable, move_cost, food, wood, stone, gold}.
func stats(data, season_id: String) -> Dictionary:
	var t: Dictionary = data.terrain(terrain)
	var base: Dictionary = t.get("base", {})
	var out: Dictionary = base.duplicate(true)
	var all_overrides: Dictionary = t.get("season_overrides", {})
	var overrides: Dictionary = all_overrides.get(season_id, {})
	for k in overrides:
		out[k] = overrides[k]

	for k in YIELD_KEYS:
		out[k] = float(out.get(k, 0.0))
	out["passable"] = bool(out.get("passable", true))

	var move_mult: float = data.season_value(season_id, "movement_cost", 1.0)
	out["move_cost"] = float(out.get("move_cost", 1.0)) * move_mult
	# Until farms exist (build step 2), the doc's "farm output" row scales raw land food.
	var food_mult: float = data.season_value(season_id, "farm_output", 1.0)
	out["food"] = float(out["food"]) * food_mult

	if is_ravaged():
		var ravaged_mult: float = float(data.setup.get("ravaged_yield_multiplier", 0.5))
		for k in YIELD_KEYS:
			out[k] = float(out[k]) * ravaged_mult
	return out
