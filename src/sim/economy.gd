## City economy and condition (design doc sections 7 and 8), as pure functions.
## `project` computes a full, explainable report without changing anything, so
## the UI can always show the math; `apply` commits a report.
##
##   Output     = base yield x pace x morale/100            (all resources)
##   Manpower   = population x manpower_per_pop x pace x morale/100 x stamina/100
##   Food eaten = population x food_per_pop x rations
##   Food_next  = clamp(Food_now + Output_food - Food eaten, 0, Cap)
##
## Base yield: every tile the city claims (season-adjusted terrain yields) plus the
## city-centre bonus (food part scaled by the season's farm output).
## Starvation: the stock would go below zero -> food 0, population shrinks, morale
## drops and stamina cannot recover. Stamina and morale changes take effect next round.
extends RefCounted

const YIELD_KEYS := ["food", "wood", "stone", "gold"]


static func morale_multiplier(data, morale: float) -> float:
	return maxf(morale / 100.0, data.condition_value("morale", "output_floor", 0.0))


## Season-adjusted yield of the city's tiles plus the centre bonus, before modifiers.
static func base_production(data, map, city, season_id: String) -> Dictionary:
	var production := {"food": 0.0, "wood": 0.0, "stone": 0.0, "gold": 0.0, "tiles": 0}
	for c in map.tiles:
		var tile = map.tiles[c]
		if tile.city_id != city.id:
			continue
		var s: Dictionary = tile.stats(data, season_id)
		for k in YIELD_KEYS:
			production[k] = float(production[k]) + float(s[k])
		production["tiles"] = int(production["tiles"]) + 1
	var bonus: Dictionary = data.economy.get("city_centre_bonus", {})
	var food_mult: float = data.season_value(season_id, "farm_output", 1.0)
	for k in YIELD_KEYS:
		var b := float(bonus.get(k, 0.0))
		if k == "food":
			b *= food_mult
		production[k] = float(production[k]) + b
	return production


static func project(data, map, city, season_id: String) -> Dictionary:
	var base := base_production(data, map, city, season_id)
	var pace: Dictionary = data.pace(city.pace)
	var rations: Dictionary = data.rations(city.rations)
	var pace_mult := float(pace.get("output", 1.0))
	var morale_mult := morale_multiplier(data, city.morale)
	var stamina_mult: float = city.stamina / 100.0
	var output_mult := pace_mult * morale_mult

	var production := {}
	for k in YIELD_KEYS:
		production[k] = float(base[k]) * output_mult

	var pop: float = city.population
	var manpower: float = pop * data.econ("manpower_per_pop", 0.5) * output_mult * stamina_mult
	var ration_mult := float(rations.get("food_use", 1.0))
	var eaten: float = pop * data.econ("food_per_pop", 1.0) * ration_mult
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

	# Stamina: set by this round's pace and rations; no recovery while starving.
	var stamina_delta := float(pace.get("stamina", 0.0)) + float(rations.get("stamina", 0.0))
	if starving:
		stamina_delta = minf(stamina_delta, 0.0)
	var stamina_after := clampf(city.stamina + stamina_delta, 0.0, data.condition_value("stamina", "max", 100.0))

	# Morale: each source listed so the UI can show why it moved.
	var morale_changes := {}
	var drift: float = data.season_value(season_id, "morale_drift", 0.0)
	if drift != 0.0:
		morale_changes[data.season_name(season_id)] = drift
	var ration_morale := float(rations.get("morale", 0.0))
	if ration_morale != 0.0:
		morale_changes[str(rations.get("name", city.rations))] = ration_morale
	if starving:
		morale_changes["Starvation"] = data.condition_value("morale", "starvation", 0.0)
	var morale_delta := 0.0
	for k in morale_changes:
		morale_delta += float(morale_changes[k])
	var morale_after := clampf(city.morale + morale_delta,
		data.condition_value("morale", "min", 0.0), data.condition_value("morale", "max", 200.0))

	var threshold: float = data.condition_value("rebellion", "threshold", 50.0)
	var rebellion_chance := clampf((threshold - morale_after) * data.condition_value("rebellion", "chance_per_point", 0.01), 0.0, 1.0)

	return {
		"season": season_id,
		"tiles_worked": int(base["tiles"]),
		"base_production": base,
		"pace": city.pace,
		"rations": city.rations,
		"pace_multiplier": pace_mult,
		"morale_multiplier": morale_mult,
		"stamina_multiplier": stamina_mult,
		"output_multiplier": output_mult,
		"production": production,
		"manpower_produced": manpower,
		"food_before": city.food,
		"food_eaten": eaten,
		"ration_multiplier": ration_mult,
		"food_net": produced - eaten,
		"food_after": food_after,
		"food_cap": cap,
		"food_wasted": maxf(0.0, raw - cap),
		"food_shortfall": maxf(0.0, -raw),
		"starving": starving,
		"population_before": pop,
		"population_after": pop_after,
		"stamina_before": city.stamina,
		"stamina_delta": stamina_delta,
		"stamina_after": stamina_after,
		"morale_before": city.morale,
		"morale_changes": morale_changes,
		"morale_after": morale_after,
		"rebellion_chance": rebellion_chance,
	}


## Commit a report. `rebelled` is the result of the caller's seeded roll against
## report.rebellion_chance; when true, part of the population rebels and leaves.
static func apply(data, report: Dictionary, city, faction, rebelled: bool = false) -> void:
	var pop_after := float(report["population_after"])
	var rebels := 0.0
	if rebelled:
		var min_pop: float = data.econ("min_population", 1.0)
		rebels = minf(pop_after * data.condition_value("rebellion", "population_share", 0.1), maxf(0.0, pop_after - min_pop))
		pop_after -= rebels
	report["rebelled"] = rebelled
	report["rebels"] = rebels

	city.food = float(report["food_after"])
	city.population = pop_after
	city.manpower += float(report["manpower_produced"])
	city.starving = bool(report["starving"])
	city.stamina = float(report["stamina_after"])
	city.morale = float(report["morale_after"])
	city.rebels += rebels
	city.last_report = report
	var production: Dictionary = report["production"]
	if faction != null:
		for k in ["wood", "stone", "gold"]:
			faction.treasury[k] = float(faction.treasury.get(k, 0.0)) + float(production[k])
