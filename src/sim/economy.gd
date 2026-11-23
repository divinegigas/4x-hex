## City economy (design doc section 7), as pure functions.
## `project` computes a full, explainable report without changing anything, so
## the UI can always show the math; `apply` commits a report.
##
##   Food_next = clamp(Food_now + Production - Consumption, 0, Cap)
##
## Production: every tile the city claims (season-adjusted terrain yields) plus the
## city-centre bonus (food part also scaled by the season's farm output).
## Consumption: population x food_per_pop (rations and armies join in steps 3 and 6).
## Starvation: when the stock would go below zero, food is 0 and population shrinks.
extends RefCounted

const YIELD_KEYS := ["food", "wood", "stone", "gold"]


static func project(data, map, city, season_id: String) -> Dictionary:
	var production := {"food": 0.0, "wood": 0.0, "stone": 0.0, "gold": 0.0}
	var tiles_worked := 0
	for c in map.tiles:
		var tile = map.tiles[c]
		if tile.city_id != city.id:
			continue
		var s: Dictionary = tile.stats(data, season_id)
		for k in YIELD_KEYS:
			production[k] = float(production[k]) + float(s[k])
		tiles_worked += 1

	var bonus: Dictionary = data.economy.get("city_centre_bonus", {})
	var food_mult: float = data.season_value(season_id, "farm_output", 1.0)
	for k in YIELD_KEYS:
		var b := float(bonus.get(k, 0.0))
		if k == "food":
			b *= food_mult
		production[k] = float(production[k]) + b

	var pop: float = city.population
	var eaten: float = pop * data.econ("food_per_pop", 1.0)
	var manpower: float = pop * data.econ("manpower_per_pop", 0.5)
	var cap: float = data.storage_cap("food")
	var produced: float = production["food"]
	var raw: float = city.food + produced - eaten
	var starving := raw < 0.0
	var food_after := clampf(raw, 0.0, cap)

	var pop_after := pop
	if starving:
		pop_after = pop * (1.0 - data.econ("starvation_shrink_rate", 0.1))
	elif produced > eaten:
		pop_after = pop * (1.0 + data.econ("growth_rate", 0.0))
	pop_after = maxf(pop_after, data.econ("min_population", 1.0))

	return {
		"season": season_id,
		"tiles_worked": tiles_worked,
		"production": production,
		"manpower_produced": manpower,
		"food_before": city.food,
		"food_eaten": eaten,
		"food_net": produced - eaten,
		"food_after": food_after,
		"food_cap": cap,
		"food_wasted": maxf(0.0, raw - cap),
		"food_shortfall": maxf(0.0, -raw),
		"starving": starving,
		"population_before": pop,
		"population_after": pop_after,
	}


static func apply(report: Dictionary, city, faction) -> void:
	city.food = float(report["food_after"])
	city.population = float(report["population_after"])
	city.manpower += float(report["manpower_produced"])
	city.starving = bool(report["starving"])
	city.last_report = report
	var production: Dictionary = report["production"]
	if faction != null:
		for k in ["wood", "stone", "gold"]:
			faction.treasury[k] = float(faction.treasury.get(k, 0.0)) + float(production[k])
