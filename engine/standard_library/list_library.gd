extends RefCounted

const RuntimeError = preload("res://engine/virtual_machine/runtime_error.gd")
const SessionHeap = preload("res://engine/virtual_machine/session_heap.gd")


static func register(vm) -> void:
	vm.define_native_function("insert", _insert)
	vm.define_native_function("remove", _remove)
	vm.define_native_function("index", _index)
	vm.define_native_function("copy", _copy.bind(vm.heap))
	vm.define_native_function("reverse", _reverse)
	vm.define_native_function("sort", _sort)


static func _insert(list: Variant, index: Variant, value: Variant) -> Variant:
	var error := _require_list(list, "insert")
	if error != null:
		return error
	if typeof(index) != TYPE_INT:
		return _error("insert() index must be an integer.")

	if index < 0:
		index = maxi(0, list.size() + index)
	else:
		index = mini(index, list.size())
	list.insert(index, value)
	return null


static func _remove(list: Variant, value: Variant) -> Variant:
	var error := _require_list(list, "remove")
	if error != null:
		return error

	var index: int = list.find(value)
	if index == -1:
		return _error("remove() value was not found in the list.")
	list.remove_at(index)
	return null


static func _index(list: Variant, value: Variant) -> Variant:
	var error := _require_list(list, "index")
	if error != null:
		return error

	var index: int = list.find(value)
	if index == -1:
		return _error("index() value was not found in the list.")
	return index


static func _copy(list: Variant, heap: SessionHeap) -> Variant:
	var error := _require_list(list, "copy")
	if error != null:
		return error
	return heap.new_list(list.duplicate())


static func _reverse(list: Variant) -> Variant:
	var error := _require_list(list, "reverse")
	if error != null:
		return error
	list.reverse()
	return null


static func _sort(list: Variant) -> Variant:
	var error := _require_list(list, "sort")
	if error != null:
		return error
	# Validate the entire list before mutating it.
	var has_numbers := false
	var has_strings := false
	for value in list:
		match typeof(value):
			TYPE_INT, TYPE_FLOAT: has_numbers = true
			TYPE_STRING: has_strings = true
			_: return _error("sort() expects only numbers or only strings.")
		if has_numbers and has_strings:
			return _error("sort() expects only numbers or only strings.")
	list.sort()
	return null


static func _require_list(value: Variant, name: String) -> RuntimeError:
	if not value is Array:
		return _error("%s() first argument must be a list." % name)
	return null


## The VM attaches the script call site's line and stack trace to native errors.
static func _error(message: String) -> RuntimeError:
	return RuntimeError.new(message, -1)
