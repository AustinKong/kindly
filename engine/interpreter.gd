class_name Interpreter
extends RefCounted

const VirtualMachine = preload("res://engine/runtime/virtual_machine.gd")
const Compiler = preload("res://engine/frontend/compiler/compiler.gd")
const Lexer = preload("res://engine/frontend/lexer/lexer.gd")
const ScanError = preload("res://engine/frontend/lexer/scan_error.gd")
const CompileError = preload("res://engine/frontend/compiler/compile_error.gd")


## Returns null on success, or the scan, compile, or runtime error for the caller to display.
func interpret(source: String, output: Callable = Callable()) -> Variant:
	var scanned: Variant = Lexer.new(source).scan()
	if scanned is ScanError:
		return scanned

	var compiled: Variant = Compiler.new(source, scanned).compile()
	if compiled is CompileError:
		return compiled

	var vm := VirtualMachine.new()
	vm.define_native_function("print", func(value: Variant) -> void:
		if output.is_valid():
			output.call(str(value))
		else:
			print(value)
	)
	return vm.interpret(compiled)
