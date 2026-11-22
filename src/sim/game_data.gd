## Loads and validates the tunable game data in res://data.
## Everything balance-related comes from here, never from literals in code.
extends RefCounted

const YIELD_KEYS := ["food", "wood", "stone", "gold"]

var terrains: Dictionary = {}
var seasons: Dictionary = {}
var season_order: PackedStringArray = []
var setup: Dictionary = {}
## Empty when all data loaded and validated.
var errors: PackedStringArray = []


func _init(data_dir: String = "res://data") -> void:
	var terrain_doc := _load_json(data_dir.path_join("terrain.json"))
	terrains = terrain_doc.get("terrains", {})
	var season_doc := _load_json(data_dir.path_join("seasons.json"))
	var order: Array = season_doc.get("order", [])
	season_order = PackedStringArray(order)
	seasons = season_doc.get("seasons", {})
	setup = _load_json(data_dir.path_join("setup.json"))
	_validate()


func has_terrain(id: String) -> bool:
	return terrains.has(id)


func terrain(id: String) -> Dictionary:
	return terrains.get(id, {})


func terrain_name(id: String) -> String:
	return str(terrain(id).get("name", id))


func terrain_color(id: String, season_id: String) -> Color:
	var colors: Dictionary = terrain(id).get("colors", {})
	var hex_str := str(colors.get(season_id, ""))
	if Color.html_is_valid(hex_str):
		return Color.html(hex_str)
	return Color.MAGENTA  # Missing art shows up loudly.


## A global seasonal multiplier or value from seasons.json.
func season_value(season_id: String, key: String, default_value: float = 1.0) -> float:
	var s: Dictionary = seasons.get(season_id, {})
	return float(s.get(key, default_value))


func season_name(season_id: String) -> String:
	var s: Dictionary = seasons.get(season_id, {})
	return str(s.get("name", season_id.capitalize()))


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("Missing data file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("Could not parse %s as a JSON object" % path)
		return {}
	return parsed


func _validate() -> void:
	if season_order.is_empty():
		errors.append("seasons.json: 'order' is empty")
	for s in season_order:
		if not seasons.has(s):
			errors.append("seasons.json: season '%s' is in 'order' but has no entry" % s)
	if terrains.is_empty():
		errors.append("terrain.json: no terrains defined")
	for id in terrains:
		var t: Dictionary = terrains[id]
		if not t.has("base"):
			errors.append("terrain.json: '%s' has no 'base' block" % id)
		var colors: Dictionary = t.get("colors", {})
		for s in season_order:
			if not Color.html_is_valid(str(colors.get(s, ""))):
				errors.append("terrain.json: '%s' has no valid %s colour" % [id, s])
	var spawn_terrains: Array = setup.get("savage_spawn_terrains", [])
	for id in spawn_terrains:
		if not terrains.has(str(id)):
			errors.append("setup.json: savage spawn terrain '%s' is not defined" % id)
