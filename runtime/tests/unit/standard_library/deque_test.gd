extends "res://tests/support/library_suite.gd"


func test_constructor_copies_input_and_operations_cover_both_ends() -> void:
	var input := [[1], 2]
	var deque = invoke("deque", [input])
	input[1] = 99
	deque.at(0)[0] = 7
	invoke("append_front", [deque, 0])
	invoke("append", [deque, 3])
	assert_int(invoke("pop_front", [deque])).is_equal(0)
	assert_int(invoke("pop", [deque])).is_equal(3)
	assert_array(deque.to_array()).is_equal([[7], 2])
	assert_array(input).is_equal([[7], 99])


func test_copy_preserves_wrapped_order_and_shares_nested_values() -> void:
	var deque = invoke("deque", [[[0], 1, 2, 3, 4, 5, 6, 7]])
	for i in range(5):
		invoke("pop_front", [deque])
	invoke("extend", [deque, [[8], 9, 10]])
	var copied = invoke("copy", [deque])
	copied.at(3)[0] = 80
	invoke("pop_front", [deque])
	invoke("append", [copied, 11])
	assert_array(deque.to_array()).is_equal([6, 7, [80], 9, 10])
	assert_array(copied.to_array()).is_equal([5, 6, 7, [80], 9, 10, 11])


func test_self_extension_and_membership_match_list_behavior() -> void:
	var values := [1, [2], null]
	var deque = invoke("deque", [values])
	for value in [1.0, true, [2.0], null]:
		assert_bool(invoke("contains", [deque, value])).is_equal(invoke("contains", [values, value]))
	invoke("extend", [deque, deque])
	assert_array(deque.to_array()).is_equal(values + values)


func test_empty_and_invalid_operations_report_errors() -> void:
	for operation in [
		["deque", [null]],
		["pop", [invoke("deque")]],
		["pop_front", [invoke("deque")]],
		["append_front", [[], 1]],
		["pop", [invoke("deque"), null]],
	]:
		assert_bool(invoke(operation[0], operation[1]) is RuntimeError).is_true()
