extends RefCounted

const ListLibrary = preload("res://engine/standard_library/list_library.gd")


## Registers standard functions in a fresh VM's global namespace.
static func register(vm) -> void:
	ListLibrary.register(vm)
