extends RefCounted

const Buffer = preload("res://utilities/circular_buffer.gd")
const RuntimeError = preload("res://engine/virtual_machine/runtime_error.gd")
const ListLibrary = preload("res://engine/standard_library/list_library.gd")
const DictionaryLibrary = preload("res://engine/standard_library/dictionary_library.gd")
const SessionHeap = preload("res://engine/virtual_machine/session_heap.gd")

## Distinguish an omitted dictionary key from an explicit None key.
class MissingArgument extends RefCounted:
	pass


static func register(vm) -> void:
	vm.define_native_function("len", _length)
	vm.define_native_function("append", _append)
	vm.define_native_function("pop", _pop, 1, 3)
	vm.define_native_function("remove", _remove)
	vm.define_native_function("copy", _copy.bind(vm.heap))
	vm.define_native_function("contains", _contains)
	vm.define_native_function("extend", _extend)


static func _length(collection: Variant) -> Variant:
	var error := _require_collection(collection, "len")
	if error != null:
		return error
	return collection.size()


static func _append(collection: Variant, value: Variant) -> Variant:
	var error := _require_sequence(collection, "append")
	if error != null:
		return error
	if collection is Array:
		collection.append(value)
	else:
		collection.push_back(value)
	return null


static func _pop(collection: Variant, key: Variant = MissingArgument, fallback: Variant = null) -> Variant:
	var error := _require_collection(collection, "pop")
	if error != null:
		return error
	if collection is Dictionary:
		if is_same(key, MissingArgument):
			return RuntimeError.new("pop() requires a key for dictionaries.", -1)
		error = DictionaryLibrary.key_error(key)
		if error != null:
			return error
		if not collection.has(key):
			return fallback
		var value: Variant = collection[key]
		collection.erase(key)
		return value
	if not is_same(key, MissingArgument):
		return RuntimeError.new("pop() accepts only one argument for lists and deques.", -1)
	if collection.is_empty():
		var kind := "list" if collection is Array else "deque"
		return RuntimeError.new("pop() cannot pop an empty %s." % kind, -1)
	return collection.pop_back()


static func _remove(collection: Variant, value: Variant) -> Variant:
	if collection is Dictionary:
		return DictionaryLibrary._remove(collection, value)
	if not collection is Array:
		return RuntimeError.new("remove() first argument must be a list or dictionary.", -1)
	return ListLibrary._remove(collection, value)


static func _copy(collection: Variant, heap: SessionHeap) -> Variant:
	if collection is Dictionary:
		return heap.new_dictionary(collection.duplicate())
	if collection is Buffer:
		return heap.new_circular_buffer(collection.to_array())
	if not collection is Array:
		return RuntimeError.new("copy() first argument must be a list, deque, or dictionary.", -1)
	return ListLibrary._copy(collection, heap)


static func _contains(collection: Variant, value: Variant) -> Variant:
	var error := _require_collection(collection, "contains")
	if error != null:
		return error
	if collection is Dictionary:
		error = DictionaryLibrary.key_error(value)
		if error != null:
			return error
	return collection.has(value)


static func _extend(collection: Variant, other: Variant) -> Variant:
	var error := _require_sequence(collection, "extend")
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
	if not (value is Array or value is Buffer or value is Dictionary):
		return RuntimeError.new("%s() first argument must be a list, deque, or dictionary." % name, -1)
	return null


static func _require_sequence(value: Variant, name: String) -> RuntimeError:
	if not (value is Array or value is Buffer):
		return RuntimeError.new("%s() first argument must be a list or deque." % name, -1)
	return null
