## Whole-game simulation state and the round loop (design doc section 2).
## No nodes, no UI: the view listens to signals, and tests or AI-vs-AI runs
## can drive it headless.
extends RefCounted

signal season_changed(season_id: String)

const GameData = preload("res://src/sim/game_data.gd")
const HexMap = preload("res://src/sim/hex_map.gd")
const Hex = preload("res://src/sim/hex.gd")
const Faction = preload("res://src/sim/faction.gd")
const City = preload("res://src/sim/city.gd")
const Economy = preload("res://src/sim/economy.gd")

var data: GameData
var map: HexMap
## 1-based. Every round is one season.
var round_number: int = 1
var factions: Array[Faction] = []
var cities: Array[City] = []


func _init(game_data: GameData, hex_map: HexMap) -> void:
	data = game_data
	map = hex_map


func season_index() -> int:
	return (round_number - 1) % data.season_order.size()


func season() -> String:
	return data.season_order[season_index()]


func year() -> int:
	@warning_ignore("integer_division")
	return (round_number - 1) / data.season_order.size() + 1


func add_faction(display_name: String, race_id: String, color_html: String, is_player: bool) -> Faction:
	var f := Faction.new(factions.size(), display_name, race_id, color_html, is_player)
	factions.append(f)
	return f


func get_faction(id: int) -> Faction:
	if id < 0 or id >= factions.size():
		return null
	return factions[id]


## Found a city at `at` and claim unowned tiles within city_claim_radius.
func found_city(owner_id: int, at: Vector2i, display_name: String) -> City:
	var city := City.new(cities.size(), display_name, owner_id, at)
	cities.append(city)
	var radius := int(data.econ("city_claim_radius", 1))
	for c in Hex.within(at, radius):
		var tile := map.get_tile(c)
		if tile == null or (tile.owner_id >= 0 and c != at):
			continue
		tile.owner_id = owner_id
		tile.city_id = city.id
	map.get_tile(at).improvement = "city"
	return city


func city_at(c: Vector2i) -> City:
	for city in cities:
		if city.coord == c:
			return city
	return null


func get_city(id: int) -> City:
	if id < 0 or id >= cities.size():
		return null
	return cities[id]


## What a city's economy will do at the end of this round (nothing is changed).
func project_city(city: City) -> Dictionary:
	return Economy.project(data, map, city, season())


## Round flow: end-of-round resolution, then the next round starts with a season flip.
## Faction turns (in Leader-stat order) slot in between from build step 5 onwards.
func end_round() -> void:
	_resolve_end_of_round()
	round_number += 1
	_begin_round()


func _resolve_end_of_round() -> void:
	# Food production and consumption use the season of the round just played.
	for city in cities:
		Economy.apply(project_city(city), city, get_faction(city.owner_id))
	# Build steps 3-6: stamina and morale, supply connectivity, army starvation.


func _begin_round() -> void:
	map.on_season_flip()
	season_changed.emit(season())
