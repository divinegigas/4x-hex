## Axial hex-coordinate math for a pointy-top grid. Coordinates are Vector2i(q, r).
## Pure static functions: safe to use from simulation, view and tests.
## Reference: https://www.redblobgames.com/grids/hexagons/
extends RefCounted

## Neighbour offsets, in ring-walk order (east, then counter-clockwise).
const DIRECTIONS := [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]


static func neighbor(c: Vector2i, dir: int) -> Vector2i:
	var d: Vector2i = DIRECTIONS[posmod(dir, 6)]
	return c + d


static func neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRECTIONS:
		out.append(c + d)
	return out


static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	@warning_ignore("integer_division")
	return (absi(d.x) + absi(d.x + d.y) + absi(d.y)) / 2


## Every hex within `radius` steps of `center`, center included.
static func within(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dq in range(-radius, radius + 1):
		for dr in range(maxi(-radius, -dq - radius), mini(radius, -dq + radius) + 1):
			out.append(center + Vector2i(dq, dr))
	return out


## The hexes exactly `radius` steps from `center`.
static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if radius <= 0:
		out.append(center)
		return out
	var start_dir: Vector2i = DIRECTIONS[4]
	var c: Vector2i = center + start_dir * radius
	for i in 6:
		var step: Vector2i = DIRECTIONS[i]
		for _j in radius:
			out.append(c)
			c += step
	return out


## Rectangular maps are stored as "odd-r" offset rows (odd rows shifted right).
static func offset_to_axial(col: int, row: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(col - (row - (row & 1)) / 2, row)


static func axial_to_offset(c: Vector2i) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(c.x + (c.y - (c.y & 1)) / 2, c.y)


## Round fractional axial coordinates to the nearest hex.
static func round_axial(q: float, r: float) -> Vector2i:
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))
