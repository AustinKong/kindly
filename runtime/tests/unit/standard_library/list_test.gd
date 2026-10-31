extends "res://tests/support/library_suite.gd"


func test_append_pop_and_remove_mutate_the_shared_list() -> void:
	var values := [1, 2, 1]
	var alias := values
	assert_that(invoke("append", [values, 3])).is_null()
	assert_int(invoke("pop", [values])).is_equal(3)
	invoke("remove", [values, 1])
	assert_array(alias).is_equal([2, 1])
	assert_int(invoke("index", [values, 1])).is_equal(1)
	assert_bool(invoke("contains", [values, 9])).is_false()


func test_insert_handles_negative_and_clamped_bounds() -> void:
	var values := [1, 3]
	invoke("insert", [values, 1, 2])
	invoke("insert", [values, -1, 8])
	invoke("insert", [values, -99, 0])
	invoke("insert", [values, 99, 4])
	assert_array(values).is_equal([0, 1, 2, 8, 3, 4])


func test_copy_has_independent_storage_but_shared_nested_values() -> void:
	var original := [[1], 2]
	var copied: Array = invoke("copy", [original])
	copied.append(3)
	copied[0][0] = 9
	assert_array(original).is_equal([[9], 2])
	assert_array(copied).is_equal([[9], 2, 3])


func test_extend_snapshots_self_and_accepts_deques() -> void:
	var values := [1, 2]
	invoke("extend", [values, values])
	invoke("extend", [values, invoke("deque", [[3]])])
	assert_array(values).is_equal([1, 2, 1, 2, 3])


func test_sort_and_reverse_support_numbers_and_strings() -> void:
	var numbers := [3, 1.5, -2, 1]
	invoke("sort", [numbers])
	assert_array(numbers).is_equal([-2, 1, 1.5, 3])
	invoke("reverse", [numbers])
	assert_array(numbers).is_equal([3, 1.5, 1, -2])
	var words := ["z", "a", "b"]
	invoke("sort", [words])
	assert_array(words).is_equal(["a", "b", "z"])


func test_invalid_operations_report_errors_without_mutation() -> void:
	for values in [[3, "a", 1], [true], [null]]:
		var before: Array = values.duplicate()
		assert_bool(invoke("sort", [values]) is RuntimeError).is_true()
		assert_array(values).is_equal(before)
	for operation in [["pop", [[]]], ["remove", [[1], 9]], ["index", [[1], 9]], ["insert", [[], true, 1]], ["append", [{}, 1]]]:
		assert_bool(invoke(operation[0], operation[1]) is RuntimeError).is_true()
