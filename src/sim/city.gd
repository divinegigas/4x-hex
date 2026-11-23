## A city: population plus the food and manpower stored in it.
## Its tiles are the map tiles whose city_id is this city's id.
extends RefCounted

var id: int
var city_name: String
var owner_id: int
var coord: Vector2i
var population: float = 1.0
var food: float = 0.0
var manpower: float = 0.0
## True when last round's food ran out (doc section 7: "when food hits zero").
var starving: bool = false
## The Economy report from the last resolved round (empty before the first).
var last_report: Dictionary = {}


func _init(city_id: int = 0, display_name: String = "", owner: int = -1, at: Vector2i = Vector2i.ZERO) -> void:
	id = city_id
	city_name = display_name
	owner_id = owner
	coord = at
