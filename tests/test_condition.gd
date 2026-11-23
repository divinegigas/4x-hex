extends "res://tests/test_case.gd"

const Hex = preload("res://src/sim/hex.gd")
const GameData = preload("res://src/sim/game_data.gd")
const GameState = preload("res://src/sim/game_state.gd")
const HexMap = preload("res://src/sim/hex_map.gd")
const Tile = preload("res://src/sim/tile.gd")
const Economy = preload("res://src/sim/economy.gd")


func _state(population: float = 5.0, food: float = 30.0) -> GameState:
	var data := GameData.new()
	var map := HexMap.new(5, 5, 11)
	for c in Hex.within(Vector2i.ZERO, 2):
		map.add_tile(Tile.new(c, "grassland"))
	var state := GameState.new(data, map)
	var f := state.add_faction("Test", "humans", "#ffffff", true)
	var city := state.found_city(f.id, Vector2i.ZERO, "Testford")
	city.population = population
	city.food = food
	return state


func _project(state: GameState, season_id: String = "summer") -> Dictionary:
	return Economy.project(state.data, state.map, state.cities[0], season_id)


func test_condition_data_loads() -> void:
	var data := GameData.new()
	check(data.errors.is_empty(), ", ".join(data.errors))


func test_new_city_starts_fresh() -> void:
	var city := _state().cities[0]
	check_eq(city.stamina, 100.0)
	check_eq(city.morale, 100.0)
	check_eq(city.pace, "normal")
	check_eq(city.rations, "normal")


func test_normal_settings_change_nothing() -> void:
	var state := _state()
	var r := _project(state, "summer")  # summer has no morale drift
	check_eq(r["output_multiplier"], 1.0)
	check_eq(r["stamina_after"], 100.0)
	check_eq(r["morale_after"], 100.0)
	check_eq(r["rebellion_chance"], 0.0)


func test_pace_scales_output_and_stamina() -> void:
	var state := _state()
	var city := state.cities[0]
	var base_food := float(_project(state)["production"]["food"])
	city.stamina = 50.0
	check(state.set_city_pace(city, "high"), "high is a valid pace")
	var high := _project(state)
	check_eq(high["production"]["food"], base_food * float(state.data.pace("high")["output"]))
	check_eq(high["stamina_after"], 50.0 + float(state.data.pace("high")["stamina"]))
	state.set_city_pace(city, "low")
	var low := _project(state)
	check_eq(low["production"]["food"], base_food * float(state.data.pace("low")["output"]))
	check_eq(low["stamina_after"], 50.0 + float(state.data.pace("low")["stamina"]))
	check(not state.set_city_pace(city, "frantic"), "unknown pace rejected")
	check_eq(city.pace, "low")


func test_stamina_never_exceeds_max() -> void:
	var state := _state()
	state.set_city_pace(state.cities[0], "low")
	check_eq(_project(state)["stamina_after"], state.data.condition_value("stamina", "max"))


func test_rations_scale_food_eaten_and_condition() -> void:
	var state := _state(10.0)
	var city := state.cities[0]
	city.stamina = 50.0
	var normal_eaten := float(_project(state)["food_eaten"])
	for id in ["half", "extra"]:
		state.set_city_rations(city, id)
		var r := _project(state)
		var ration: Dictionary = state.data.rations(id)
		check_eq(r["food_eaten"], normal_eaten * float(ration["food_use"]), id)
		check_eq(r["stamina_after"], 50.0 + float(ration["stamina"]), id)
		check_eq(r["morale_after"], 100.0 + float(ration["morale"]), id)


func test_high_pace_with_extra_rations_holds_stamina() -> void:
	# The doc's example combo: more output, stamina steady, double food.
	var state := _state()
	var city := state.cities[0]
	city.stamina = 70.0
	state.set_city_pace(city, "high")
	state.set_city_rations(city, "extra")
	var r := _project(state)
	check_eq(r["stamina_after"], 70.0)
	check(float(r["output_multiplier"]) > 1.0, "more output")


func test_stamina_scales_manpower_only() -> void:
	var state := _state()
	var city := state.cities[0]
	var full := _project(state)
	city.stamina = 80.0
	var tired := _project(state)
	check_eq(tired["manpower_produced"], float(full["manpower_produced"]) * 0.8)
	check_eq(tired["production"]["food"], full["production"]["food"])


func test_morale_multiplies_output() -> void:
	var state := _state()
	var city := state.cities[0]
	var base := _project(state)
	city.morale = 200.0
	check_eq(_project(state)["production"]["gold"], float(base["production"]["gold"]) * 2.0)
	city.morale = 50.0
	check_eq(_project(state)["production"]["gold"], float(base["production"]["gold"]) * 0.5)
	city.morale = 0.0
	var floor_mult := state.data.condition_value("morale", "output_floor")
	check_eq(_project(state)["morale_multiplier"], floor_mult)


func test_seasons_drift_morale() -> void:
	var state := _state()
	check_eq(_project(state, "spring")["morale_after"], 100.0 + state.data.season_value("spring", "morale_drift"))
	check_eq(_project(state, "winter")["morale_after"], 100.0 + state.data.season_value("winter", "morale_drift"))


func test_starvation_hurts_morale_and_blocks_recovery() -> void:
	var state := _state(50.0, 0.0)
	var city := state.cities[0]
	city.stamina = 60.0
	state.set_city_pace(city, "low")  # would normally recover stamina
	var r := _project(state, "summer")
	check_eq(r["starving"], true)
	check_eq(r["stamina_after"], 60.0, "no recovery while starving")
	check_eq(r["morale_after"], 100.0 + state.data.condition_value("morale", "starvation"))


func test_rebellion_chance_below_threshold() -> void:
	var state := _state()
	var city := state.cities[0]
	city.morale = 40.0
	var r := _project(state, "summer")
	var expected := (state.data.condition_value("rebellion", "threshold") - 40.0) * state.data.condition_value("rebellion", "chance_per_point")
	check_eq(r["rebellion_chance"], expected)
	city.morale = 60.0
	check_eq(_project(state, "summer")["rebellion_chance"], 0.0)


func test_rebellion_removes_population() -> void:
	var state := _state(20.0)
	var city := state.cities[0]
	var r := _project(state, "summer")
	Economy.apply(state.data, r, city, state.get_faction(0), true)
	var share := state.data.condition_value("rebellion", "population_share")
	check_eq(city.population, float(r["population_after"]) * (1.0 - share))
	check_eq(city.rebels, float(r["population_after"]) * share)
	check_eq(city.last_report["rebelled"], true)


func test_condition_updates_on_end_round() -> void:
	var state := _state()
	var city := state.cities[0]
	state.set_city_pace(city, "high")
	var r := state.project_city(city)
	state.end_round()
	check_eq(city.stamina, r["stamina_after"])
	check_eq(city.morale, r["morale_after"])


func test_rebellion_rolls_are_deterministic() -> void:
	var results: Array = []
	for attempt in 2:
		var state := _state(30.0)
		var city := state.cities[0]
		city.morale = 10.0
		state.set_city_rations(city, "half")
		for i in 8:
			state.end_round()
		results.append([city.population, city.rebels, city.morale])
	check_eq(results[0], results[1])
