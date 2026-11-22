## The world map: a dictionary of Vector2i axial coord -> Tile.
extends RefCounted

const Hex = preload("res://src/sim/hex.gd")
const Tile = preload("res://src/sim/tile.gd")

var width: int
var height: int
var map_seed: int
var tiles: Dictionary = {}


func _init(w: int = 0, h: int = 0, s: int = 0) -> void:
	width = w
	height = h
	map_seed = s


func add_tile(t: Tile) -> void:
	tiles[t.coord] = t


func has_tile(c: Vector2i) -> bool:
	return tiles.has(c)


func get_tile(c: Vector2i) -> Tile:
	return tiles.get(c)


func tile_count() -> int:
	return tiles.size()


## Neighbours of `c` that are on the map.
func neighbors_of(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for n in Hex.neighbors(c):
		if tiles.has(n):
			out.append(n)
	return out


func lair_coords() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in tiles:
		if tiles[c].savage_spawn:
			out.append(c)
	return out


func on_season_flip() -> void:
	for t in tiles.values():
		t.tick_season()
