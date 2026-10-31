extends GdUnitTestSuite

const B = preload("res://tests/support/bytecode.gd")
const O = preload("res://engine/bytecode/opcode.gd")


func test_constant_operand_255_and_source_lines_reach_the_vm_intact() -> void:
	var function := B.build([[O.GET_GLOBAL, "observe"]])
	for i in range(1, 255):
		function.chunk.add_constant(i)
	assert_int(function.chunk.add_constant("last")).is_equal(255)
	for byte in [O.CONSTANT, 255, O.CALL, 1, O.POP, O.NONE, O.RETURN]:
		function.chunk.append(byte, 17)
	assert_array(B.run(function).output).is_equal(["last"])
	assert_int(function.chunk.lines[-1]).is_equal(17)


func test_call_operand_255_reaches_the_final_parameter() -> void:
	var target := B.build([[O.GET_LOCAL, 254], [O.RETURN]], "last", 255, 255)
	var operations: Array = [[O.CLOSURE, target, []]]
	for i in range(255):
		operations.append([O.TRUE])
	operations.append([O.CALL, 255])
	var result := B.evaluate(operations)
	assert_that(result.error).is_null()
	assert_array(result.output).is_equal([true])
