## Draws the hex map in 2.5D isometric for the current season and handles tile selection.
## Tiles are raised blocks (terrain elevation) drawn back to front.
## Placeholder art: one flat colour per terrain per season (data/terrain.json);
## view settings come from data/view.json.
extends Node2D

signal tile_selected(coord: Vector2i)

const HexLayout = preload("res://src/view/hex_layout.gd")
const IsoMapGeometry = preload("res://src/view/iso_map_geometry.gd")
const GameState = preload("res://src/sim/game_state.gd")

const VIEW_CONFIG_PATH := "res://data/view.json"
const OUTLINE_COLOR := Color(0, 0, 0, 0.35)
const SELECT_COLOR := Color("#e8c15a")
const LAIR_COLOR := Color("#5b0f12")
const LAIR_RIM_COLOR := Color("#c23b2e")
const RAVAGED_COLOR := Color("#2a1208")
const STONE_COLOR := Color("#3a3640")
const STONE_DARK := Color("#24212a")
const ROOF_COLOR := Color("#1a1719")

var layout: HexLayout
var geometry: IsoMapGeometry
var state: GameState
var selected: Vector2i
var has_selection := false
var _shade_left := 0.25
var _shade_right := 0.45


func _init() -> void:
	var cfg := load_view_config()
	layout = HexLayout.new(float(cfg.get("hex_size", 48.0)), float(cfg.get("iso_y_scale", 0.6)))
	geometry = IsoMapGeometry.new(layout, float(cfg.get("height_unit", 10.0)), float(cfg.get("base_thickness", 6.0)))
	_shade_left = float(cfg.get("wall_shade_left", 0.25))
	_shade_right = float(cfg.get("wall_shade_right", 0.45))


static func load_view_config() -> Dictionary:
	if not FileAccess.file_exists(VIEW_CONFIG_PATH):
		push_warning("Missing %s, using default view settings" % VIEW_CONFIG_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(VIEW_CONFIG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Could not parse %s, using default view settings" % VIEW_CONFIG_PATH)
		return {}
	return parsed


func bind(game_state: GameState) -> void:
	state = game_state
	state.season_changed.connect(_on_season_changed)
	has_selection = false
	geometry.build(state.map.tiles.keys(), func(c: Vector2i) -> float:
		return state.data.terrain_elevation(state.map.get_tile(c).terrain)
	)
	queue_redraw()


## Centre of a tile's raised top face in world space.
func world_pos_of(c: Vector2i) -> Vector2:
	return to_global(geometry.centers.get(c, Vector2.ZERO))


## World-space rectangle covering the whole map.
func world_rect() -> Rect2:
	return geometry.bounds()


## Select the tile drawn under a world position. Returns true if a tile was hit.
func select_at_world(world_pos: Vector2) -> bool:
	if state == null:
		return false
	var hit: Variant = geometry.pick(to_local(world_pos))
	if hit == null:
		return false
	selected = hit
	has_selection = true
	queue_redraw()
	tile_selected.emit(selected)
	return true


func _on_season_changed(_season_id: String) -> void:
	queue_redraw()


func _draw() -> void:
	if state == null:
		return
	var season := state.season()
	for c in geometry.order:
		var tile = state.map.get_tile(c)
		var color := state.data.terrain_color(tile.terrain, season)
		if tile.is_ravaged():
			color = color.darkened(0.35)
		var w: Array = geometry.walls[c]
		draw_colored_polygon(w[0], color.darkened(_shade_left))
		draw_colored_polygon(w[1], color.darkened(_shade_right))
		var top: PackedVector2Array = geometry.tops[c]
		draw_colored_polygon(top, color)
		var loop := top.duplicate()
		loop.append(top[0])
		draw_polyline(loop, OUTLINE_COLOR, 1.5)

		var center: Vector2 = geometry.centers[c]
		if tile.is_ravaged():
			var sx := layout.size * 0.45
			var sy := sx * layout.y_scale
			draw_line(center + Vector2(-sx, -sy), center + Vector2(sx, sy), RAVAGED_COLOR, 3.0)
			draw_line(center + Vector2(-sx, sy), center + Vector2(sx, -sy), RAVAGED_COLOR, 3.0)
		if tile.savage_spawn:
			_draw_lair(center)
		if tile.owner_id >= 0:
			_draw_border(top, center, _faction_color(tile.owner_id))

	# Cities after all tiles so their towers stand above the terrain around them.
	for city in state.cities:
		_draw_city(geometry.centers[city.coord], _faction_color(city.owner_id))

	# Drawn last so the selection stays visible even behind tall terrain.
	if has_selection:
		var sel: PackedVector2Array = geometry.tops[selected]
		var outline := sel.duplicate()
		outline.append(sel[0])
		draw_polyline(outline, SELECT_COLOR, 4.0)


func _faction_color(faction_id: int) -> Color:
	var f = state.get_faction(faction_id)
	if f == null:
		return Color.WHITE
	return Color.html(f.color_html)


## Territory: an inset outline of the top face in the owner's colour.
func _draw_border(top: PackedVector2Array, center: Vector2, color: Color) -> void:
	var inset := PackedVector2Array()
	for p in top:
		inset.append(center + (p - center) * 0.86)
	inset.append(inset[0])
	draw_polyline(inset, Color(color, 0.85), 2.5)


## Placeholder city: a stone keep with two towers and a banner in the owner's colour.
func _draw_city(center: Vector2, banner: Color) -> void:
	var s := layout.size
	var base_y := center.y + s * 0.18
	var hall := Rect2(center.x - s * 0.38, base_y - s * 0.42, s * 0.76, s * 0.42)
	draw_rect(hall, STONE_COLOR)
	draw_colored_polygon(PackedVector2Array([
		Vector2(hall.position.x - s * 0.05, hall.position.y),
		Vector2(center.x, hall.position.y - s * 0.28),
		Vector2(hall.end.x + s * 0.05, hall.position.y),
	]), ROOF_COLOR)
	for side in [-1.0, 1.0]:
		var tx: float = center.x + side * s * 0.42
		var tower := Rect2(tx - s * 0.12, base_y - s * 0.72, s * 0.24, s * 0.72)
		draw_rect(tower, STONE_DARK)
		draw_colored_polygon(PackedVector2Array([
			Vector2(tower.position.x - s * 0.03, tower.position.y),
			Vector2(tx, tower.position.y - s * 0.22),
			Vector2(tower.end.x + s * 0.03, tower.position.y),
		]), ROOF_COLOR)
	draw_rect(Rect2(center.x - s * 0.08, base_y - s * 0.2, s * 0.16, s * 0.2), ROOF_COLOR)  # gate
	var pole_top := Vector2(center.x, hall.position.y - s * 0.62)
	draw_line(Vector2(center.x, hall.position.y - s * 0.26), pole_top, ROOF_COLOR, 2.0)
	draw_colored_polygon(PackedVector2Array([
		pole_top, pole_top + Vector2(s * 0.3, s * 0.07), pole_top + Vector2(0, s * 0.15),
	]), banner)


## A lair is a dark pit: an ellipse lying flat on the tile.
func _draw_lair(center: Vector2) -> void:
	var r := layout.size * 0.26
	draw_set_transform(center, 0.0, Vector2(1.0, layout.y_scale))
	draw_circle(Vector2.ZERO, r, LAIR_COLOR)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, LAIR_RIM_COLOR, 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
