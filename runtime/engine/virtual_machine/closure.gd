extends RefCounted


const CompiledFunction = preload("res://engine/bytecode/compiled_function.gd")
const Cell = preload("res://engine/virtual_machine/cell.gd")

var function: CompiledFunction
var upvalues: Array[Cell] = []


func _init(p_function: CompiledFunction):
	function = p_function
