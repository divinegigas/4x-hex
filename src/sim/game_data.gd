## Loads and validates the tunable game data in res://data.
## Everything balance-related comes from here, never from literals in code.
extends RefCounted

const YIELD_KEYS := ["food", "wood", "stone", "gold"]

var terrains: Dictionary = {}
var seasons: Dictionary = {}
var season_order: PackedStringArray = []
var setup: Dictionary = {}
var economy: Dictionary = {}
var races: Dictionary = {}
var condition: Dictionary = {}
var map_types: Dictionary = {}
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
	economy = _load_json(data_dir.path_join("economy.json"))
	var race_doc := _load_json(data_dir.path_join("races.json"))
	races = race_doc.get("races", {})
	condition = _load_json(data_dir.path_join("condition.json"))
	map_types = _load_json(data_dir.path_join("map_types.json"))
	_validate()


func has_terrain(id: String) -> bool:
	return terrains.has(id)


func terrain(id: String) -> Dictionary:
	return terrains.get(id, {})


func terrain_name(id: String) -> String:
	return str(terrain(id).get("name", id))


## Height of the terrain (used by the isometric view; later by terrain effects).
func terrain_elevation(id: String) -> float:
	return float(terrain(id).get("elevation", 0.0))


## "salt", "fresh" or "" (land).
func terrain_water(id: String) -> String:
	return str(terrain(id).get("water", ""))


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


func econ(key: String, default_value: float = 0.0) -> float:
	return float(economy.get(key, default_value))


## Storage cap for a resource, or INF when it has none.
func storage_cap(resource: String) -> float:
	var caps: Dictionary = economy.get("storage_caps", {})
	return float(caps.get(resource, INF))


## A value from a section of condition.json, e.g. condition_value("morale", "max").
func condition_value(section: String, key: String, default_value: float = 0.0) -> float:
	var sec: Dictionary = condition.get(section, {})
	return float(sec.get(key, default_value))


## A pace setting ("low", "normal", "high"); unknown ids fall back to normal.
func pace(id: String) -> Dictionary:
	var all: Dictionary = condition.get("pace", {})
	return all.get(id, all.get("normal", {}))


## A ration setting ("half", "normal", "extra"); unknown ids fall back to normal.
func rations(id: String) -> Dictionary:
	var all: Dictionary = condition.get("rations", {})
	return all.get(id, all.get("normal", {}))


## Map type ids in file order.
func map_type_ids() -> PackedStringArray:
	var types: Dictionary = map_types.get("types", {})
	return PackedStringArray(types.keys())


func map_type_name(id: String) -> String:
	var types: Dictionary = map_types.get("types", {})
	var t: Dictionary = types.get(id, {})
	return str(t.get("name", id.capitalize()))


## Full generation settings for a map type: defaults overlaid with the type's changes.
## Unknown ids fall back to the default type.
func generation_params(type_id: String) -> Dictionary:
	var types: Dictionary = map_types.get("types", {})
	if not types.has(type_id):
		type_id = str(map_types.get("default", ""))
	var params: Dictionary = map_types.get("defaults", {}).duplicate(true)
	var t: Dictionary = types.get(type_id, {})
	var changes: Dictionary = t.get("generation", {})
	for k in changes:
		params[k] = changes[k]
	return params


func race(id: String) -> Dictionary:
	return races.get(id, {})


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
		var elev: Variant = t.get("elevation", 0.0)
		if typeof(elev) != TYPE_FLOAT and typeof(elev) != TYPE_INT:
			errors.append("terrain.json: '%s' elevation is not a number" % id)
		if not t.has("base"):
			errors.append("terrain.json: '%s' has no 'base' block" % id)
		var colors: Dictionary = t.get("colors", {})
		for s in season_order:
			if not Color.html_is_valid(str(colors.get(s, ""))):
				errors.append("terrain.json: '%s' has no valid %s colour" % [id, s])
	for key in ["food_per_pop", "manpower_per_pop", "starvation_shrink_rate", "growth_rate", "min_population", "city_claim_radius"]:
		if not economy.has(key):
			errors.append("economy.json: missing '%s'" % key)
	var site_terrains: Array = economy.get("city_site_terrains", [])
	for id in site_terrains:
		if not terrains.has(str(id)):
			errors.append("economy.json: city site terrain '%s' is not defined" % id)
	for pair in [["pace", ["low", "normal", "high"]], ["rations", ["half", "normal", "extra"]]]:
		var sec: Dictionary = condition.get(pair[0], {})
		for id in pair[1]:
			if not sec.has(id):
				errors.append("condition.json: %s has no '%s' setting" % [pair[0], id])
	for sec_name in ["stamina", "morale", "rebellion"]:
		if not condition.has(sec_name):
			errors.append("condition.json: missing '%s' section" % sec_name)
	for id in ["ocean", "coast", "lake", "river", "grassland", "plains", "forest", "hills", "mountains", "swamp"]:
		if not terrains.has(id):
			errors.append("terrain.json: map generator needs terrain '%s'" % id)
	var types: Dictionary = map_types.get("types", {})
	if types.is_empty():
		errors.append("map_types.json: no map types defined")
	if not types.has(str(map_types.get("default", ""))):
		errors.append("map_types.json: default type '%s' is not defined" % map_types.get("default", ""))
	var defaults: Dictionary = map_types.get("defaults", {})
	for id in types:
		var changes: Dictionary = types[id].get("generation", {})
		for k in changes:
			if not defaults.has(k):
				errors.append("map_types.json: '%s' sets unknown setting '%s'" % [id, k])
	if not types.has(str(setup.get("map_type", ""))):
		errors.append("setup.json: map_type '%s' is not in map_types.json" % setup.get("map_type", ""))
	if races.is_empty():
		errors.append("races.json: no races defined")
	for id in races:
		var r: Dictionary = races[id]
		for key in ["name", "color", "starting_population", "starting_resources", "city_names"]:
			if not r.has(key):
				errors.append("races.json: '%s' is missing '%s'" % [id, key])
		if not Color.html_is_valid(str(r.get("color", ""))):
			errors.append("races.json: '%s' color is not a valid colour" % id)
	if not races.has(str(setup.get("player_race", ""))):
		errors.append("setup.json: player_race '%s' is not in races.json" % setup.get("player_race", ""))
	var spawn_terrains: Array = setup.get("savage_spawn_terrains", [])
	for id in spawn_terrains:
		if not terrains.has(str(id)):
			errors.append("setup.json: savage spawn terrain '%s' is not defined" % id)
