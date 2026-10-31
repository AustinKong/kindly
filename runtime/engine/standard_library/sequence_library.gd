extends RefCounted

const RuntimeError = preload("res://engine/virtual_machine/runtime_error.gd")
const SessionHeap = preload("res://engine/virtual_machine/session_heap.gd")


static func register(vm) -> void:
	var heap: SessionHeap = vm.heap
	vm.define_native_function("slice", func(value: Variant, start: Variant = null, stop: Variant = null) -> Variant: return _slice(value, start, stop, heap), 1, 3)


static func _slice(value: Variant, start: Variant, stop: Variant, heap: SessionHeap) -> Variant:
	if not (value is Array or value is String):
		return RuntimeError.new("slice() first argument must be a list or string.", -1)
	if (start != null and typeof(start) != TYPE_INT) or (stop != null and typeof(stop) != TYPE_INT):
		return RuntimeError.new("slice() bounds must be integers or None.", -1)
	var size: int = value.length() if value is String else value.size()
	var first := _bound(start, size, 0)
	var last := _bound(stop, size, size)
	if value is String:
		return value.substr(first, maxi(0, last - first))
	return heap.new_list(value.slice(first, last) if first < last else [])


static func _bound(bound: Variant, size: int, fallback: int) -> int:
	if bound == null:
		return fallback
	var index: int = bound
	if index < 0:
		index += size
	return clampi(index, 0, size)
