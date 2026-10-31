extends GdUnitTestSuite

const B = preload("res://tests/support/bytecode.gd")
const O = preload("res://engine/bytecode/opcode.gd")
const VM = preload("res://engine/virtual_machine/virtual_machine.gd")
const RuntimeError = preload("res://engine/virtual_machine/runtime_error.gd")


func test_script_and_zero_argument_native_calls_preserve_caller_operands() -> void:
	var add := B.build([[O.GET_LOCAL, 0], [O.GET_LOCAL, 1], [O.ADD], [O.RETURN]], "add", 2, 2)
	var result := B.evaluate([
		[O.CONSTANT, 10],
		[O.CLOSURE, add, []],
		[O.CONSTANT, 2],
		[O.CONSTANT, 3],
		[O.CALL, 2],
		[O.ADD],
		[O.GET_GLOBAL, "answer"],
		[O.CALL, 0],
		[O.ADD],
	], {"answer": func() -> int: return 42})
	assert_that(result.error).is_null()
	assert_array(result.output).is_equal([57])


func test_native_range_aliases_and_reregistration() -> void:
	var vm := VM.new()
	var observed: Array = []
	vm.define_native_function("observe", func(value: Variant) -> void: observed.append(value))
	vm.define_native_function("sum", func(a: Variant, b: Variant = 10) -> Variant: return a + b, 1, 2)
	var alias = vm._globals["sum"]
	vm.define_native_function("sum", func(a: Variant) -> Variant: return a * 2)
	var function := B.build([
		[O.GET_GLOBAL, "observe"],
		[O.CONSTANT, alias],
		[O.CONSTANT, 3],
		[O.CALL, 1],
		[O.GET_GLOBAL, "sum"],
		[O.CONSTANT, 3],
		[O.CALL, 1],
		[O.ADD],
		[O.CALL, 1],
		[O.POP],
		[O.NONE],
		[O.RETURN],
	])
	assert_that(vm.interpret(function)).is_null()
	assert_array(observed).is_equal([19])


func test_argument_count_reports_supplied_count_and_native_bound_arguments_are_excluded() -> void:
	var count := B.build([[O.ARGUMENT_COUNT], [O.RETURN]], "count", 0, 2)
	for arguments in [[], [7], [7, 8]]:
		var instructions: Array = [[O.CLOSURE, count, []]]
		for value in arguments:
			instructions.append([O.CONSTANT, value])
		instructions.append([O.CALL, arguments.size()])
		assert_array(B.evaluate(instructions).output).is_equal([arguments.size()])
	var result := B.evaluate([[O.GET_GLOBAL, "offset"], [O.CONSTANT, 3], [O.CALL, 1]], {"offset": _offset.bind(4)})
	assert_array(result.output).is_equal([7])


func test_invalid_calls_report_errors_at_the_call_site() -> void:
	var required := B.build([[O.NONE], [O.RETURN]], "required", 1, 1)
	for instructions in [
		[[O.CONSTANT, 7], [O.CALL, 0, 8]],
		[[O.CLOSURE, required, []], [O.CALL, 0, 8]],
		[[O.GET_GLOBAL, "native"], [O.CALL, 0, 8]],
		[[O.GET_GLOBAL, "range"], [O.CONSTANT, 1], [O.CONSTANT, 2], [O.CONSTANT, 3], [O.CALL, 3, 8]],
	]:
		var result := B.run(B.build(instructions), {"native": func(value: Variant) -> Variant: return value, "range": func(a: Variant, b: Variant = 1) -> Variant: return a + b})
		assert_bool(result.error is RuntimeError).is_true()
		assert_int(result.error.line).is_equal(8)
		assert_array(result.error.stack_trace).is_equal(["Line 9 in <script>"])


func test_nested_and_native_errors_preserve_call_trace() -> void:
	var inner := B.build([[O.GET_GLOBAL, "fail"], [O.CALL, 0, 3], [O.RETURN]], "inner")
	var outer := B.build([[O.CLOSURE, inner, []], [O.CALL, 0, 6], [O.RETURN]], "outer")
	var result := B.run(B.build([
		[O.CLOSURE, outer, []],
		[O.CALL, 0, 9],
		[O.RETURN],
	]), {"fail": func() -> Variant: return RuntimeError.new("native failure", -1)})
	assert_bool(result.error is RuntimeError).is_true()
	assert_str(result.error.message).is_equal("native failure")
	assert_int(result.error.line).is_equal(3)
	assert_array(result.error.stack_trace).is_equal(["Line 4 in inner", "Line 7 in outer", "Line 10 in <script>"])


func test_recursion_and_instruction_limits_return_language_errors() -> void:
	var recursive := B.build([[O.GET_GLOBAL, "recurse"], [O.CALL, 0], [O.RETURN]], "recurse")
	var result := B.run(B.build([
		[O.CLOSURE, recursive, []],
		[O.DEFINE_GLOBAL, "recurse"],
		[O.GET_GLOBAL, "recurse"],
		[O.CALL, 0],
		[O.RETURN],
	]))
	assert_bool(result.error is RuntimeError).is_true()
	assert_str(result.error.message).is_equal("Stack overflow.")
	result = B.run(B.build([[O.JUMP, -3]]))
	assert_bool(result.error is RuntimeError).is_true()
	assert_str(result.error.message).contains("Execution limit exceeded")


func _offset(value: Variant, offset: int) -> Variant:
	return value + offset
