extends RefCounted

var message: String
var line: int
## Formatted frames, innermost first, with one-based source lines.
var stack_trace: Array[String] = []


func _init(p_message: String, p_line: int) -> void:
	message = p_message
	line = p_line
