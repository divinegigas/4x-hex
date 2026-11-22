## Touch-first camera: one-finger drag pans, two-finger pinch zooms, a short
## touch without movement is a tap. Mouse wheel zooms on desktop; mouse
## clicks arrive as touches via the emulate_touch_from_mouse project setting.
extends Camera2D

signal tapped(screen_pos: Vector2)

@export var min_zoom := 0.25
@export var max_zoom := 2.5
## A touch that moves further than this (in screen pixels) is a drag, not a tap.
@export var tap_slop := 14.0

## Returns true when a screen position is over UI that should eat the touch.
var ui_hit_test: Callable

var _touches := {}  # touch index -> screen position
var _drag_distance := 0.0
var _pinch_start_dist := 0.0
var _pinch_start_zoom := 1.0
var _bounds := Rect2()


func set_bounds(rect: Rect2) -> void:
	_bounds = rect
	_clamp_position()


## Centre on the map and zoom so most of it is visible.
func frame(rect: Rect2) -> void:
	set_bounds(rect)
	position = rect.get_center()
	var vp := get_viewport_rect().size
	var fit := minf(vp.x / maxf(rect.size.x, 1.0), vp.y / maxf(rect.size.y, 1.0))
	var z := clampf(maxf(fit, 0.5), min_zoom, max_zoom)
	zoom = Vector2(z, z)


## Screen (viewport) position -> world position. Computed directly from
## position and zoom so it is correct within the same frame as a zoom change.
func screen_to_world(screen_pos: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	return position + (screen_pos - vp * 0.5) / zoom


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton and event.pressed:
		if _over_ui(event.position):
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, zoom.x * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, zoom.x / 1.1)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _over_ui(event.position):
			return
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_drag_distance = 0.0
		elif _touches.size() == 2:
			_start_pinch()
		get_viewport().set_input_as_handled()
	elif _touches.has(event.index):
		var was_single := _touches.size() == 1
		_touches.erase(event.index)
		if was_single and _drag_distance < tap_slop:
			tapped.emit(event.position)
		get_viewport().set_input_as_handled()


func _on_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	_touches[event.index] = event.position
	if _touches.size() == 1:
		_drag_distance += event.relative.length()
		position -= event.relative / zoom
		_clamp_position()
	elif _touches.size() == 2:
		_update_pinch()
	get_viewport().set_input_as_handled()


func _start_pinch() -> void:
	var pts: Array = _touches.values()
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[1]
	_pinch_start_dist = a.distance_to(b)
	_pinch_start_zoom = zoom.x
	_drag_distance = INF  # Lifting fingers after a pinch is never a tap.


func _update_pinch() -> void:
	if _pinch_start_dist < 1.0:
		return
	var pts: Array = _touches.values()
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[1]
	var target := _pinch_start_zoom * a.distance_to(b) / _pinch_start_dist
	_zoom_at((a + b) * 0.5, target)


## Zoom to `target_zoom`, keeping the world point under `screen_pos` fixed.
func _zoom_at(screen_pos: Vector2, target_zoom: float) -> void:
	var before := screen_to_world(screen_pos)
	var z := clampf(target_zoom, min_zoom, max_zoom)
	zoom = Vector2(z, z)
	position += before - screen_to_world(screen_pos)
	_clamp_position()


func _clamp_position() -> void:
	if _bounds.has_area():
		position = position.clamp(_bounds.position, _bounds.end)


func _over_ui(screen_pos: Vector2) -> bool:
	return ui_hit_test.is_valid() and bool(ui_hit_test.call(screen_pos))
