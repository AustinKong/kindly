extends RefCounted

var name: String
var arity: int
var callable: Callable


func _init(p_name: String, p_callable: Callable):
	name = p_name
	callable = p_callable
	arity = p_callable.get_argument_count()
