## Precomputed isometric shapes for every tile: the raised top face, the two
## visible side walls, back-to-front draw order and hit testing.
## Pure (no Nodes) so it can be tested headless. Rebuild when elevations change.
extends RefCounted

const HexLayout = preload("res://src/view/hex_layout.gd")

var layout: HexLayout
var height_unit: float
var base_thickness: float

## Coords sorted back (top of screen) to front.
var order: Array[Vector2i] = []
## coord -> PackedVector2Array, the raised top face.
var tops := {}
## coord -> [left wall, right wall], each a PackedVector2Array quad.
var walls := {}
## coord -> Vector2, centre of the raised top face.
var centers := {}


func _init(hex_layout: HexLayout, unit: float = 10.0, base: float = 6.0) -> void:
	layout = hex_layout
	height_unit = unit
	base_thickness = base


## `elevation_of` maps a coord to its terrain elevation.
func build(coords: Array, elevation_of: Callable) -> void:
	order.clear()
	tops.clear()
	walls.clear()
	centers.clear()
	for c in coords:
		order.append(c)
	# Rows further up the screen first; within a row, left to right.
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	for c in order:
		var lift: float = float(elevation_of.call(c)) * height_unit
		var up := Vector2(0, -lift)
		var top := layout.corners(c)
		for i in top.size():
			top[i] += up
		var drop := Vector2(0, lift + base_thickness)
		tops[c] = top
		# Only the two lower slanted edges show walls; the vertical side edges
		# extrude straight down and have no visible area.
		walls[c] = [_quad(top[2], top[3], drop), _quad(top[1], top[2], drop)]
		centers[c] = layout.to_pixel(c) + up


## The front-most tile whose top face or walls contain `p`, or null.
func pick(p: Vector2) -> Variant:
	for i in range(order.size() - 1, -1, -1):
		var c: Vector2i = order[i]
		if Geometry2D.is_point_in_polygon(p, tops[c]):
			return c
		var w: Array = walls[c]
		if Geometry2D.is_point_in_polygon(p, w[0]) or Geometry2D.is_point_in_polygon(p, w[1]):
			return c
	return null


## World-space rectangle covering every top face and wall.
func bounds() -> Rect2:
	if order.is_empty():
		return Rect2()
	var first: PackedVector2Array = tops[order[0]]
	var rect := Rect2(first[0], Vector2.ZERO)
	for c in order:
		for p in tops[c]:
			rect = rect.expand(p)
		for w in walls[c]:
			for p in w:
				rect = rect.expand(p)
	return rect


static func _quad(a: Vector2, b: Vector2, drop: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, b, b + drop, a + drop])
