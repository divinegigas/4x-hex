extends "res://tests/test_case.gd"

const GameData = preload("res://src/sim/game_data.gd")
const GameState = preload("res://src/sim/game_state.gd")
const HexMap = preload("res://src/sim/hex_map.gd")
const Tile = preload("res://src/sim/tile.gd")


func _state_with_tile(terrain: String) -> GameState:
	var data := GameData.new()
	var map := HexMap.new(1, 1, 1)
	map.add_tile(Tile.new(Vector2i.ZERO, terrain))
	return GameState.new(data, map)


func test_data_loads_cleanly() -> void:
	var data := GameData.new()
	check(data.errors.is_empty(), "data errors: %s" % ", ".join(data.errors))
	check_eq(data.season_order.size(), 4)


func test_rounds_cycle_seasons_and_years() -> void:
	var state := _state_with_tile("grassland")
	var seen: Array[String] = []
	for i in 9:
		seen.append(state.season())
		state.end_round()
	check_eq(seen, ["spring", "summer", "fall", "winter", "spring", "summer", "fall", "winter", "spring"] as Array[String])
	check_eq(state.round_number, 10)
	check_eq(state.year(), 3)


func test_season_changed_signal() -> void:
	var state := _state_with_tile("grassland")
	var got: Array[String] = []
	state.season_changed.connect(func(s: String) -> void: got.append(s))
	state.end_round()
	state.end_round()
	check_eq(got, ["summer", "fall"] as Array[String])


func test_seasonal_stats_follow_doc() -> void:
	var state := _state_with_tile("grassland")
	var tile := state.map.get_tile(Vector2i.ZERO)
	var base: Dictionary = state.data.terrain("grassland")["base"]
	var base_food := float(base["food"])
	var base_move := float(base["move_cost"])
	var spring := tile.stats(state.data, "spring")
	var summer := tile.stats(state.data, "summer")
	var fall := tile.stats(state.data, "fall")
	var winter := tile.stats(state.data, "winter")
	check_eq(spring["food"], base_food * 0.5, "spring farm output x0.5")
	check_eq(summer["food"], base_food, "summer baseline")
	check_eq(fall["food"], base_food * 2.0, "fall farm output x2")
	check(float(winter["food"]) < base_food * 0.25, "winter food almost none")
	check_eq(summer["move_cost"], base_move * 0.5, "summer movement x0.5")
	check_eq(winter["move_cost"], base_move * 2.0, "winter movement x2")


func test_season_override_applies_before_multipliers() -> void:
	var state := _state_with_tile("grassland")
	state.data.terrains["grassland"]["season_overrides"] = {"winter": {"food": 10.0, "passable": false}}
	var tile := state.map.get_tile(Vector2i.ZERO)
	var winter := tile.stats(state.data, "winter")
	check_eq(winter["food"], 10.0 * state.data.season_value("winter", "farm_output"))
	check_eq(winter["passable"], false)
	check_eq(tile.stats(state.data, "summer")["passable"], true)


func test_ravaged_tiles_recover_over_seasons() -> void:
	var state := _state_with_tile("forest")
	var tile := state.map.get_tile(Vector2i.ZERO)
	var normal_wood := float(tile.stats(state.data, "summer")["wood"])
	tile.ravaged_seasons = 2
	var mult := float(state.data.setup["ravaged_yield_multiplier"])
	check_eq(tile.stats(state.data, "summer")["wood"], normal_wood * mult)
	state.end_round()
	check(tile.is_ravaged(), "still ravaged after one flip")
	state.end_round()
	check(not tile.is_ravaged(), "recovered after two flips")
	check_eq(tile.stats(state.data, "summer")["wood"], normal_wood)
