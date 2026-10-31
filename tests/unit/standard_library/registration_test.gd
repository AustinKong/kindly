extends "res://tests/support/library_suite.gd"


func test_registered_functions_match_the_public_api() -> void:
	var names := vm._globals.keys()
	names.sort()
	assert_array(names).is_equal([
		"append",
		"append_front",
		"contains",
		"copy",
		"deque",
		"extend",
		"get",
		"index",
		"insert",
		"keys",
		"len",
		"pop",
		"pop_front",
		"print",
		"remove",
		"reverse",
		"slice",
		"sort",
		"values",
	])
	assert_int(vm._globals["slice"].min_arity).is_equal(1)
	assert_int(vm._globals["slice"].max_arity).is_equal(3)
	assert_int(vm._globals["deque"].min_arity).is_equal(0)
	assert_int(vm._globals["deque"].max_arity).is_equal(1)
