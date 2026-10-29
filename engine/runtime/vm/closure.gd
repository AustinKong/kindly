extends RefCounted


const Function = preload("res://engine/runtime/function.gd")
const Cell = preload("res://engine/runtime/vm/cell.gd")

var function: Function
var upvalues: Array[Cell] = []


func _init(p_function: Function):
	function = p_function
