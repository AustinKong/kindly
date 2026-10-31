extends GdUnitTestSuite

const VM = preload("res://engine/virtual_machine/virtual_machine.gd")
const StandardLibrary = preload("res://engine/standard_library/standard_library.gd")
const RuntimeError = preload("res://engine/virtual_machine/runtime_error.gd")

var vm: VM
var output: Array


func before_test() -> void:
	output = []
	vm = VM.new()
	StandardLibrary.register(vm, func(value: String) -> void: output.append(value))


func after_test() -> void:
	vm.heap.clear()
	vm = null


## Test native behavior directly; VM tests cover CALL arity and error locations.
func invoke(name: String, arguments: Array = []) -> Variant:
	return vm._globals[name].callable.callv(arguments)
