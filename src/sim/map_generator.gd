## Builds a seeded, deterministic HexMap from setup data.
##
## Passes, in order:
##   1. Ocean: the lowest ocean_fraction of ALL tiles by elevation, with elevation
##      pushed down near the map edges so seas mostly ring the land.
##   2. Coast: every ocean tile touching land becomes coast, so land never borders
##      ocean directly.
##   3. Land terrain by noise *rank* (lakes, mountains, hills, swamp, forest,
##      plains, grassland), as shares of the land tiles, so every map has the mix
##      set in setup.json. Lakes touching salt water join the coast instead.
##   4. Rivers: every lake gets a river flowing downhill to the sea, then
##      river_sources extra rivers start in hills or mountains and run to the
##      nearest water. Each river ends in salt water or an earlier river, so the
##      water network is connected.
##   5. Savage lairs.
extends RefCounted

const Hex = preload("res://src/sim/hex.gd")
const HexMap = preload("res://src/sim/hex_map.gd")
const Tile = preload("res://src/sim/tile.gd")

const SALT := ["ocean", "coast"]


## `overrides` replaces top-level setup.json keys (tests use it for small maps).
static func generate(data, map_seed: int, overrides: Dictionary = {}) -> HexMap:
	var setup: Dictionary = data.setup.duplicate(true)
	for k in overrides:
		setup[k] = overrides[k]
	var gen: Dictionary = setup.get("generation", {})
	var width := int(setup.get("map_width", 40))
	var height := int(setup.get("map_height", 28))
	var freq := float(gen.get("noise_frequency", 0.08))
	var map := HexMap.new(width, height, map_seed)

	var elev_noise := _make_noise(map_seed, freq)
	var moist_noise := _make_noise(map_seed + 7919, freq * 1.3)
	var coords: Array[Vector2i] = []
	var raw_elev := {}
	var moist := {}
	var edge_dist := {}
	for row in height:
		for col in width:
			var c := Hex.offset_to_axial(col, row)
			# Sample noise in roughly-Euclidean space so features aren't skewed.
			var x: float = col + 0.5 * (row & 1)
			var y: float = row * 0.866
			coords.append(c)
			raw_elev[c] = elev_noise.get_noise_2d(x, y)
			moist[c] = moist_noise.get_noise_2d(x, y)
			edge_dist[c] = mini(mini(col, width - 1 - col), mini(row, height - 1 - row))

	# Elevation as a rank in [0, 1], lowered near the edges so oceans ring the land.
	var n := coords.size()
	var noise_rank := _ranks(coords, raw_elev)
	var edge_width := maxf(1.0, float(gen.get("edge_ocean_width", 5)))
	var edge_strength := float(gen.get("edge_ocean_strength", 0.7))
	var elev := {}
	for c in coords:
		var near_edge := maxf(0.0, 1.0 - float(edge_dist[c]) / edge_width)
		elev[c] = float(noise_rank[c]) - edge_strength * near_edge * near_edge
	var elev_rank := _ranks(coords, elev)

	var assigned := {}
	# 1-2. Ocean, then coast wherever ocean meets land.
	var by_elev := _sorted_by(coords, elev)
	var ocean_n := int(n * float(gen.get("ocean_fraction", 0.22)))
	for i in ocean_n:
		assigned[by_elev[i]] = "ocean"
	for i in ocean_n:
		var c: Vector2i = by_elev[i]
		for nb in Hex.neighbors(c):
			if edge_dist.has(nb) and not assigned.has(nb):
				assigned[c] = "coast"
				break

	# 3. Land terrain, as shares of the land tiles.
	var land := _unassigned(coords, assigned)
	var land_n := land.size()
	var land_by_elev := _sorted_by(land, elev)
	var lake_n := int(land_n * float(gen.get("lake_fraction", 0.04)))
	var mountain_n := int(land_n * float(gen.get("mountain_fraction", 0.08)))
	var hills_n := int(land_n * float(gen.get("hills_fraction", 0.14)))
	for i in mini(lake_n, land_n):
		var c: Vector2i = land_by_elev[i]
		assigned[c] = "coast" if _touches(c, assigned, SALT) else "lake"
	for i in mini(mountain_n, land_n):
		assigned[land_by_elev[land_n - 1 - i]] = "mountains"
	for i in clampi(hills_n, 0, maxi(0, land_n - mountain_n)):
		assigned[land_by_elev[land_n - 1 - mountain_n - i]] = "hills"
	# Lakes that ended up touching a converted lake-coast join the coast too.
	for c in coords:
		if assigned.get(c, "") == "lake" and _touches(c, assigned, SALT):
			assigned[c] = "coast"

	# Swamps: wet and low.
	var rest := _unassigned(coords, assigned)
	var moist_rank := _ranks(coords, moist)
	var wetness := {}
	for c in rest:
		wetness[c] = float(moist_rank[c]) - 0.5 * float(elev_rank[c])
	var by_wet := _sorted_by(rest, wetness)
	by_wet.reverse()
	var swamp_n := mini(int(land_n * float(gen.get("swamp_fraction", 0.08))), by_wet.size())
	for i in swamp_n:
		assigned[by_wet[i]] = "swamp"

	# Forest on the wettest of what's left; plains on the driest; grassland between.
	rest = _unassigned(coords, assigned)
	var by_moist := _sorted_by(rest, moist)
	by_moist.reverse()
	var forest_n := mini(int(land_n * float(gen.get("forest_fraction", 0.26))), by_moist.size())
	var plains_n := int((by_moist.size() - forest_n) * float(gen.get("plains_fraction_of_rest", 0.4)))
	for i in by_moist.size():
		var c: Vector2i = by_moist[i]
		if i < forest_n:
			assigned[c] = "forest"
		elif i >= by_moist.size() - plains_n:
			assigned[c] = "plains"
		else:
			assigned[c] = "grassland"

	# 4. Rivers.
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	_carve_rivers(coords, assigned, elev_rank, int(gen.get("river_sources", 4)), rng)

	for c in coords:
		map.add_tile(Tile.new(c, str(assigned[c])))

	# 5. Lairs (own RNG stream so river changes don't reshuffle them).
	_place_lairs(map, coords, setup, map_seed)
	return map


