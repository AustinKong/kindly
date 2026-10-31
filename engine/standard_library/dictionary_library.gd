extends RefCounted

const RuntimeError = preload("res://engine/virtual_machine/runtime_error.gd")
const SessionHeap = preload("res://engine/virtual_machine/session_heap.gd")


static func register(vm) -> void:
	vm.define_native_function("keys", _keys.bind(vm.heap))
	vm.define_native_function("values", _values.bind(vm.heap))
	vm.define_native_function("get", _get_value, 2, 3)


static func _keys(dictionary: Variant, heap: SessionHeap) -> Variant:
	var error := _require_dictionary(dictionary, "keys")
	if error != null:
		return error
	return heap.new_list(dictionary.keys())


static func _values(dictionary: Variant, heap: SessionHeap) -> Variant:
	var error := _require_dictionary(dictionary, "values")
	if error != null:
		return error
	return heap.new_list(dictionary.values())


static func _get_value(dictionary: Variant, key: Variant, fallback: Variant = null) -> Variant:
	var error := _require_dictionary(dictionary, "get")
	if error != null:
		return error
	error = key_error(key)
	if error != null:
		return error
	return dictionary.get(key, fallback)


static func _remove(dictionary: Dictionary, key: Variant) -> Variant:
	var error := key_error(key)
	if error != null:
		return error
	if not dictionary.erase(key):
		return RuntimeError.new("remove() key was not found in the dictionary.", -1)
	return null


static func key_error(key: Variant) -> RuntimeError:
	if typeof(key) not in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
		return RuntimeError.new("Dictionary keys must be strings, numbers, booleans, or None.", -1)
	return null


static func _require_dictionary(value: Variant, name: String) -> RuntimeError:
	if not value is Dictionary:
		return RuntimeError.new("%s() first argument must be a dictionary." % name, -1)
	return null
