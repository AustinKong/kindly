extends RefCounted

## Executes bytecode with separate operand storage and per-call local cells.

const CallFrame = preload("res://engine/virtual_machine/call_frame.gd")
const Cell = preload("res://engine/virtual_machine/cell.gd")
const Closure = preload("res://engine/virtual_machine/closure.gd")
const NativeFunction = preload("res://engine/virtual_machine/native_function.gd")
const RuntimeError = preload("res://engine/virtual_machine/runtime_error.gd")
const SessionHeap = preload("res://engine/virtual_machine/session_heap.gd")

const CompiledFunction = preload("res://engine/bytecode/compiled_function.gd")
const OpCode = preload("res://engine/bytecode/opcode.gd")

const NUMBER_TYPES = [TYPE_INT, TYPE_FLOAT]
const MAX_CALL_STACK_SIZE: int = 256
const INSTRUCTION_LIMIT: int = 1000000

var _stack: Array = []
var _call_stack: Array[CallFrame] = []
var _globals: Dictionary = {}
## Native functions creating session-owned values must allocate through this heap.
var heap := SessionHeap.new()


## Registers one callable and argument range, replacing any previous binding.
## Omitted bounds infer a fixed count from the callable's unbound arguments.
func define_native_function(name: String, callable: Callable, min_arity: int = -1, max_arity: int = -1) -> void:
	_globals[name] = NativeFunction.new(name, callable, min_arity, max_arity)


## Executes a function and disposes the session on success or runtime failure.
## Returns null or a RuntimeError whose diagnostic data survives disposal.
func interpret(function: CompiledFunction) -> RuntimeError:
	var error := _execute(function)
	_dispose()
	return error


