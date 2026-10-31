extends RefCounted

var name: String
var min_arity: int
var max_arity: int
## Callbacks return a script value, or RuntimeError to abort at the script call site.
var callable: Callable


func _init(p_name: String, p_callable: Callable, p_min_arity: int = -1, p_max_arity: int = -1):
	name = p_name
	callable = p_callable
	max_arity = p_callable.get_argument_count() if p_max_arity == -1 else p_max_arity
	min_arity = max_arity if p_min_arity == -1 else p_min_arity
	assert(min_arity >= 0 and min_arity <= max_arity, "Invalid native argument range.")
	assert(max_arity <= p_callable.get_argument_count(), "Native arity exceeds callable argument count.")
