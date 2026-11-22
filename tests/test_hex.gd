extends "res://tests/test_case.gd"

const Hex = preload("res://src/sim/hex.gd")
const HexLayout = preload("res://src/view/hex_layout.gd")


func test_distance() -> void:
	check_eq(Hex.distance(Vector2i(0, 0), Vector2i(0, 0)), 0)
	check_eq(Hex.distance(Vector2i(0, 0), Vector2i(3, -1)), 3)
	check_eq(Hex.distance(Vector2i(-2, 1), Vector2i(2, -1)), 4)
	check_eq(Hex.distance(Vector2i(1, 2), Vector2i(-1, -2)), 6)


func test_neighbors_are_six_unique_adjacent() -> void:
	var c := Vector2i(4, -3)
	var ns := Hex.neighbors(c)
	check_eq(ns.size(), 6)
	var seen := {}
	for n in ns:
		check_eq(Hex.distance(c, n), 1, "neighbour %s" % n)
		seen[n] = true
	check_eq(seen.size(), 6)


func test_within_and_ring_counts() -> void:
	check_eq(Hex.within(Vector2i.ZERO, 0).size(), 1)
	check_eq(Hex.within(Vector2i.ZERO, 2).size(), 19)
	check_eq(Hex.within(Vector2i(5, 5), 3).size(), 37)
	var r := Hex.ring(Vector2i(1, 1), 3)
	check_eq(r.size(), 18)
	for c in r:
		check_eq(Hex.distance(Vector2i(1, 1), c), 3)


func test_offset_round_trip() -> void:
	for row in range(-3, 6):
		for col in range(-3, 6):
			var a := Hex.offset_to_axial(col, row)
			check_eq(Hex.axial_to_offset(a), Vector2i(col, row))


func test_offset_rows_are_adjacent() -> void:
	# Odd-r: the tile below-right of (0,0) in offset space is a neighbour.
	check_eq(Hex.distance(Hex.offset_to_axial(0, 0), Hex.offset_to_axial(0, 1)), 1)
	check_eq(Hex.distance(Hex.offset_to_axial(1, 1), Hex.offset_to_axial(1, 2)), 1)


func test_layout_round_trip() -> void:
	var layout := HexLayout.new(48.0)
	for c in Hex.within(Vector2i(2, -1), 4):
		var p := layout.to_pixel(c)
		check_eq(layout.to_hex(p), c, "centre")
		# Points well inside the hex still map back to it.
		check_eq(layout.to_hex(p + Vector2(20, 10)), c, "offset point")
		for corner in layout.corners(c, 0.9):
			check_eq(layout.to_hex(corner), c, "near corner")
