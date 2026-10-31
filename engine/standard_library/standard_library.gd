extends RefCounted

const ListLibrary = preload("res://engine/standard_library/list_library.gd")
const CollectionLibrary = preload("res://engine/standard_library/collection_library.gd")
const DequeLibrary = preload("res://engine/standard_library/deque_library.gd")
const PrintLibrary = preload("res://engine/standard_library/print_library.gd")


## Registers standard functions in a fresh VM's global namespace.
static func register(vm, output: Callable = Callable()) -> void:
	ListLibrary.register(vm)
	CollectionLibrary.register(vm)
	DequeLibrary.register(vm)
	PrintLibrary.register(vm, output)
