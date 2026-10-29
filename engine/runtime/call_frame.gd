extends RefCounted

const Function = preload("res://engine/runtime/function.gd")

var function: Function
var pc: int
var slot_start: int


## Creates a frame for a function at its first instruction and the given stack slot.
func _init(p_function: Function, p_slot_start: int = 0) -> void:
	function = p_function
	pc = 0
	slot_start = p_slot_start
