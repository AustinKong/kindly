extends RefCounted

var message: String
var line: int


func _init(p_message: String, p_line: int) -> void:
	message = p_message
	line = p_line
