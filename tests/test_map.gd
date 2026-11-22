extends "res://tests/test_case.gd"

const GameData = preload("res://src/sim/game_data.gd")
const Hex = preload("res://src/sim/hex.gd")
const MapGenerator = preload("res://src/sim/map_generator.gd")

var data := GameData.new()


func _terrain_signature(map) -> String:
	var parts: PackedStringArray = []
	for row in map.height:
		for col in map.width:
			var t = map.get_tile(Hex.offset_to_axial(col, row))
			parts.append(t.terrain + ("*" if t.savage_spawn else ""))
	return ",".join(parts)


func test_map_has_every_tile_with_known_terrain() -> void:
	var map := MapGenerator.generate(data, 1234, {"map_width": 20, "map_height": 14})
	check_eq(map.tile_count(), 20 * 14)
	for row in 14:
		for col in 20:
			var c := Hex.offset_to_axial(col, row)
			check(map.has_tile(c), "missing tile at offset %d,%d" % [col, row])
	for c in map.tiles:
		check(data.has_terrain(map.get_tile(c).terrain), "unknown terrain at %s" % c)


func test_generation_is_deterministic() -> void:
	var a := MapGenerator.generate(data, 42)
	var b := MapGenerator.generate(data, 42)
	var c := MapGenerator.generate(data, 43)
	check_eq(_terrain_signature(a), _terrain_signature(b), "same seed")
	check(_terrain_signature(a) != _terrain_signature(c), "different seeds should differ")


func test_terrain_mix_matches_setup() -> void:
	var map := MapGenerator.generate(data, 7)
	var counts := {}
	for c in map.tiles:
		var t: String = map.get_tile(c).terrain
		counts[t] = int(counts.get(t, 0)) + 1
	var n := map.tile_count()
	var gen: Dictionary = data.setup["generation"]
	check_eq(int(counts.get("lake", 0)), int(n * float(gen["lake_fraction"])))
	check_eq(int(counts.get("mountains", 0)), int(n * float(gen["mountain_fraction"])))
	check(int(counts.get("grassland", 0)) > 0, "has grassland")
	check(int(counts.get("plains", 0)) > 0, "has plains")


func test_lairs_count_terrain_and_spacing() -> void:
	var map := MapGenerator.generate(data, 99)
	var lairs := map.lair_coords()
	check_eq(lairs.size(), int(data.setup["savage_spawn_tiles"]))
	var eligible: Array = data.setup["savage_spawn_terrains"]
	var min_dist := int(data.setup["savage_spawn_min_distance"])
	for i in lairs.size():
		check(eligible.has(map.get_tile(lairs[i]).terrain), "lair on %s" % map.get_tile(lairs[i]).terrain)
		for j in range(i + 1, lairs.size()):
			check(Hex.distance(lairs[i], lairs[j]) >= min_dist, "lairs %s and %s too close" % [lairs[i], lairs[j]])


func test_lair_count_comes_from_setup() -> void:
	var map := MapGenerator.generate(data, 5, {"savage_spawn_tiles": 3})
	check_eq(map.lair_coords().size(), 3)
