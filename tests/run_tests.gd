## Headless test runner. From the project root:
##   godot --headless --import          (first run only, or after adding files)
##   godot --headless --script res://tests/run_tests.gd
## Runs every `test_*` method in TEST_FILES; exit code 1 on any failure.
extends SceneTree

const TEST_FILES := [
	"res://tests/test_hex.gd",
	"res://tests/test_seasons.gd",
	"res://tests/test_map.gd",
	"res://tests/test_iso.gd",
	"res://tests/test_economy.gd",
	"res://tests/test_condition.gd",
]


func _initialize() -> void:
	var total := 0
	var failed := 0
	for path in TEST_FILES:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			failed += 1
			total += 1
			print("FAIL  %s did not load (parse error?)" % path)
			continue
		var suite = script.new()
		for m in script.get_script_method_list():
			var method_name: String = m["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			suite.current = "%s::%s" % [str(path).get_file(), method_name]
			var before: int = suite.failures.size()
			suite.call(method_name)
			if suite.failures.size() > before:
				failed += 1
				print("FAIL  ", suite.current)
				for i in range(before, suite.failures.size()):
					print("      ", suite.failures[i])
			else:
				print("ok    ", suite.current)
	print("\n%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 or total == 0 else 0)
