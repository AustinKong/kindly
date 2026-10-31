extends RefCounted

const Buffer = preload("res://utilities/circular_buffer.gd")
const RuntimeError = preload("res://engine/virtual_machine/runtime_error.gd")
const SessionHeap = preload("res://engine/virtual_machine/session_heap.gd")


static func register(vm) -> void:
	var heap: SessionHeap = vm.heap
	vm.define_native_function("deque", func(items: Variant = []) -> Variant: return _new(items, heap), 0, 1)
	vm.define_native_function("append_front", _append_front)
	vm.define_native_function("pop_front", _pop_front)


static func _new(items: Variant, heap: SessionHeap) -> Variant:
	if not items is Array:
		return RuntimeError.new("deque() argument must be a list.", -1)
	return heap.new_circular_buffer(items)


static func _append_front(deque: Variant, value: Variant) -> Variant:
	if not deque is Buffer:
		return RuntimeError.new("append_front() first argument must be a deque.", -1)
	deque.push_front(value)
	return null


static func _pop_front(deque: Variant) -> Variant:
	if not deque is Buffer:
		return RuntimeError.new("pop_front() first argument must be a deque.", -1)
	if deque.is_empty():
		return RuntimeError.new("pop_front() cannot pop an empty deque.", -1)
	return deque.pop_front()
