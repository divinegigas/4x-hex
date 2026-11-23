extends "res://tests/test_case.gd"

const Hex = preload("res://src/sim/hex.gd")
const GameData = preload("res://src/sim/game_data.gd")
const HexLayout = preload("res://src/view/hex_layout.gd")
const IsoMapGeometry = preload("res://src/view/iso_map_geometry.gd")


func test_squashed_layout_round_trip() -> void:
	var layout := HexLayout.new(48.0, 0.6)
	for c in Hex.within(Vector2i(1, 2), 4):
		var p := layout.to_pixel(c)
		check_eq(layout.to_hex(p), c, "centre")
		for corner in layout.corners(c, 0.9):
			check_eq(layout.to_hex(corner), c, "near corner")


func test_squash_shrinks_rows() -> void:
	var flat := HexLayout.new(48.0, 1.0)
	var iso := HexLayout.new(48.0, 0.6)
	var c := Vector2i(0, 4)
	check_eq(iso.to_pixel(c).y, flat.to_pixel(c).y * 0.6)
	check_eq(iso.to_pixel(c).x, flat.to_pixel(c).x)


func test_draw_order_is_back_to_front() -> void:
	var geo := IsoMapGeometry.new(HexLayout.new(48.0, 0.6))
	geo.build(Hex.within(Vector2i.ZERO, 3), func(_c: Vector2i) -> float: return 1.0)
	for i in range(1, geo.order.size()):
		var a: Vector2i = geo.order[i - 1]
		var b: Vector2i = geo.order[i]
		check(a.y < b.y or (a.y == b.y and a.x < b.x), "%s before %s" % [a, b])


func test_flat_map_picks_tile_under_centre() -> void:
	var geo := IsoMapGeometry.new(HexLayout.new(48.0, 0.6), 10.0, 6.0)
	var coords := Hex.within(Vector2i.ZERO, 4)
	geo.build(coords, func(_c: Vector2i) -> float: return 1.0)
	for c in coords:
		check_eq(geo.pick(geo.centers[c]), c)


func test_elevation_raises_top_face() -> void:
	var geo := IsoMapGeometry.new(HexLayout.new(48.0, 0.6), 10.0, 6.0)
	geo.build([Vector2i(0, 0), Vector2i(3, 0)], func(c: Vector2i) -> float: return 3.0 if c.x == 3 else 0.0)
	var low: Vector2 = geo.centers[Vector2i(0, 0)]
	var high: Vector2 = geo.centers[Vector2i(3, 0)]
	check_eq(low.y - high.y, 30.0, "3 elevation x 10 units")


func test_tall_front_tile_occludes_tile_behind() -> void:
	# (0,1) is in front of (0,0); raise it enough to cover (0,0)'s lower half.
	var geo := IsoMapGeometry.new(HexLayout.new(48.0, 0.6), 10.0, 6.0)
	geo.build([Vector2i(0, 0), Vector2i(0, 1)], func(c: Vector2i) -> float: return 4.0 if c.y == 1 else 0.0)
	var behind: Vector2 = geo.centers[Vector2i(0, 0)]
	var front_top: PackedVector2Array = geo.tops[Vector2i(0, 1)]
	# Pick a point inside the front tile's raised top that also lies over the back tile.
	var p := behind + Vector2(20, 10)
	check(Geometry2D.is_point_in_polygon(p, front_top), "test point should be on the raised front tile")
	check_eq(geo.pick(p), Vector2i(0, 1))


func test_terrain_elevations_load() -> void:
	var data := GameData.new()
	check(data.errors.is_empty(), ", ".join(data.errors))
	check(data.terrain_elevation("mountains") > data.terrain_elevation("grassland"), "mountains above grassland")
	check(data.terrain_elevation("lake") <= data.terrain_elevation("swamp"), "lakes lowest")
