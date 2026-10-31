extends GdUnitTestSuite

const Heap = preload("res://engine/virtual_machine/session_heap.gd")
const Cell = preload("res://engine/virtual_machine/cell.gd")
const Function = preload("res://engine/bytecode/compiled_function.gd")
const VM = preload("res://engine/virtual_machine/virtual_machine.gd")
const B = preload("res://tests/support/bytecode.gd")
const O = preload("res://engine/bytecode/opcode.gd")
const RuntimeError = preload("res://engine/virtual_machine/runtime_error.gd")


func test_clear_breaks_mixed_container_and_closure_cycles() -> void:
	var heap := Heap.new()
	var marker := RefCounted.new()
	var reference: WeakRef = weakref(marker)
	var list := heap.new_list([marker])
	var dictionary := heap.new_dictionary({"list": list})
	var deque := heap.new_circular_buffer([dictionary])
	var closure := heap.new_closure(Function.new())
	closure.upvalues.append(Cell.new(deque))
	list.append(closure)
	dictionary["self"] = dictionary
	marker = null
	heap.clear()
	assert_that(reference.get_ref()).is_null()
	assert_array(list).is_empty()
	assert_dict(dictionary).is_empty()
	assert_bool(deque.is_empty()).is_true()
	assert_array(closure.upvalues).is_empty()
	heap.clear()
	assert_array(heap._allocations).is_empty()


func test_allocations_are_retained_until_session_cleanup() -> void:
	var heap := Heap.new()
	var closure := heap.new_closure(Function.new())
	var reference: WeakRef = weakref(closure)
	closure = null
	# Passing the object to an assertion would itself keep it alive until test end.
	assert_bool(reference.get_ref() != null).is_true()
	heap.clear()
	assert_that(reference.get_ref()).is_null()


func test_vm_disposes_native_allocations_on_success_and_failure() -> void:
	for fail in [false, true]:
		var vm := VM.new()
		var retained := vm.heap.new_list([])
		var marker := RefCounted.new()
		var reference: WeakRef = weakref(marker)
		retained.append(marker)
		retained.append(retained)
		marker = null
		vm.define_native_function("allocate", vm.heap.new_list.bind([1, 2]))
		var instructions: Array = [[O.GET_GLOBAL, "allocate"], [O.CALL, 0], [O.DEFINE_GLOBAL, "allocated"]]
		instructions.append_array([[O.GET_GLOBAL, "missing"]] if fail else [[O.NONE], [O.RETURN]])
		var error = vm.interpret(B.build(instructions))
		assert_bool(error is RuntimeError).is_equal(fail)
		assert_that(reference.get_ref()).is_null()
		assert_array(retained).is_empty()
		assert_array(vm.heap._allocations).is_empty()
		assert_array(vm._stack).is_empty()
		assert_array(vm._call_stack).is_empty()
		assert_dict(vm._globals).is_empty()
