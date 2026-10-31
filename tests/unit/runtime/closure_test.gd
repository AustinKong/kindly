extends GdUnitTestSuite

const B = preload("res://tests/support/bytecode.gd")
const O = preload("res://engine/bytecode/opcode.gd")


func test_returned_closure_retains_and_mutates_its_cell() -> void:
	var increment := B.build([[O.GET_UPVALUE, 0], [O.CONSTANT, 1], [O.ADD], [O.SET_UPVALUE, 0], [O.RETURN]], "increment", 0, 0, 1)
	var factory := B.build([[O.CONSTANT, 0], [O.DEFINE_LOCAL], [O.CLOSURE, increment, [[true, 0]]], [O.RETURN]], "factory")
	var result := B.evaluate([
		[O.CLOSURE, factory, []],
		[O.CALL, 0],
		[O.DEFINE_LOCAL],
		[O.GET_LOCAL, 0],
		[O.CALL, 0],
		[O.GET_LOCAL, 0],
		[O.CALL, 0],
		[O.ADD],
	])
	assert_that(result.error).is_null()
	assert_array(result.output).is_equal([3])


func test_sibling_closures_share_the_cell_after_its_local_slot_is_reused() -> void:
	var write := B.build([[O.CONSTANT, 9], [O.SET_UPVALUE, 0], [O.RETURN]], "write", 0, 0, 1)
	var read := B.build([[O.GET_UPVALUE, 0], [O.RETURN]], "read", 0, 0, 1)
	var result := B.evaluate([
		[O.CONSTANT, 1],
		[O.DEFINE_LOCAL],
		[O.CLOSURE, write, [[true, 0]]],
		[O.DEFINE_GLOBAL, "write"],
		[O.CLOSURE, read, [[true, 0]]],
		[O.DEFINE_GLOBAL, "read"],
		[O.POP_LOCAL],
		[O.CONSTANT, 99],
		[O.DEFINE_LOCAL],
		[O.GET_GLOBAL, "write"],
		[O.CALL, 0],
		[O.POP],
		[O.GET_GLOBAL, "read"],
		[O.CALL, 0],
	])
	assert_that(result.error).is_null()
	assert_array(result.output).is_equal([9])


func test_capture_forwarding_and_separate_factory_invocations() -> void:
	var read := B.build([[O.GET_UPVALUE, 0], [O.RETURN]], "read", 0, 0, 1)
	var middle := B.build([[O.CLOSURE, read, [[false, 0]]], [O.RETURN]], "middle", 0, 0, 1)
	var factory := B.build([[O.CLOSURE, middle, [[true, 0]]], [O.RETURN]], "factory", 1, 1)
	var instructions: Array = []
	for value in [7, 9]:
		instructions.append_array([[O.CLOSURE, factory, []], [O.CONSTANT, value], [O.CALL, 1], [O.CALL, 0], [O.CALL, 0]])
	instructions.append([O.ADD])
	var result := B.evaluate(instructions)
	assert_that(result.error).is_null()
	assert_array(result.output).is_equal([16])
