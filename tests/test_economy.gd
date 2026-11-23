extends "res://tests/test_case.gd"

const Hex = preload("res://src/sim/hex.gd")
const GameData = preload("res://src/sim/game_data.gd")
const GameState = preload("res://src/sim/game_state.gd")
const GameSetup = preload("res://src/sim/game_setup.gd")
const HexMap = preload("res://src/sim/hex_map.gd")
const MapGenerator = preload("res://src/sim/map_generator.gd")
const Tile = preload("res://src/sim/tile.gd")
const Economy = preload("res://src/sim/economy.gd")


## A radius-2 all-grassland map with one city at the centre (claims radius 1 = 7 tiles).
func _city_state(population: float, food: float) -> GameState:
	var data := GameData.new()
	var map := HexMap.new(5, 5, 1)
	for c in Hex.within(Vector2i.ZERO, 2):
		map.add_tile(Tile.new(c, "grassland"))
	var state := GameState.new(data, map)
	var f := state.add_faction("Test", "humans", "#ffffff", true)
	var city := state.found_city(f.id, Vector2i.ZERO, "Testford")
	city.population = population
	city.food = food
	return state


## Expected food production for the test city in a season, derived from data.
func _expected_food(state: GameState, season_id: String) -> float:
	var grass_food := float(state.data.terrain("grassland")["base"]["food"])
	var bonus := float(state.data.economy["city_centre_bonus"]["food"])
	var mult := state.data.season_value(season_id, "farm_output")
	return (7.0 * grass_food + bonus) * mult


func test_data_loads_cleanly() -> void:
	var data := GameData.new()
	check(data.errors.is_empty(), ", ".join(data.errors))


func test_found_city_claims_ring() -> void:
	var state := _city_state(5.0, 0.0)
	var claimed := 0
	for c in state.map.tiles:
		var t = state.map.get_tile(c)
		if t.city_id == 0:
			claimed += 1
			check_eq(t.owner_id, 0)
			check(Hex.distance(c, Vector2i.ZERO) <= 1, "claimed tile %s outside radius" % c)
	check_eq(claimed, 7)
	check_eq(state.map.get_tile(Vector2i.ZERO).improvement, "city")
	check(state.city_at(Vector2i.ZERO) != null, "city_at finds the city")


func test_food_production_follows_season() -> void:
	var state := _city_state(5.0, 20.0)
	var city := state.cities[0]
	for season_id in ["spring", "summer", "fall", "winter"]:
		var r := Economy.project(state.data, state.map, city, season_id)
		check_eq(r["production"]["food"], _expected_food(state, season_id), season_id)
		check_eq(r["food_eaten"], 5.0 * state.data.econ("food_per_pop"), season_id)


func test_food_balance_formula() -> void:
	var state := _city_state(5.0, 20.0)
	var r := Economy.project(state.data, state.map, state.cities[0], "summer")
	var expected := 20.0 + _expected_food(state, "summer") - 5.0 * state.data.econ("food_per_pop")
	check_eq(r["food_after"], minf(expected, state.data.storage_cap("food")))
	check_eq(r["starving"], false)


func test_storage_cap_spoils_excess() -> void:
	var cap := GameData.new().storage_cap("food")
	var state := _city_state(1.0, cap - 1.0)
	var r := Economy.project(state.data, state.map, state.cities[0], "fall")
	check_eq(r["food_after"], cap)
	check(float(r["food_wasted"]) > 0.0, "excess food is wasted")


func test_starvation_empties_store_and_shrinks_population() -> void:
	var state := _city_state(50.0, 0.0)
	var city := state.cities[0]
	var r := Economy.project(state.data, state.map, city, "winter")
	check_eq(r["starving"], true)
	check_eq(r["food_after"], 0.0)
	check_eq(r["population_after"], 50.0 * (1.0 - state.data.econ("starvation_shrink_rate")))
	Economy.apply(state.data, r, city, state.get_faction(0))
	check(city.starving, "city flagged starving")
	check_eq(city.food, 0.0)


func test_surplus_grows_population() -> void:
	var state := _city_state(5.0, 0.0)
	var r := Economy.project(state.data, state.map, state.cities[0], "summer")
	check_eq(r["population_after"], 5.0 * (1.0 + state.data.econ("growth_rate")))


func test_population_never_below_minimum() -> void:
	var state := _city_state(1.0, 0.0)
	state.data.economy["food_per_pop"] = 1000.0
	var r := Economy.project(state.data, state.map, state.cities[0], "winter")
	check_eq(r["population_after"], state.data.econ("min_population"))


func test_end_round_resolves_with_season_played() -> void:
	var state := _city_state(5.0, 20.0)
	var city := state.cities[0]
	var faction := state.get_faction(0)
	var gold_before := float(faction.treasury["gold"])
	var spring := state.project_city(city)
	check_eq(spring["season"], "spring")
	state.end_round()
	check_eq(city.food, spring["food_after"])
	check_eq(city.population, spring["population_after"])
	check_eq(city.manpower, spring["manpower_produced"])
	check_eq(faction.treasury["gold"], gold_before + float(spring["production"]["gold"]))
	check_eq(city.last_report["season"], "spring")


func test_a_year_of_rounds_stays_sane() -> void:
	var state := _city_state(5.0, 20.0)
	var city := state.cities[0]
	for i in 12:
		state.end_round()
		check(city.food >= 0.0 and city.food <= state.data.storage_cap("food"), "food in range round %d" % i)
		check(city.population >= state.data.econ("min_population"), "population floor round %d" % i)


func test_game_setup_founds_capital_on_good_site() -> void:
	var data := GameData.new()
	var map := MapGenerator.generate(data, 2024)
	var state := GameSetup.start(data, map)
	check_eq(state.factions.size(), 1)
	check_eq(state.cities.size(), 1)
	var city := state.cities[0]
	var tile := map.get_tile(city.coord)
	var sites: Array = data.economy["city_site_terrains"]
	check(sites.has(tile.terrain), "capital on %s" % tile.terrain)
	for lair in map.lair_coords():
		check(Hex.distance(city.coord, lair) >= int(data.econ("city_min_lair_distance")), "capital too close to lair %s" % lair)
	var race: Dictionary = data.race("humans")
	check_eq(city.population, float(race["starting_population"]))
	check_eq(city.food, float(race["starting_resources"]["food"]))
	check_eq(state.get_faction(0).treasury["gold"], float(race["starting_resources"]["gold"]))
	check_eq(city.city_name, str(race["city_names"][0]))


func test_game_setup_is_deterministic() -> void:
	var data := GameData.new()
	var a := GameSetup.start(data, MapGenerator.generate(data, 77))
	var b := GameSetup.start(data, MapGenerator.generate(data, 77))
	check_eq(a.cities[0].coord, b.cities[0].coord)