func _execute(function: CompiledFunction) -> RuntimeError:
	var entry := heap.new_closure(function)
	_call_stack.append(CallFrame.new(entry))
	var remaining_instructions := INSTRUCTION_LIMIT

	while true:
		if remaining_instructions == 0:
			return _runtime_error("Execution limit exceeded (%d instructions)." % INSTRUCTION_LIMIT)
		remaining_instructions -= 1

		var opcode := _read_byte()
		match opcode:
			# Values and operand stack.
			OpCode.CONSTANT:
				_stack.push_back(_read_constant())
			OpCode.TRUE: _stack.push_back(true)
			OpCode.FALSE: _stack.push_back(false)
			OpCode.NONE: _stack.push_back(null)
			OpCode.POP: _stack.pop_back()
			OpCode.ARGUMENT_COUNT:
				_stack.push_back(_current_frame().argument_count)
			# Unary and binary operations.
			OpCode.NEGATE:
				if typeof(_stack.back()) not in NUMBER_TYPES:
					return _runtime_error("Operand must be a number.")

				_stack.push_back(-_stack.pop_back())
			OpCode.NOT: _stack.push_back(_is_falsy(_stack.pop_back()))
			OpCode.ADD:
				var right: Variant = _stack.pop_back()
				var left: Variant = _stack.pop_back()

				if typeof(left) == TYPE_STRING and typeof(right) == TYPE_STRING:
					_stack.push_back(left + right)
				elif typeof(left) in NUMBER_TYPES and typeof(right) in NUMBER_TYPES:
					_stack.push_back(left + right)
				else:
					return _runtime_error("Incompatible operands.")
			# Numeric-only binary operators.
			OpCode.SUBTRACT, OpCode.MULTIPLY, OpCode.DIVIDE, OpCode.GREATER, OpCode.LESS:
				var right: Variant = _stack.pop_back()
				var left: Variant = _stack.pop_back()
				if typeof(left) not in NUMBER_TYPES or typeof(right) not in NUMBER_TYPES:
					return _runtime_error("Operands must be numbers")

				match opcode:
					OpCode.SUBTRACT: _stack.push_back(left - right)
					OpCode.MULTIPLY: _stack.push_back(left * right)
					OpCode.DIVIDE: _stack.push_back(float(left) / float(right))
					OpCode.GREATER: _stack.push_back(left > right)
					OpCode.LESS: _stack.push_back(left < right)
			OpCode.EQUAL:
				var right: Variant = _stack.pop_back()
				var left: Variant = _stack.pop_back()
				_stack.push_back(_is_equal(left, right))
			# Global bindings.
			OpCode.DEFINE_GLOBAL:
				var name: String = _read_constant()
				_globals[name] = _stack.pop_back()
			OpCode.GET_GLOBAL, OpCode.SET_GLOBAL:
				var name: String = _read_constant()
				if not _globals.has(name):
					return _runtime_error("Undefined variable %s." % name)

				if opcode == OpCode.GET_GLOBAL:
					_stack.push_back(_globals[name])
				else:
					_globals[name] = _stack.back()
			# Local cells.
			OpCode.DEFINE_LOCAL:
				_current_frame().locals.append(Cell.new(_stack.pop_back()))
			OpCode.GET_LOCAL:
				_stack.push_back(_current_frame().locals[_read_byte()].value)
			OpCode.SET_LOCAL:
				_current_frame().locals[_read_byte()].value = _stack.back()
			OpCode.POP_LOCAL:
				_current_frame().locals.pop_back()
			# Closures and captured cells.
			OpCode.CLOSURE:
				var closure_function: CompiledFunction = _read_constant()
				var closure := heap.new_closure(closure_function)

				for i in range(closure_function.upvalue_count):
					var is_local := _read_byte() == 1
					var index := _read_byte()

					if is_local:
						closure.upvalues.append(_current_frame().locals[index])
					else:
						closure.upvalues.append(_current_frame().closure.upvalues[index])

				_stack.push_back(closure)
			OpCode.GET_UPVALUE:
				var index := _read_byte()
				_stack.push_back(_current_frame().closure.upvalues[index].value)
			OpCode.SET_UPVALUE:
				var index := _read_byte()
				_current_frame().closure.upvalues[index].value = _stack.back()
			# Control flow.
			OpCode.JUMP:
				var offset := _read_two_bytes()
				_current_frame().pc += offset
			OpCode.JUMP_IF_FALSE:
				var offset := _read_two_bytes()
				if _is_falsy(_stack.back()):
					_current_frame().pc += offset
			OpCode.JUMP_IF_TRUE:
				var offset := _read_two_bytes()
				if _is_truthy(_stack.back()):
					_current_frame().pc += offset
			# Calls and returns.
			OpCode.CALL:
				var arg_count := _read_byte()
				var callee_index := len(_stack) - arg_count - 1
				var callee: Variant = _stack[callee_index]

				if not (callee is Closure or callee is NativeFunction):
					return _runtime_error("Only functions can be called.")

				var target: Variant = callee.function if callee is Closure else callee
				if arg_count < target.min_arity or arg_count > target.max_arity:
					if target.min_arity == target.max_arity:
						return _runtime_error("Expected %d arguments but got %d." % [target.max_arity, arg_count])
					return _runtime_error("Expected %d to %d arguments but got %d." % [target.min_arity, target.max_arity, arg_count])

				if callee is Closure and len(_call_stack) >= MAX_CALL_STACK_SIZE:
					return _runtime_error("Stack overflow.")

				# callee_index + 1 is len(_stack) - arg_count; do not use -arg_count.
				# With zero arguments, slice(-arg_count) becomes slice(0) and copies the entire stack.
				var args := _stack.slice(callee_index + 1)
				if callee is Closure:
					var frame := CallFrame.new(callee, arg_count)
					for argument in args:
						frame.locals.append(Cell.new(argument))
					_call_stack.append(frame)
					_stack.resize(callee_index)
				else:
					var result: Variant = callee.callable.callv(args)
					# Standard library has no access to the line. VM needs to unpack and add line number.
					if result is RuntimeError:
						return _runtime_error(result.message)
					_stack.resize(callee_index)
					_stack.push_back(result)
			OpCode.RETURN:
				# Statements preserve operand-stack height, including paths that return early.
				# Only the return value remains above the caller's operands, so no stack resize is needed.
				var result: Variant = _stack.pop_back()
				_call_stack.pop_back()
				if _call_stack.is_empty():
					return null
				_stack.push_back(result)
			OpCode.BUILD_LIST:
				var list_length := _read_byte()
				var list := heap.new_list([])
				for _i in range(list_length):
					list.append(_stack.pop_back())
				list.reverse()
				_stack.push_back(list)
			OpCode.BUILD_DICT:
				var entry_count := _read_byte()
				var dictionary := heap.new_dictionary({})
				var entries_start := _stack.size() - entry_count * 2
				# Insert in source order so later duplicate keys replace earlier values.
				for i in range(entry_count):
					var key: Variant = _stack[entries_start + i * 2]
					var error := _validate_dictionary_key(key)
					if error != null:
						return error
					dictionary[key] = _stack[entries_start + i * 2 + 1]

				_stack.resize(entries_start)
				_stack.push_back(dictionary)
			OpCode.GET_SUBSCRIPT:
				var index_in_list: Variant = _stack.pop_back()
				var list: Variant = _stack.pop_back()
				var error := _validate_subscript(list, index_in_list)
				if error != null:
					return error
				_stack.push_back(list.at(index_in_list) if list is CircularBuffer else list[index_in_list])
			OpCode.SET_SUBSCRIPT:
				var value: Variant = _stack.pop_back()
				var index_in_list: Variant = _stack.pop_back()
				var list: Variant = _stack.pop_back()
				var error := _validate_subscript(list, index_in_list, true)
				if error != null:
					return error
				if list is CircularBuffer:
					list.set_at(index_in_list, value)
				else:
					list[index_in_list] = value
				_stack.push_back(value)


	return null


