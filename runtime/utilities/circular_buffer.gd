class_name CircularBuffer
extends RefCounted

var _items: Array = []
var _head: int = 0
var _count: int = 0


func _init(initial_capacity: int = 8) -> void:
	assert(initial_capacity >= 0, "Capacity must be nonnegative.")
	_items.resize(maxi(1, initial_capacity))


func size() -> int:
	return _count


func capacity() -> int:
	return _items.size()


func is_empty() -> bool:
	return _count == 0


func has(value: Variant) -> bool:
	# Use Array.has so deque membership matches list membership. I.e. matches Godot's `has` matching rules.
	var candidate: Array = [null]
	for i in range(size()):
		candidate[0] = at(i)
		if candidate.has(value):
			return true
	return false


func push_back(value: Variant) -> void:
	_ensure_space()
	_items[_physical_index(_count)] = value
	_count += 1


func push_front(value: Variant) -> void:
	_ensure_space()
	_head = (_head + capacity() - 1) % capacity()
	_items[_head] = value
	_count += 1


func pop_front() -> Variant:
	if is_empty():
		return null
	var value: Variant = _items[_head]
	_items[_head] = null
	_count -= 1
	_head = (_head + 1) % capacity() if _count > 0 else 0
	return value


func pop_back() -> Variant:
	if is_empty():
		return null
	var index := _physical_index(_count - 1)
	var value: Variant = _items[index]
	_items[index] = null
	_count -= 1
	if _count == 0:
		_head = 0
	return value


func front() -> Variant:
	return null if is_empty() else _items[_head]


func back() -> Variant:
	return null if is_empty() else _items[_physical_index(_count - 1)]


func at(index: int) -> Variant:
	return _items[_checked_index(index)]


func set_at(index: int, value: Variant) -> void:
	_items[_checked_index(index)] = value


## Releases stored values while retaining capacity for reuse.
func clear() -> void:
	_items.fill(null)
	_head = 0
	_count = 0


## Returns an independent Array in logical order; nested values remain shared.
func to_array() -> Array:
	var result: Array = []
	result.resize(_count)
	for i in range(_count):
		result[i] = _items[_physical_index(i)]
	return result


func _physical_index(index: int) -> int:
	return (_head + index) % capacity()


func _checked_index(index: int) -> int:
	assert(index >= -_count and index < _count, "CircularBuffer index out of bounds.")
	return _physical_index(index + _count if index < 0 else index)


func _ensure_space() -> void:
	if _count < capacity():
		return
	var grown: Array = []
	grown.resize(capacity() * 2)
	for i in range(_count):
		grown[i] = _items[_physical_index(i)]
	_items = grown
	_head = 0
