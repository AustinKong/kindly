extends RefCounted

var message: String
var line: int
var start: int
var length: int


func _init(p_message: String, p_line: int, p_start: int, p_length: int) -> void:
	message = p_message
	line = p_line
	start = p_start
	length = p_length