## Ends the session, clearing lists and captures before releasing heap ownership.
func _dispose() -> void:
	heap.clear()
	_globals.clear()
	_stack.clear()
	_call_stack.clear()


#region Instruction decoding


## Returns the active call frame at the top of the call stack.
func _current_frame() -> CallFrame:
	return _call_stack[-1]


## Reads a byte from the current frame's function and increments that frame's pc.
func _read_byte() -> int:
	var frame := _current_frame()
	var byte := frame.closure.function.chunk.code[frame.pc]
	frame.pc += 1
	return byte


## Reads consecutive bytes as a single signed 16-bit integer.
func _read_two_bytes() -> int:
	var offset := (_read_byte() << 8) | _read_byte()
	return BitUtils.to_signed_16(offset)


## Reads a constant from the current frame's function using the next byte as its index.
func _read_constant() -> Variant:
	return _current_frame().closure.function.chunk.constants[_read_byte()]

#endregion


#region Runtime helpers


func _validate_subscript(data_structure: Variant, index: Variant, for_assignment: bool = false) -> RuntimeError:
	if data_structure is Dictionary:
		var error := _validate_dictionary_key(index)
		if error != null:
			return error
		if not for_assignment and not data_structure.has(index):
			return _runtime_error("Dictionary key not found.")
		return null
	if not (data_structure is Array or data_structure is CircularBuffer):
		return _runtime_error("Only lists, deques, or dictionaries can be subscripted.")
	var kind := "Deque" if data_structure is CircularBuffer else "List"
	if typeof(index) != TYPE_INT:
		return _runtime_error("%s index must be an integer." % kind)
	# Preserve Godot's negative indexing: -1 selects the final element.
	if index < -data_structure.size() or index >= data_structure.size():
		return _runtime_error("%s index out of bounds." % kind)
	return null


func _validate_dictionary_key(key: Variant) -> RuntimeError:
	if typeof(key) not in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
		return _runtime_error("Dictionary keys must be strings, numbers, booleans, or None.")
	return null


func _is_falsy(value: Variant) -> bool:
	if value is Array or value is Dictionary or value is CircularBuffer:
		return value.is_empty()
	return not bool(value)


func _is_truthy(value: Variant) -> bool:
	return not _is_falsy(value)


func _is_equal(left: Variant, right: Variant) -> bool:
	return left == right


func _runtime_error(message: String) -> RuntimeError:
	var frame := _current_frame()
	var line := frame.closure.function.chunk.lines[frame.pc - 1]
	var error := RuntimeError.new(message, line)
	for i in range(len(_call_stack) - 1, -1, -1):
		frame = _call_stack[i]
		var function := frame.closure.function
		var name := function.name if not function.name.is_empty() else "<script>"
		# pc points past the failing instruction or the caller's CALL operand.
		var frame_line := function.chunk.lines[frame.pc - 1]
		error.stack_trace.append("Line %d in %s" % [frame_line + 1, name])
	return error


#endregion
