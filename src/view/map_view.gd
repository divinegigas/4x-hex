## Draws the hex map for the current season and handles tile selection.
## Placeholder art: one flat colour per terrain per season (data/terrain.json).
extends Node2D

signal tile_selected(coord: Vector2i)

const HexLayout = preload("res://src/view/hex_layout.gd")
const GameState = preload("res://src/sim/game_state.gd")

const OUTLINE_COLOR := Color(0, 0, 0, 0.35)
const SELECT_COLOR := Color("#e8c15a")
const LAIR_COLOR := Color("#5b0f12")
const LAIR_RIM_COLOR := Color("#c23b2e")
const RAVAGED_COLOR := Color("#2a1208")

var layout := HexLayout.new(48.0)
var state: GameState
var selected: Vector2i
var has_selection := false


func bind(game_state: GameState) -> void:
	state = game_state
	state.season_changed.connect(_on_season_changed)
	has_selection = false
	queue_redraw()


## World-space rectangle covering the whole map.
func world_rect() -> Rect2:
	if state == null or state.map.tile_count() == 0:
		return Rect2()
	var rect := Rect2(layout.to_pixel(state.map.tiles.keys()[0]), Vector2.ZERO)
	for c in state.map.tiles:
		rect = rect.expand(layout.to_pixel(c))
	return rect.grow(layout.size)


## Select the tile under a world position. Returns true if a tile was hit.
func select_at_world(world_pos: Vector2) -> bool:
	if state == null:
		return false
	var c := layout.to_hex(to_local(world_pos))
	if not state.map.has_tile(c):
		return false
	selected = c
	has_selection = true
	queue_redraw()
	tile_selected.emit(c)
	return true


func _on_season_changed(_season_id: String) -> void:
	queue_redraw()


func _draw() -> void:
	if state == null:
		return
	var season := state.season()
	for c in state.map.tiles:
		var tile = state.map.tiles[c]
		var pts := layout.corners(c)
		var color := state.data.terrain_color(tile.terrain, season)
		if tile.is_ravaged():
			color = color.darkened(0.35)
		draw_colored_polygon(pts, color)
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, OUTLINE_COLOR, 1.5)

		var center := layout.to_pixel(c)
		if tile.is_ravaged():
			var s := layout.size * 0.45
			draw_line(center + Vector2(-s, -s), center + Vector2(s, s), RAVAGED_COLOR, 3.0)
			draw_line(center + Vector2(-s, s), center + Vector2(s, -s), RAVAGED_COLOR, 3.0)
		if tile.savage_spawn:
			draw_circle(center, layout.size * 0.24, LAIR_COLOR)
			draw_arc(center, layout.size * 0.24, 0.0, TAU, 24, LAIR_RIM_COLOR, 2.5)

	if has_selection:
		var sel := layout.corners(selected, 0.92)
		sel.append(sel[0])
		draw_polyline(sel, SELECT_COLOR, 4.0)
