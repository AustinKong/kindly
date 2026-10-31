extends RefCounted

const MAX_DEPTH: int = 64


static func register(vm, output: Callable = Callable()) -> void:
	vm.define_native_function("print", _print.bind(output))


static func _print(value: Variant, output: Callable) -> void:
	var text := format(value)
	if output.is_valid():
		output.call(text)
	else:
		print(text)


## Language display belongs here, independently of the underlying storage types.
static func format(value: Variant) -> String:
	return _format(value, [], false, 0)


static func _format(value: Variant, active: Array, nested: bool, depth: int) -> String:
	if value is Array or value is CircularBuffer:
		var prefix := "deque(" if value is CircularBuffer else ""
		var suffix := ")" if value is CircularBuffer else ""
		if depth >= MAX_DEPTH or active.any(func(parent: Variant) -> bool: return is_same(parent, value)):
			return prefix + "[...]" + suffix
		active.append(value)
		var parts := PackedStringArray()
		for i in range(value.size()):
			var item: Variant = value.at(i) if value is CircularBuffer else value[i]
			parts.append(_format(item, active, true, depth + 1))
		active.pop_back()
		return prefix + "[" + ", ".join(parts) + "]" + suffix
	if nested and typeof(value) == TYPE_STRING:
		return JSON.stringify(value)
	return str(value)
