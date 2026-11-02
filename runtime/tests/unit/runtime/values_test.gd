extends GdUnitTestSuite

const B = preload("res://tests/support/bytecode.gd")
const O = preload("res://engine/bytecode/opcode.gd")
const RuntimeError = preload("res://engine/virtual_machine/runtime_error.gd")
const Buffer = preload("res://utilities/circular_buffer.gd")


func test_numeric_operations_preserve_types_and_precision() -> void:
	for sample in [
		[O.ADD, 2, 3, 5],
		[O.ADD, 2, 0.5, 2.5],
		[O.SUBTRACT, 3, 0.5, 2.5],
		[O.MULTIPLY, 2, 3, 6],
		[O.DIVIDE, 3, 2, 1.5],
		[O.GREATER, 3, 2, true],
		[O.LESS, 1, 2.0, true],
		[O.EQUAL, 1, 1.0, true],
		[O.ADD, "a", "b", "ab"],
		[O.ADD, 9007199254740993, 1, 9007199254740994],
	]:
		var result := B.evaluate([[O.CONSTANT, sample[1]], [O.CONSTANT, sample[2]], [sample[0]]])
		assert_that(result.error).is_null()
		assert_array(result.output).is_equal([sample[3]])
		assert_int(typeof(result.output[0])).is_equal(typeof(sample[3]))


func test_string_concatenation_accepts_numbers_in_either_order() -> void:
	for sample in [
		["count: ", 3, "count: 3"],
		[3, " items", "3 items"],
		["", 0, "0"],
		[-12, "", "-12"],
		["value: ", 2.5, "value: 2.5"],
		[2.5, " units", "2.5 units"],
		["", 9007199254740993, "9007199254740993"],
		[9223372036854775807, "", "9223372036854775807"],
	]:
		var result := B.evaluate([[O.CONSTANT, sample[0]], [O.CONSTANT, sample[1]], [O.ADD]])
		assert_that(result.error).is_null()
		assert_array(result.output).is_equal([sample[2]])
		assert_int(typeof(result.output[0])).is_equal(TYPE_STRING)


func test_string_concatenation_rejects_non_numeric_values() -> void:
	for value in [true, null, [], {}]:
		for operands in [["value: ", value], [value, " suffix"]]:
			var result := B.evaluate([[O.CONSTANT, operands[0]], [O.CONSTANT, operands[1]], [O.ADD]])
			assert_bool(result.error is RuntimeError).is_true()


func test_truncated_remainder_signs_and_integer_boundary() -> void:
	for sample in [
		[7, 3, 1],
		[-7, 3, -1],
		[7, -3, 1],
		[-7, -3, -1],
		[-7.5, 2.0, -1.5],
		[7, -2.0, 1.0],
		[9223372036854775807, 3, 1],
		[-9223372036854775807 - 1, -1, 0],
	]:
		var result := B.evaluate([[O.CONSTANT, sample[0]], [O.CONSTANT, sample[1]], [O.MODULO]])
		assert_that(result.error).is_null()
		assert_array(result.output).is_equal([sample[2]])


func test_invalid_numeric_operands_and_zero_remainder_divisor() -> void:
	for operations in [
		[[O.TRUE], [O.NEGATE]],
		[[O.TRUE], [O.CONSTANT, 1], [O.ADD]],
		[[O.CONSTANT, "a"], [O.CONSTANT, 1], [O.LESS]],
		[[O.CONSTANT, 1], [O.CONSTANT, 0], [O.MODULO]],
		[[O.CONSTANT, 1.0], [O.CONSTANT, 0.0], [O.MODULO]],
	]:
		assert_bool(B.evaluate(operations).error is RuntimeError).is_true()


func test_conditional_jumps_skip_errors_and_keep_selected_operand() -> void:
	for sample in [[O.JUMP_IF_FALSE, 0], [O.JUMP_IF_TRUE, "selected"]]:
		var result := B.evaluate([[O.CONSTANT, sample[1]], [sample[0], 3], [O.POP], [O.GET_GLOBAL, "missing"]])
		assert_that(result.error).is_null()
		assert_array(result.output).is_equal([sample[1]])
	var result := B.evaluate([[O.TRUE], [O.JUMP_IF_FALSE, 3], [O.POP], [O.CONSTANT, 42]])
	assert_array(result.output).is_equal([42])


func test_truthiness_includes_empty_collections() -> void:
	for sample in [[null, true], [0, true], ["", true], ["text", false], [[], true], [{}, true], [[null], false], [{"a": null}, false]]:
		assert_array(B.evaluate([[O.CONSTANT, sample[0]], [O.NOT]]).output).is_equal([sample[1]])


func test_subscript_reads_and_writes_support_container_semantics() -> void:
	var list := [1, 2]
	var dictionary := {"a": 1}
	var deque := Buffer.new()
	deque.push_back(3)
	for sample in [[list, -1, 2], [dictionary, "a", 1], [deque, -1, 3], ["a猫😀", -1, "😀"]]:
		var result := B.evaluate([[O.CONSTANT, sample[0]], [O.CONSTANT, sample[1]], [O.GET_SUBSCRIPT]])
		assert_that(result.error).is_null()
		assert_array(result.output).is_equal([sample[2]])
	for sample in [[list, 0], [dictionary, "new"], [deque, -1]]:
		var result := B.evaluate([[O.CONSTANT, sample[0]], [O.CONSTANT, sample[1]], [O.CONSTANT, 9], [O.SET_SUBSCRIPT]])
		assert_array(result.output).is_equal([9])
	assert_array(list).is_equal([9, 2])
	assert_dict(dictionary).is_equal({"a": 1, "new": 9})
	assert_int(deque.at(0)).is_equal(9)


func test_subscript_errors_reject_invalid_keys_bounds_and_string_writes() -> void:
	for sample in [[[], 0], [[1], true], ["abc", -4], ["abc", 1.0], [{}, "missing"], [{}, []], [42, 0]]:
		assert_bool(B.evaluate([[O.CONSTANT, sample[0]], [O.CONSTANT, sample[1]], [O.GET_SUBSCRIPT]]).error is RuntimeError).is_true()
	assert_bool(B.evaluate([[O.CONSTANT, "abc"], [O.CONSTANT, 0], [O.CONSTANT, "z"], [O.SET_SUBSCRIPT]]).error is RuntimeError).is_true()


func test_build_instructions_preserve_list_order_and_last_dictionary_value() -> void:
	var list := B.evaluate([[O.CONSTANT, 1], [O.CONSTANT, 2], [O.BUILD_LIST, 2], [O.CONSTANT, 0], [O.GET_SUBSCRIPT]])
	assert_array(list.output).is_equal([1])
	var dict := B.evaluate([
		[O.CONSTANT, "a"],
		[O.CONSTANT, 1],
		[O.CONSTANT, "a"],
		[O.CONSTANT, 2],
		[O.BUILD_DICT, 2],
		[O.CONSTANT, "a"],
		[O.GET_SUBSCRIPT],
	])
	assert_array(dict.output).is_equal([2])
	assert_bool(B.evaluate([[O.BUILD_LIST, 0], [O.CONSTANT, 1], [O.BUILD_DICT, 1]]).error is RuntimeError).is_true()
