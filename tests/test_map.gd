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


func test_salt_water_share_matches_setup() -> void:
	var map := MapGenerator.generate(data, 7)
	var salt := 0
	for c in map.tiles:
		if data.terrain_water(map.get_tile(c).terrain) == "salt":
			salt += 1
	var share := float(data.generation_params("continents")["ocean_fraction"])
	# Lakes that touch the sea become coast too, so there can be a few extra.
	check(salt >= int(map.tile_count() * share), "salt tiles %d" % salt)
	var land := 0
	for c in map.tiles:
		if data.terrain_water(map.get_tile(c).terrain) == "":
			land += 1
	check(land > map.tile_count() / 2, "mostly land (%d)" % land)


func test_land_never_touches_ocean() -> void:
	for map_seed in [3, 7, 42, 99, 2024]:
		var map := MapGenerator.generate(data, map_seed)
		for c in map.tiles:
			if map.get_tile(c).terrain != "ocean":
				continue
			for nb in map.neighbors_of(c):
				var t: String = map.get_tile(nb).terrain
				check(t == "ocean" or t == "coast", "seed %d: %s next to ocean at %s" % [map_seed, t, nb])


func test_lakes_are_inland() -> void:
	for map_seed in [3, 7, 42, 99, 2024]:
		var map := MapGenerator.generate(data, map_seed)
		for c in map.tiles:
			if map.get_tile(c).terrain != "lake":
				continue
			for nb in map.neighbors_of(c):
				check(data.terrain_water(map.get_tile(nb).terrain) != "salt", "seed %d: lake %s touches the sea" % [map_seed, c])


func test_oceans_ring_the_map_edges() -> void:
	var map := MapGenerator.generate(data, 42)
	var edge := 0
	var salt := 0
	for row in map.height:
		for col in map.width:
			if row != 0 and col != 0 and row != map.height - 1 and col != map.width - 1:
				continue
			edge += 1
			if data.terrain_water(map.get_tile(Hex.offset_to_axial(col, row)).terrain) == "salt":
				salt += 1
	check(salt >= edge * 0.8, "%d of %d edge tiles are sea" % [salt, edge])


## Every lake and river tile reaches the sea through lakes and rivers.
func test_fresh_water_drains_to_the_sea() -> void:
	for map_seed in [3, 7, 42, 99, 2024]:
		var map := MapGenerator.generate(data, map_seed)
		var rivers := 0
		for c in map.tiles:
			var t: String = map.get_tile(c).terrain
			if t == "river":
				rivers += 1
			if t != "lake" and t != "river":
				continue
			check(_reaches_sea(map, c), "seed %d: %s at %s does not reach the sea" % [map_seed, t, c])
		check(rivers > 0, "seed %d has rivers" % map_seed)


func _reaches_sea(map, start: Vector2i) -> bool:
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var i := 0
	while i < queue.size():
		for nb in map.neighbors_of(queue[i]):
			var t: String = map.get_tile(nb).terrain
			if data.terrain_water(t) == "salt":
				return true
			if (t == "lake" or t == "river") and not seen.has(nb):
				seen[nb] = true
				queue.append(nb)
		i += 1
	return false


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


func test_every_map_type_keeps_the_water_rules() -> void:
	check(data.map_type_ids().size() >= 2, "several map types")
	for type_id in data.map_type_ids():
		for map_seed in [5, 17]:
			var map := MapGenerator.generate(data, map_seed, {"map_type": type_id})
			var where := "%s seed %d" % [type_id, map_seed]
			check_eq(map.tile_count(), map.width * map.height, where)
			for c in map.tiles:
				var t: String = map.get_tile(c).terrain
				check(data.has_terrain(t), "%s: unknown terrain %s" % [where, t])
				if t == "ocean":
					for nb in map.neighbors_of(c):
						var nt: String = map.get_tile(nb).terrain
						check(nt == "ocean" or nt == "coast", "%s: %s next to ocean" % [where, nt])
				if t == "lake" or t == "river":
					check(_reaches_sea(map, c), "%s: %s at %s does not reach the sea" % [where, t, c])


func test_map_types_differ() -> void:
	var count_water := func(type_id: String) -> int:
		var map := MapGenerator.generate(data, 9, {"map_type": type_id})
		var n := 0
		for c in map.tiles:
			if data.terrain_water(map.get_tile(c).terrain) == "salt":
				n += 1
		return n
	check(int(count_water.call("islands")) > int(count_water.call("continents")), "islands have more sea")
	var count_high := func(type_id: String) -> int:
		var map := MapGenerator.generate(data, 9, {"map_type": type_id})
		var n := 0
		for c in map.tiles:
			var t: String = map.get_tile(c).terrain
			if t == "hills" or t == "mountains":
				n += 1
		return n
	check(int(count_high.call("highlands")) > int(count_high.call("continents")), "highlands are higher")


func test_unknown_map_type_falls_back_to_default() -> void:
	var a := MapGenerator.generate(data, 31, {"map_type": "no_such_type"})
	var b := MapGenerator.generate(data, 31, {"map_type": str(data.map_types["default"])})
	check_eq(_terrain_signature(a), _terrain_signature(b))
