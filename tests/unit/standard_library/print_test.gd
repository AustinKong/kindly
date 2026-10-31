extends "res://tests/support/library_suite.gd"

const Formatter = preload("res://engine/standard_library/print_library.gd")


func test_scalars_and_nested_strings_have_distinct_formatting() -> void:
	assert_str(Formatter.format("hello")).is_equal("hello")
	assert_str(Formatter.format([1, "two", true, null])).is_equal('[1, "two", true, <null>]')
	assert_str(Formatter.format(["line\nbreak", 'say "hi"'])).is_equal('["line\\nbreak", "say \\"hi\\""]')


func test_shared_values_print_fully_but_mixed_cycles_are_bounded() -> void:
	var shared := vm.heap.new_dictionary({"a": 1})
	assert_str(Formatter.format([shared, shared])).is_equal('[{"a": 1}, {"a": 1}]')
	var list := vm.heap.new_list([])
	var deque = invoke("deque", [[list]])
	shared["cycle"] = deque
	list.append(shared)
	var first := Formatter.format(shared)
	assert_str(first).contains("{...}")
	assert_str(Formatter.format(shared)).is_equal(first)
	assert_bool(is_same(list[0], shared)).is_true()
	assert_bool(is_same(deque.at(0), list)).is_true()


func test_deep_acyclic_values_have_bounded_output() -> void:
	var value: Array = [1]
	for i in range(100):
		value = [value]
	var formatted := Formatter.format(value)
	assert_str(formatted).contains("[...]")
	assert_int(formatted.length()).is_less(200)


func test_registered_print_uses_formatter_and_returns_none() -> void:
	var deque = invoke("deque", [[1]])
	assert_that(invoke("print", [[deque, "task"]])).is_null()
	assert_array(output).is_equal(['[deque([1]), "task"]'])
