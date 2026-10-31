extends RefCounted

const Function = preload("res://engine/bytecode/compiled_function.gd")
const O = preload("res://engine/bytecode/opcode.gd")
const VM = preload("res://engine/virtual_machine/virtual_machine.gd")


## Instructions are [opcode, optional operand, optional zero-based source line].
## CLOSURE's third field instead holds [is_local, index] capture descriptors.
static func build(instructions: Array, name: String = "", min_arity: int = 0, max_arity: int = 0, captures: int = 0) -> Function:
	var function := Function.new()
	function.name = name
	function.min_arity = min_arity
	function.max_arity = max_arity
	function.upvalue_count = captures
	for instruction: Array in instructions:
		var opcode: int = instruction[0]
		var line: int = instruction[2] if instruction.size() > 2 and instruction[2] is int else 0
		function.chunk.append(opcode, line)
		if instruction.size() < 2:
			continue
		var operand: Variant = instruction[1]
		if opcode in [O.CONSTANT, O.CLOSURE, O.GET_GLOBAL, O.SET_GLOBAL, O.DEFINE_GLOBAL]:
			operand = function.chunk.add_constant(operand)
		if opcode in [O.JUMP, O.JUMP_IF_FALSE, O.JUMP_IF_TRUE]:
			function.chunk.append((int(operand) >> 8) & 255, line)
		function.chunk.append(int(operand) & 255, line)
		if opcode == O.CLOSURE:
			for capture: Array in instruction[2]:
				function.chunk.append(1 if capture[0] else 0, line)
				function.chunk.append(capture[1], line)
	return function


static func run(function: Function, natives: Dictionary = {}) -> Dictionary:
	var vm := VM.new()
	var output: Array = []
	vm.define_native_function("observe", func(value: Variant) -> void: output.append(value))
	for name: String in natives:
		vm.define_native_function(name, natives[name])
	var error = vm.interpret(function)
	return {"error": error, "output": output}


## Leaves one expression result as the argument to a host observer.
static func evaluate(instructions: Array, natives: Dictionary = {}) -> Dictionary:
	return run(build([[O.GET_GLOBAL, "observe"]] + instructions + [
		[O.CALL, 1], [O.POP], [O.NONE], [O.RETURN],
	]), natives)
