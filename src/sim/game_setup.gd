## Starts a new game on a generated map: creates the player faction and founds
## its first city on a good site. Pure, so tests and AI-vs-AI runs can use it.
extends RefCounted

const Hex = preload("res://src/sim/hex.gd")
const GameState = preload("res://src/sim/game_state.gd")


static func start(data, map) -> GameState:
	var state := GameState.new(data, map)
	var race_id := str(data.setup.get("player_race", "humans"))
	var race: Dictionary = data.race(race_id)
	var faction := state.add_faction(str(race.get("name", race_id)), race_id, str(race.get("color", "#ffffff")), true)
	var start_res: Dictionary = race.get("starting_resources", {})
	for k in faction.treasury:
		faction.treasury[k] = float(start_res.get(k, 0.0))

	@warning_ignore("integer_division")
	var map_centre := Hex.offset_to_axial(int(map.width) / 2, int(map.height) / 2)
	var site: Variant = find_city_site(data, map, map_centre)
	if site == null:
		push_warning("No valid city site on this map")
		return state
	var names: Array = race.get("city_names", ["City"])
	var city := state.found_city(faction.id, site, str(names[0]))
	city.population = float(race.get("starting_population", 5.0))
	city.food = float(start_res.get("food", 0.0))
	city.manpower = float(start_res.get("manpower", 0.0))
	return state


## The site-terrain tile nearest `near` that keeps clear of savage lairs.
## Falls back to ignoring lairs, then returns null if no site terrain exists.
static func find_city_site(data, map, near: Vector2i) -> Variant:
	var site_terrains: Array = data.economy.get("city_site_terrains", [])
	var min_lair := int(data.econ("city_min_lair_distance", 4))
	var lairs: Array[Vector2i] = map.lair_coords()
	for respect_lairs in [true, false]:
		var best: Variant = null
		var best_dist := 1 << 30
		for c in map.tiles:
			var tile = map.tiles[c]
			if not site_terrains.has(tile.terrain) or tile.savage_spawn:
				continue
			if respect_lairs:
				var too_close := false
				for l in lairs:
					if Hex.distance(c, l) < min_lair:
						too_close = true
						break
				if too_close:
					continue
			var d := Hex.distance(c, near)
			if d < best_dist:
				best_dist = d
				best = c
		if best != null:
			return best
	return null
