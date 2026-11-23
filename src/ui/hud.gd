## Phone-friendly HUD, built in code: a top bar (season, round, actions) and a
## bottom tile-info panel. Emits signals; owns no game logic.
extends CanvasLayer

signal end_round_pressed
signal new_map_pressed
signal ravage_pressed

const BUTTON_SIZE := Vector2(170, 60)

var _top_bar: PanelContainer
var _season_label: Label
var _treasury_label: Label
var _tile_panel: PanelContainer
var _tile_label: Label


func _ready() -> void:
	var theme := _make_theme()

	_top_bar = PanelContainer.new()
	_top_bar.theme = theme
	add_child(_top_bar)
	_top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_top_bar.add_child(row)
	_season_label = Label.new()
	_season_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_season_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_season_label)
	_treasury_label = Label.new()
	_treasury_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_treasury_label.add_theme_color_override("font_color", Color("#e8c15a"))
	row.add_child(_treasury_label)
	row.add_child(_make_button("New map", new_map_pressed))
	row.add_child(_make_button("End round", end_round_pressed))

	_tile_panel = PanelContainer.new()
	_tile_panel.theme = theme
	_tile_panel.grow_horizontal = Control.GROW_DIRECTION_END
	_tile_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_tile_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_tile_panel.add_child(col)
	_tile_label = Label.new()
	_tile_label.custom_minimum_size = Vector2(460, 0)
	col.add_child(_tile_label)
	col.add_child(_make_button("Ravage (debug)", ravage_pressed))
	_tile_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	_tile_panel.visible = false


func show_round(text: String) -> void:
	_season_label.text = text


func show_treasury(text: String) -> void:
	_treasury_label.text = text


func show_tile(text: String) -> void:
	_tile_label.text = text
	_tile_panel.visible = true
	# Re-anchor so the panel stays pinned bottom-left as its content changes height.
	_tile_panel.reset_size()
	_tile_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)


func hide_tile() -> void:
	_tile_panel.visible = false


## True when `screen_pos` is over a visible HUD panel, so the map ignores it.
func covers(screen_pos: Vector2) -> bool:
	for panel in [_top_bar, _tile_panel]:
		if panel.visible and panel.get_global_rect().has_point(screen_pos):
			return true
	return false


func _make_button(text: String, sig: Signal) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.pressed.connect(func() -> void: sig.emit())
	return b


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 26
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.07, 0.06, 0.08, 0.88)
	panel.set_corner_radius_all(8)
	panel.set_content_margin_all(12)
	theme.set_stylebox("panel", "PanelContainer", panel)
	return theme
