## Converts between axial hex coords and 2D pixel positions (pointy-top).
extends RefCounted

const Hex = preload("res://src/sim/hex.gd")
const SQRT3 := 1.7320508075688772

## Distance from a hex's centre to any corner, in world pixels.
var size: float


func _init(hex_size: float = 48.0) -> void:
	size = hex_size


func to_pixel(c: Vector2i) -> Vector2:
	return Vector2(size * (SQRT3 * c.x + SQRT3 / 2.0 * c.y), size * 1.5 * c.y)


func to_hex(p: Vector2) -> Vector2i:
	var q := (SQRT3 / 3.0 * p.x - p.y / 3.0) / size
	var r := (2.0 / 3.0 * p.y) / size
	return Hex.round_axial(q, r)


func corners(c: Vector2i, scale: float = 1.0) -> PackedVector2Array:
	var center := to_pixel(c)
	var pts := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)
		pts.append(center + Vector2(cos(angle), sin(angle)) * size * scale)
	return pts
