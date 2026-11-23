## Entry point: wires the simulation (src/sim) to the view (src/view) and HUD (src/ui).
extends Node

const GameData = preload("res://src/sim/game_data.gd")
const GameState = preload("res://src/sim/game_state.gd")
const MapGenerator = preload("res://src/sim/map_generator.gd")
const GameSetup = preload("res://src/sim/game_setup.gd")
const MapView = preload("res://src/view/map_view.gd")
const CameraController = preload("res://src/view/camera_controller.gd")
const Hud = preload("res://src/ui/hud.gd")

var data: GameData
var state: GameState
var map_view: MapView
var camera: CameraController
var hud: Hud


func _ready() -> void:
	data = GameData.new()
	for err in data.errors:
		push_error(err)

	map_view = MapView.new()
	add_child(map_view)
	camera = CameraController.new()
	add_child(camera)
	camera.make_current()
	hud = Hud.new()
	add_child(hud)

	camera.ui_hit_test = hud.covers
	camera.tapped.connect(_on_tapped)
	map_view.tile_selected.connect(_on_tile_selected)
	hud.end_round_pressed.connect(_on_end_round)
	hud.new_map_pressed.connect(func() -> void: _start_game(0))
	hud.ravage_pressed.connect(_on_ravage)

	_start_game(int(data.setup.get("seed", 0)))


## map_seed 0 picks a random seed.
func _start_game(map_seed: int) -> void:
	if map_seed == 0:
		map_seed = randi_range(1, 2147483647)
	var map := MapGenerator.generate(data, map_seed)
	state = GameSetup.start(data, map)
	state.season_changed.connect(_on_season_changed)
	map_view.bind(state)
	camera.frame(map_view.world_rect())
	hud.hide_tile()
	_refresh_round()
	# Start looking at the capital, with it selected so its numbers are visible.
	if not state.cities.is_empty():
		var capital := state.cities[0]
		camera.position = map_view.world_pos_of(capital.coord)
		camera.zoom = Vector2.ONE
		map_view.select_at_world(map_view.world_pos_of(capital.coord))
	print("New map, seed %d" % map_seed)


func _on_tapped(screen_pos: Vector2) -> void:
	map_view.select_at_world(camera.screen_to_world(screen_pos))


func _on_end_round() -> void:
	state.end_round()


func _on_season_changed(_season_id: String) -> void:
	_refresh_round()
	map_view.queue_redraw()
	if map_view.has_selection:
		_on_tile_selected(map_view.selected)


func _on_tile_selected(c: Vector2i) -> void:
	hud.show_tile(_describe_tile(c))


func _on_ravage() -> void:
	if not map_view.has_selection:
		return
	state.map.get_tile(map_view.selected).ravaged_seasons = 2
	map_view.queue_redraw()
	_on_tile_selected(map_view.selected)


func _refresh_round() -> void:
	var player := state.get_faction(0)
	if player != null:
		hud.show_treasury("Gold %d  ·  Wood %d  ·  Stone %d" % [
			roundi(player.treasury["gold"]), roundi(player.treasury["wood"]), roundi(player.treasury["stone"])])
	hud.show_round("Year %d  ·  %s  ·  Round %d" % [
		state.year(), data.season_name(state.season()), state.round_number])


func _describe_tile(c: Vector2i) -> String:
	var tile := state.map.get_tile(c)
	var s := tile.stats(data, state.season())
	var lines: PackedStringArray = []
	lines.append("%s   (%d, %d)" % [data.terrain_name(tile.terrain), c.x, c.y])
	if s["passable"]:
		lines.append("Move cost: %.1f" % s["move_cost"])
	else:
		lines.append("Impassable")
	lines.append("Food %.1f · Wood %.1f · Stone %.1f · Gold %.1f" % [s["food"], s["wood"], s["stone"], s["gold"]])
	if tile.owner_id < 0:
		lines.append("Unclaimed")
	else:
		var owner_name := state.get_faction(tile.owner_id).faction_name
		var home := state.get_city(tile.city_id)
		lines.append("%s land%s" % [owner_name, (" (%s)" % home.city_name) if home != null else ""])
	if tile.improvement != "":
		lines.append("Improvement: %s" % tile.improvement)
	if tile.savage_spawn:
		lines.append("Savage lair")
	if tile.is_ravaged():
		lines.append("Ravaged: %d more season(s)" % tile.ravaged_seasons)
	var city := state.city_at(c)
	if city != null:
		lines.append("")
		lines.append_array(_describe_city(city))
	return "\n".join(lines)


## The city's numbers for the round in progress, with the math shown.
func _describe_city(city) -> PackedStringArray:
	var r := state.project_city(city)
	var prod: Dictionary = r["production"]
	var lines: PackedStringArray = []
	lines.append("— %s —" % city.city_name)
	lines.append("Population %.1f  →  %.1f" % [r["population_before"], r["population_after"]])
	var cap: float = r["food_cap"]
	lines.append("Food %.1f / %s   +%.1f grown  −%.1f eaten  →  %.1f" % [
		r["food_before"], ("%d" % cap) if cap < INF else "∞", prod["food"], r["food_eaten"], r["food_after"]])
	if float(r["food_wasted"]) > 0.0:
		lines.append("   %.1f food spoils (storage full)" % r["food_wasted"])
	if r["starving"]:
		lines.append("   STARVING: short %.1f food, population shrinks" % r["food_shortfall"])
	lines.append("Manpower %.1f  (+%.1f)" % [city.manpower, r["manpower_produced"]])
	lines.append("Per round: Gold +%.1f · Wood +%.1f · Stone +%.1f" % [prod["gold"], prod["wood"], prod["stone"]])
	lines.append("(%d tiles worked · %s)" % [r["tiles_worked"], data.season_name(state.season())])
	return lines
