extends "res://tests/support/library_suite.gd"


func test_length_counts_unicode_characters_and_container_entries() -> void:
	for sample in [["a猫😀", 3], ["", 0], [[1, 2], 2], [{"a": 1}, 1], [invoke("deque", [[null]]), 1]]:
		assert_int(invoke("len", [sample[0]])).is_equal(sample[1])
	assert_bool(invoke("len", [42]) is RuntimeError).is_true()


func test_slice_normalizes_negative_clamped_and_empty_bounds() -> void:
	for sample in [
		[null, null, "abcde"],
		[1, 4, "bcd"],
		[-4, -1, "bcd"],
		[-99, 99, "abcde"],
		[4, 1, ""],
		[2, 2, ""],
		[9223372036854775807, null, ""],
	]:
		assert_str(invoke("slice", ["abcde", sample[0], sample[1]])).is_equal(sample[2])
	assert_str(invoke("slice", ["a猫😀z", 1, -1])).is_equal("猫😀")
	assert_array(invoke("slice", [[0, 1, 2, 3], 1, -1])).is_equal([1, 2])
	assert_array(invoke("slice", [[], 1, 9])).is_empty()


func test_list_slice_is_an_independent_shallow_copy() -> void:
	var original := [[1], 2]
	var sliced: Array = invoke("slice", [original])
	sliced.append(3)
	sliced[0][0] = 9
	assert_array(original).is_equal([[9], 2])
	assert_array(sliced).is_equal([[9], 2, 3])


func test_slice_rejects_wrong_types() -> void:
	for arguments in [[{}], [[], true], [[], null, 1.0]]:
		assert_bool(invoke("slice", arguments) is RuntimeError).is_true()
