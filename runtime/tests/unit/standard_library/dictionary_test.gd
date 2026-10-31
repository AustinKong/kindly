extends "res://tests/support/library_suite.gd"


func test_get_and_pop_distinguish_missing_from_none() -> void:
	var values := {"value": 7, "none": null, null: 9}
	assert_that(invoke("get", [values, "none", 99])).is_null()
	assert_that(invoke("get", [values, "missing"])).is_null()
	assert_int(invoke("get", [values, "missing", 99])).is_equal(99)
	assert_int(invoke("pop", [values, null])).is_equal(9)
	assert_int(invoke("pop", [values, "value"])).is_equal(7)
	assert_that(invoke("pop", [values, "none", 99])).is_null()
	assert_that(invoke("pop", [values, "missing"])).is_null()
	assert_int(invoke("pop", [values, "missing", 99])).is_equal(99)
	assert_dict(values).is_empty()


func test_keys_and_values_are_ordered_shallow_snapshots() -> void:
	var values := {"a": [1], "b": 2}
	var keys: Array = invoke("keys", [values])
	var snapshot: Array = invoke("values", [values])
	values["b"] = 9
	values["c"] = 3
	snapshot[0][0] = 7
	assert_array(keys).is_equal(["a", "b"])
	assert_array(snapshot).is_equal([[7], 2])
	assert_array(values["a"]).is_equal([7])


func test_copy_and_remove_preserve_shallow_copy_contract() -> void:
	var original := {"a": [1], "b": 2}
	var copied: Dictionary = invoke("copy", [original])
	copied["a"][0] = 7
	invoke("remove", [copied, "b"])
	assert_dict(original).is_equal({"a": [7], "b": 2})
	assert_dict(copied).is_equal({"a": [7]})
	assert_bool(invoke("contains", [original, "b"])).is_true()
	assert_bool(invoke("contains", [original, 2])).is_false()


func test_invalid_keys_and_missing_remove_report_errors() -> void:
	for name in ["get", "pop", "remove", "contains"]:
		for key in [[], {}, invoke("deque")]:
			assert_bool(invoke(name, [{}, key]) is RuntimeError).is_true()
	assert_bool(invoke("pop", [{}]) is RuntimeError).is_true()
	assert_bool(invoke("remove", [{}, "missing"]) is RuntimeError).is_true()
