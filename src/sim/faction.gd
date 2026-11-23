## A faction on the map: for now just identity and a treasury.
## Turn order (Leader stat), AI control and diplomacy join in later build steps.
extends RefCounted

const TREASURY_KEYS := ["wood", "stone", "gold"]

var id: int
var faction_name: String
var race_id: String
## Display colour for borders and banners (html string from races.json).
var color_html: String
var is_player: bool
## Faction-wide stock of wood, stone and gold.
var treasury: Dictionary = {"wood": 0.0, "stone": 0.0, "gold": 0.0}


func _init(faction_id: int = 0, display_name: String = "", race: String = "", color: String = "#ffffff", player: bool = false) -> void:
	id = faction_id
	faction_name = display_name
	race_id = race
	color_html = color
	is_player = player
