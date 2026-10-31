extends RefCounted

const Closure = preload("res://engine/virtual_machine/closure.gd")
const Cell = preload("res://engine/virtual_machine/cell.gd")

var closure: Closure
var pc: int
## Original count supplied by user at call time. Not including defaults.
var argument_count: int

var locals: Array[Cell] = []


## Creates a frame at the closure's function's first instruction with no local cells.
func _init(p_closure: Closure, p_argument_count: int = 0) -> void:
	closure = p_closure
	pc = 0
	argument_count = p_argument_count
