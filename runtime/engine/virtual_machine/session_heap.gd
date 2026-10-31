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


func new_dictionary(items: Dictionary) -> Dictionary:
	_allocations.append(items)
	return items


func new_closure(function: CompiledFunction) -> Closure:
	var closure := Closure.new(function)
	_allocations.append(closure)
	return closure


func new_circular_buffer(items: Array) -> CircularBuffer:
	var deque := CircularBuffer.new(maxi(8, items.size()))
	_allocations.append(deque)
	for value in items:
		deque.push_back(value)
	return deque


func clear() -> void:
	for value in _allocations:
		if value is Array or value is Dictionary or value is CircularBuffer:
			value.clear()
		elif value is Closure:
			value.upvalues.clear()
	_allocations.clear()
