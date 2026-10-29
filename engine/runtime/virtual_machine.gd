extends RefCounted

const Chunk = preload("res://engine/runtime/chunk.gd")
const CallFrame = preload("res://engine/runtime/call_frame.gd")
const Function = preload("res://engine/runtime/function.gd")
const NativeFunction = preload("res://engine/runtime/native_function.gd")
const OpCode = preload("res://engine/runtime/opcode.gd")
const RuntimeError = preload("res://engine/runtime/runtime_error.gd")

const NUMBER_TYPES = [TYPE_INT, TYPE_FLOAT]
const MAX_CALL_STACK_SIZE = 256
const INSTRUCTION_LIMIT := 1000000

var _stack: Array = []
var _globals: Dictionary = {}
var _call_stack: Array[CallFrame] = []


# TODO: Implement stack traces.
# TODO: Consider if we want to store locals in call frame instead of value stack.
## Executes a function, returning null on success or a RuntimeError on failure.
func interpret(function: Function) -> RuntimeError:
	_stack.push_back(function)
	_call_stack.append(CallFrame.new(function))
	var remaining_instructions := INSTRUCTION_LIMIT

	while true:
		if remaining_instructions == 0:
			return _runtime_error("Execution limit exceeded (%d instructions)." % INSTRUCTION_LIMIT)
		remaining_instructions -= 1

		var instruction := _read_byte()
		match instruction:
			OpCode.CONSTANT:
				_stack.push_back(_current_frame().function.chunk.constants[_read_byte()])
			OpCode.TRUE: _stack.push_back(true)
			OpCode.FALSE: _stack.push_back(false)
			OpCode.NONE: _stack.push_back(null)
			OpCode.NOT: _stack.push_back(_is_falsy(_stack.pop_back()))
			OpCode.POP: _stack.pop_back()
			OpCode.EQUAL:
				var b: Variant = _stack.pop_back()
				var a: Variant = _stack.pop_back()
				_stack.push_back(_is_equal(a, b))
			OpCode.NEGATE:
				if typeof(_stack.back()) not in NUMBER_TYPES:
					return _runtime_error("Operand must be a number.")

				_stack.push_back(-_stack.pop_back())
			OpCode.ADD:
				var b: Variant = _stack.pop_back()
				var a: Variant = _stack.pop_back()

				if typeof(a) == TYPE_STRING and typeof(b) == TYPE_STRING:
					_stack.push_back(a + b)
				elif typeof(a) in NUMBER_TYPES and typeof(b) in NUMBER_TYPES:
					_stack.push_back(a + b)
				else:
					return _runtime_error("Incompatible operands.")
			# Numeric-only binary operators.
			OpCode.SUBTRACT, OpCode.MULTIPLY, OpCode.DIVIDE, OpCode.GREATER, OpCode.LESS:
				var b: Variant = _stack.pop_back()
				var a: Variant = _stack.pop_back()
				if typeof(a) not in NUMBER_TYPES or typeof(b) not in NUMBER_TYPES:
					return _runtime_error("Operands must be numbers")

				match instruction:
					OpCode.SUBTRACT: _stack.push_back(a - b)
					OpCode.MULTIPLY: _stack.push_back(a * b)
					OpCode.DIVIDE: _stack.push_back(float(a) / float(b))
					OpCode.GREATER: _stack.push_back(a > b)
					OpCode.LESS: _stack.push_back(a < b)
			OpCode.DEFINE_GLOBAL:
				var name: String = _read_constant()
				_globals[name] = _stack.pop_back()
			OpCode.SET_GLOBAL:
				var name: String = _read_constant()
				if not _globals.has(name):
					return _runtime_error("Undefined variable %s." % name)
				_globals[name] = _stack.back()
			OpCode.GET_GLOBAL:
				var name: String = _read_constant()
				if not _globals.has(name):
					return _runtime_error("Undefined variable %s." % name)

				_stack.push_back(_globals[name])
			OpCode.SET_LOCAL:
				_stack[_current_frame().slot_start + _read_byte()] = _stack.back()
			OpCode.GET_LOCAL:
				_stack.push_back(_stack[_current_frame().slot_start + _read_byte()])
			OpCode.JUMP_IF_FALSE:
				var offset := _read_two_bytes()
				if _is_falsy(_stack.back()):
					_current_frame().pc += offset
			OpCode.JUMP_IF_TRUE:
				var offset := _read_two_bytes()
				if _is_truthy(_stack.back()):
					_current_frame().pc += offset
			OpCode.JUMP:
				var offset := _read_two_bytes()
				_current_frame().pc += offset
			OpCode.CALL:
				var arg_count := _read_byte()
				var callee: Variant = _stack[- (arg_count + 1)]

				if not (callee is Function or callee is NativeFunction):
					return _runtime_error("Only functions can be called.")

				if arg_count != callee.arity:
					return _runtime_error("Expected %d arguments but got %d." % [callee.arity, arg_count])

				if callee is Function:
					if len(_call_stack) >= MAX_CALL_STACK_SIZE:
						return _runtime_error("Stack overflow.")
					# Slot 0 is reserved for the function itself.
					_call_stack.append(CallFrame.new(callee, len(_stack) - arg_count - 1))
				else:
					# Use len(_stack) - arg_count instead of -arg_count as slice(0) copies entire array.
					var args := _stack.slice(len(_stack) - arg_count)
					var result: Variant = callee.callable.callv(args)
					_stack.resize(len(_stack) - arg_count - 1)
					_stack.push_back(result)
			OpCode.RETURN:
				var result: Variant = _stack.pop_back()
				# O(n) but good enough.
				_stack.resize(_current_frame().slot_start)
				_call_stack.pop_back()
				# Script completed running.
				if len(_call_stack) == 0:
					return null
				_stack.push_back(result)

	return null


