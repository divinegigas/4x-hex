## Minimal assertion base for headless tests (see tests/run_tests.gd).
extends RefCounted

var failures: PackedStringArray = []
var current := ""


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append("%s: %s" % [current, msg])


func check_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	var same := typeof(actual) == typeof(expected) and actual == expected
	if not same and _is_number(actual) and _is_number(expected):
		same = is_equal_approx(float(actual), float(expected))
	if not same:
		failures.append("%s: expected %s, got %s %s" % [current, str(expected), str(actual), msg])


func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