## Lakes drain to the sea first, then extra rivers run from highland sources.
static func _carve_rivers(coords: Array[Vector2i], assigned: Dictionary, elev_rank: Dictionary,
		extra_sources: int, rng: RandomNumberGenerator) -> void:
	var has_salt := false
	for c in coords:
		if SALT.has(assigned[c]):
			has_salt = true
			break
	if not has_salt:
		return

	# One river per lake (connected group of lake tiles), towards salt water or an earlier river.
	var seen := {}
	for c in coords:
		if assigned[c] != "lake" or seen.has(c):
			continue
		var group := _flood(c, assigned, "lake")
		for g in group:
			seen[g] = true
		_carve_path(group, assigned, elev_rank, ["ocean", "coast", "river"])

	# Extra rivers from hills/mountains not already beside water, to the nearest water.
	var sources: Array[Vector2i] = []
	for c in coords:
		var t: String = assigned[c]
		if (t == "hills" or t == "mountains") and not _touches(c, assigned, ["ocean", "coast", "lake", "river"]):
			sources.append(c)
	_shuffle(sources, rng)
	var made := 0
	for c in sources:
		if made >= extra_sources:
			break
		if assigned[c] == "river" or _touches(c, assigned, ["river"]):
			continue  # an earlier river already passes here
		var start: Array[Vector2i] = [c]
		if _carve_path(start, assigned, elev_rank, ["ocean", "coast", "lake", "river"], true):
			made += 1


## Cheapest downhill-preferring path from `starts` to any tile whose terrain is in
## `goals`; its land tiles become river. With `include_start`, the start tiles
## become river too. Returns false when no goal is reachable.
static func _carve_path(starts: Array[Vector2i], assigned: Dictionary, elev_rank: Dictionary,
		goals: Array, include_start: bool = false) -> bool:
	var start_set := {}
	for s in starts:
		start_set[s] = true
	var dist := {}
	var prev := {}
	var heap: Array = []
	for s in starts:
		dist[s] = 0.0
		_heap_push(heap, [0.0, s.y, s.x, s])
	var goal: Variant = null
	while not heap.is_empty():
		var item: Array = _heap_pop(heap)
		var cost: float = item[0]
		var c: Vector2i = item[3]
		if cost > float(dist.get(c, INF)):
			continue
		if not start_set.has(c) and goals.has(assigned[c]):
			goal = c
			break
		for nb in Hex.neighbors(c):
			if not assigned.has(nb) or start_set.has(nb):
				continue
			var t: String = assigned[nb]
			if not goals.has(t) and (t == "ocean" or t == "coast" or t == "lake"):
				continue  # never cut through water that isn't a goal
			var step := 1.0 + 4.0 * float(elev_rank[nb])
			if t == "mountains":
				step += 6.0
			var nd := cost + step
			if nd < float(dist.get(nb, INF)):
				dist[nb] = nd
				prev[nb] = c
				_heap_push(heap, [nd, nb.y, nb.x, nb])
	if goal == null:
		return false
	var walk: Vector2i = goal
	while prev.has(walk):
		walk = prev[walk]
		if start_set.has(walk):
			if include_start:
				assigned[walk] = "river"
			break
		assigned[walk] = "river"
	return true