# TODO: I don't really see the point of this. TBD.
## Returns the active call frame at the top of the call stack.
func _current_frame() -> CallFrame:
	return _call_stack[-1]


## Reads a constant from the current frame's function using the next byte as its index.
func _read_constant() -> Variant:
	return _current_frame().function.chunk.constants[_read_byte()]

## Reads a byte from the current frame's function and increments that frame's pc.
func _read_byte() -> int:
	var frame := _current_frame()
	var byte := frame.function.chunk.code[frame.pc]
	frame.pc += 1
	return byte


## Reads consecutive bytes as a single signed 16-bit integer.
func _read_two_bytes() -> int:
	var offset := (_read_byte() << 8) | _read_byte()
	return BitUtils.to_signed_16(offset)


func _runtime_error(message: String) -> RuntimeError:
	var frame := _current_frame()
	var line := frame.function.chunk.lines[frame.pc - 1]
	return RuntimeError.new(message, line)


func define_native_function(name: String, callable: Callable):
	_globals[name] = NativeFunction.new(name, callable)


func disassemble(chunk: Chunk) -> void:
	var offset := 0
	while offset < len(chunk.code):
		print("%04d" % [offset])

		if offset > 0 and chunk.lines[offset] == chunk.lines[offset - 1]:
			print("   | ")
		else:
			print("%04d" % [chunk.lines[offset]])

		match chunk.code[offset]:
			OpCode.RETURN: print("RETURN")
			OpCode.NEGATE: print("NEGATE")
			OpCode.ADD: print("ADD")
			OpCode.SUBTRACT: print("SUBTRACT")
			OpCode.MULTIPLY: print("MULTIPLY")
			OpCode.DIVIDE: print("DIVIDE")
			OpCode.EQUAL: print("EQUAL")
			OpCode.GREATER: print("GREATER")
			OpCode.LESS: print("LESS")
			OpCode.NOT: print("NOT")
			OpCode.TRUE: print("TRUE")
			OpCode.FALSE: print("FALSE")
			OpCode.NONE: print("NONE")
			OpCode.CONSTANT:
				print("CONSTANT %4d" % [chunk.code[offset + 1]])
				offset += 1 # Consumes two code entries.
			OpCode.GET_GLOBAL, OpCode.SET_GLOBAL, OpCode.DEFINE_GLOBAL:
				var names := {OpCode.GET_GLOBAL: "GET_GLOBAL", OpCode.SET_GLOBAL: "SET_GLOBAL", OpCode.DEFINE_GLOBAL: "DEFINE_GLOBAL"}
				print("%s %4d" % [names[chunk.code[offset]], chunk.code[offset + 1]])
				offset += 1
			_: print("Unknown opcode")

		offset += 1

func _is_falsy(value: Variant) -> bool:
	return not bool(value)

func _is_truthy(value: Variant) -> bool:
	return bool(value)

func _is_equal(a: Variant, b: Variant) -> bool:
	return a == b
