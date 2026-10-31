extends RefCounted

const Buffer = preload("res://utilities/circular_buffer.gd")
const RuntimeError = preload("res://engine/virtual_machine/runtime_error.gd")


static func register(vm) -> void:
	vm.define_native_function("len", _length)
	vm.define_native_function("append", _append)
	vm.define_native_function("pop", _pop)
	vm.define_native_function("clear", _clear)
	vm.define_native_function("contains", _contains)
	vm.define_native_function("extend", _extend)


static func _length(collection: Variant) -> Variant:
	var error := _require_collection(collection, "len")
	if error != null:
		return error
	return collection.size()


static func _append(collection: Variant, value: Variant) -> Variant:
	var error := _require_collection(collection, "append")
	if error != null:
		return error
	if collection is Array:
		collection.append(value)
	else:
		collection.push_back(value)
	return null


static func _pop(collection: Variant) -> Variant:
	var error := _require_collection(collection, "pop")
	if error != null:
		return error
	if collection.is_empty():
		var kind := "list" if collection is Array else "deque"
		return RuntimeError.new("pop() cannot pop an empty %s." % kind, -1)
	return collection.pop_back()


static func _clear(collection: Variant) -> Variant:
	var error := _require_collection(collection, "clear")
	if error != null:
		return error
	collection.clear()
	return null


static func _contains(collection: Variant, value: Variant) -> Variant:
	var error := _require_collection(collection, "contains")
	if error != null:
		return error
	return collection.has(value)


static func _extend(collection: Variant, other: Variant) -> Variant:
	var error := _require_collection(collection, "extend")
	if error != null:
		return error
	if not (other is Array or other is Buffer):
		return RuntimeError.new("extend() second argument must be a list or deque.", -1)
	# Snapshot before mutation, including self-extension and overlapping values.
	var values: Array = other.duplicate() if other is Array else other.to_array()
	if collection is Array:
		collection.append_array(values)
	else:
		for value in values:
			collection.push_back(value)
	return null


static func _require_collection(value: Variant, name: String) -> RuntimeError:
	if not (value is Array or value is Buffer):
		return RuntimeError.new("%s() first argument must be a list or deque." % name, -1)
	return null
