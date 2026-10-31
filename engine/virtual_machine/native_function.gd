extends RefCounted

var name: String
var arity: int
## Callbacks return a script value, or RuntimeError to abort at the script call site.
var callable: Callable


func _init(p_name: String, p_callable: Callable):
	name = p_name
	callable = p_callable
	arity = p_callable.get_argument_count()
