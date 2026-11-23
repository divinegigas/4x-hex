## Converts between axial hex coords and 2D pixel positions (pointy-top).
## `y_scale` < 1 squashes the grid vertically for an isometric (tilted camera) look;
## all conversions stay exact inverses of each other.
extends RefCounted

const Hex = preload("res://src/sim/hex.gd")
const SQRT3 := 1.7320508075688772

## Distance from a hex's centre to any corner, in world pixels (before squash).
var size: float
## Vertical squash: 1.0 = top-down, ~0.6 = isometric.
var y_scale: float


func _init(hex_size: float = 48.0, vertical_scale: float = 1.0) -> void:
	size = hex_size
	y_scale = vertical_scale


func to_pixel(c: Vector2i) -> Vector2:
	return Vector2(size * (SQRT3 * c.x + SQRT3 / 2.0 * c.y), size * 1.5 * c.y * y_scale)


## Ground-plane pixel -> hex (ignores elevation; see IsoMapGeometry.pick for tall tiles).
func to_hex(p: Vector2) -> Vector2i:
	var y := p.y / y_scale
	var q := (SQRT3 / 3.0 * p.x - y / 3.0) / size
	var r := (2.0 / 3.0 * y) / size
	return Hex.round_axial(q, r)


## Corners in order: 0 upper-right, 1 lower-right, 2 bottom, 3 lower-left, 4 upper-left, 5 top.
func corners(c: Vector2i, scale: float = 1.0) -> PackedVector2Array:
	var center := to_pixel(c)
	var pts := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)
		pts.append(center + Vector2(cos(angle), sin(angle) * y_scale) * size * scale)
	return pts
