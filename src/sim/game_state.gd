## Whole-game simulation state and the round loop (design doc section 2).
## No nodes, no UI: the view listens to signals, and tests or AI-vs-AI runs
## can drive it headless.
extends RefCounted

signal season_changed(season_id: String)

const GameData = preload("res://src/sim/game_data.gd")
const HexMap = preload("res://src/sim/hex_map.gd")

var data: GameData
var map: HexMap
## 1-based. Every round is one season.
var round_number: int = 1


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


## Round flow: end-of-round resolution, then the next round starts with a season flip.
## Faction turns (in Leader-stat order) slot in between from build step 5 onwards.
func end_round() -> void:
	_resolve_end_of_round()
	round_number += 1
	_begin_round()


func _resolve_end_of_round() -> void:
	# Build steps 2-6: food, stamina and morale, supply connectivity, starvation.
	pass


func _begin_round() -> void:
	map.on_season_flip()
	season_changed.emit(season())