static func _place_lairs(map: HexMap, coords: Array[Vector2i], setup: Dictionary, map_seed: int) -> void:
	var eligible: Array = setup.get("savage_spawn_terrains", [])
	var candidates: Array[Vector2i] = []
	for c in coords:
		if eligible.has(map.get_tile(c).terrain):
			candidates.append(c)

	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	_shuffle(candidates, rng)

	var want := int(setup.get("savage_spawn_tiles", 8))
	var min_dist := int(setup.get("savage_spawn_min_distance", 5))
	var placed: Array[Vector2i] = []
	for c in candidates:
		if placed.size() >= want:
			break
		var far_enough := true
		for p in placed:
			if Hex.distance(c, p) < min_dist:
				far_enough = false
				break
		if far_enough:
			placed.append(c)
	# Small or crowded maps: fill the rest ignoring spacing.
	for c in candidates:
		if placed.size() >= want:
			break
		if not placed.has(c):
			placed.append(c)
	for c in placed:
		map.get_tile(c).savage_spawn = true


## Deterministic Fisher-Yates shuffle.
static func _shuffle(list: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := list[i]
		list[i] = list[j]
		list[j] = tmp


## True when any on-map neighbour of `c` has a terrain in `terrains`.
static func _touches(c: Vector2i, assigned: Dictionary, terrains: Array) -> bool:
	for nb in Hex.neighbors(c):
		if terrains.has(assigned.get(nb, "")):
			return true
	return false


## All tiles of `terrain` connected to `start`.
static func _flood(start: Vector2i, assigned: Dictionary, terrain: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = [start]
	var seen := {start: true}
	var i := 0
	while i < out.size():
		for nb in Hex.neighbors(out[i]):
			if not seen.has(nb) and assigned.get(nb, "") == terrain:
				seen[nb] = true
				out.append(nb)
		i += 1
	return out


## Min-heap on [cost, y, x, coord]; ties broken by coordinate for determinism.
static func _less(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] < b[0]
	if a[1] != b[1]:
		return a[1] < b[1]
	return a[2] < b[2]


static func _heap_push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		@warning_ignore("integer_division")
		var parent := (i - 1) / 2
		if not _less(heap[i], heap[parent]):
			break
		var tmp: Array = heap[i]
		heap[i] = heap[parent]
		heap[parent] = tmp
		i = parent


static func _heap_pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return top
	heap[0] = last
	var i := 0
	while true:
		var l := 2 * i + 1
		var r := l + 1
		var smallest := i
		if l < heap.size() and _less(heap[l], heap[smallest]):
			smallest = l
		if r < heap.size() and _less(heap[r], heap[smallest]):
			smallest = r
		if smallest == i:
			break
		var tmp: Array = heap[i]
		heap[i] = heap[smallest]
		heap[smallest] = tmp
		i = smallest
	return top


static func _make_noise(noise_seed: int, freq: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = freq
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	return noise


static func _unassigned(coords: Array[Vector2i], assigned: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in coords:
		if not assigned.has(c):
			out.append(c)
	return out


## Ascending by value; ties broken by coordinate so results never depend on sort stability.
static func _sorted_by(list: Array[Vector2i], values: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(list)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var va: float = values[a]
		var vb: float = values[b]
		if va != vb:
			return va < vb
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	return out


## Map each coord to its rank in [0, 1] by value.
static func _ranks(list: Array[Vector2i], values: Dictionary) -> Dictionary:
	var sorted := _sorted_by(list, values)
	var out := {}
	var denom := maxf(1.0, float(sorted.size() - 1))
	for i in sorted.size():
		out[sorted[i]] = float(i) / denom
	return out
