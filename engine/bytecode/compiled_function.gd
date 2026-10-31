extends RefCounted

## Compiled bytecode and function metadata; closures supply captured values at runtime.

const Chunk = preload("res://engine/bytecode/chunk.gd")


var chunk: Chunk = Chunk.new()
var min_arity: int = 0
var max_arity: int = 0
var name: String
var upvalue_count: int
