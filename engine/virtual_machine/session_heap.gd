extends RefCounted

# Some data structures (such as lists) cannot be referenced by Godot's weakref().
# Thus we must either wrap lists as a RuntimeList object which can be handled, but increases indirection and LoC dramatically.
# Or implement this heap structure which tracks all memory used by all objects and releases them at once.
# TODO: This is far from optimal and leads to growing memory usage as time goes on.

const Closure = preload("res://engine/virtual_machine/closure.gd")
const CompiledFunction = preload("res://engine/bytecode/compiled_function.gd")

## Strong ownership deliberately retains every allocation until the run ends.
var _allocations: Array = []


func new_list(items: Array) -> Array:
	_allocations.append(items)
	return items


func new_closure(function: CompiledFunction) -> Closure:
	var closure := Closure.new(function)
	_allocations.append(closure)
	return closure


func clear() -> void:
	for value in _allocations:
		if value is Array:
			value.clear()
		elif value is Closure:
			value.upvalues.clear()
	_allocations.clear()
