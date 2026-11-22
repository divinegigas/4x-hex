## Builds a seeded, deterministic HexMap from setup data.
## Terrain is assigned by noise *rank*, not raw thresholds, so every map has
## the terrain mix set in setup.json regardless of how the noise happens to fall.
extends RefCounted

const Hex = preload("res://src/sim/hex.gd")
const HexMap = preload("res://src/sim/hex_map.gd")
const Tile = preload("res://src/sim/tile.gd")


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
	var elev := {}
	var moist := {}
	for row in height:
		for col in width:
			var c := Hex.offset_to_axial(col, row)
			# Sample noise in roughly-Euclidean space so features aren't skewed.
			var x: float = col + 0.5 * (row & 1)
			var y: float = row * 0.866
			coords.append(c)
			elev[c] = elev_noise.get_noise_2d(x, y)
			moist[c] = moist_noise.get_noise_2d(x, y)

	var n := coords.size()
	var elev_rank := _ranks(coords, elev)
	var moist_rank := _ranks(coords, moist)
	var by_elev := _sorted_by(coords, elev)
	var assigned := {}

	var lake_n := int(n * float(gen.get("lake_fraction", 0.08)))
	var mountain_n := int(n * float(gen.get("mountain_fraction", 0.07)))
	var hills_n := int(n * float(gen.get("hills_fraction", 0.12)))
	for i in lake_n:
		assigned[by_elev[i]] = "lake"
	for i in mountain_n:
		assigned[by_elev[n - 1 - i]] = "mountains"
	for i in hills_n:
		assigned[by_elev[n - 1 - mountain_n - i]] = "hills"

	# Swamps: wet and low.
	var rest := _unassigned(coords, assigned)
	var wetness := {}
	for c in rest:
		wetness[c] = float(moist_rank[c]) - 0.5 * float(elev_rank[c])
	var by_wet := _sorted_by(rest, wetness)
	by_wet.reverse()
	var swamp_n := mini(int(n * float(gen.get("swamp_fraction", 0.07))), by_wet.size())
	for i in swamp_n:
		assigned[by_wet[i]] = "swamp"

	# Forest on the wettest of what's left; plains on the driest; grassland between.
	rest = _unassigned(coords, assigned)
	var by_moist := _sorted_by(rest, moist)
	by_moist.reverse()
	var forest_n := mini(int(n * float(gen.get("forest_fraction", 0.22))), by_moist.size())
	var plains_n := int((by_moist.size() - forest_n) * float(gen.get("plains_fraction_of_rest", 0.4)))
	for i in by_moist.size():
		var c: Vector2i = by_moist[i]
		if i < forest_n:
			assigned[c] = "forest"
		elif i >= by_moist.size() - plains_n:
			assigned[c] = "plains"
		else:
			assigned[c] = "grassland"

	for c in coords:
		map.add_tile(Tile.new(c, str(assigned[c])))

	_place_lairs(map, coords, setup, map_seed)
	return map


static func _place_lairs(map: HexMap, coords: Array[Vector2i], setup: Dictionary, map_seed: int) -> void:
	var eligible: Array = setup.get("savage_spawn_terrains", [])
	var candidates: Array[Vector2i] = []
	for c in coords:
		if eligible.has(map.get_tile(c).terrain):
			candidates.append(c)

	# Deterministic Fisher-Yates shuffle.
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

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
