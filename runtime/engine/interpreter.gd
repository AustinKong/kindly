class_name Interpreter
extends RefCounted

const VirtualMachine = preload("res://engine/virtual_machine/virtual_machine.gd")
const COMPILERS = {
	"simple": preload("res://engine/frontend/simple/compiler.gd"),
	"kindly": preload("res://engine/frontend/kindly/compiler.gd"),
}
const LEXERS = {
	"simple": preload("res://engine/frontend/simple/lexer.gd"),
	"kindly": preload("res://engine/frontend/kindly/lexer.gd"),
}
const ScanError = preload("res://engine/frontend/scan_error.gd")
const CompileError = preload("res://engine/frontend/compile_error.gd")
const StandardLibrary = preload("res://engine/standard_library/standard_library.gd")

var _language: String


func _init(language: String = "simple") -> void:
	_language = language


## Returns null on success, or the scan, compile, or runtime error for the caller to display.
func interpret(source: String, output: Callable = Callable()) -> Variant:
	var lexer: GDScript = LEXERS.get(_language)
	if lexer == null:
		return CompileError.new("Unsupported language: " + _language, 0, 0, 0)
	var scanned: Variant = lexer.new(source).scan()
	if scanned is ScanError:
		return scanned

	var compiler: GDScript = COMPILERS[_language]
	var compiled: Variant = compiler.new(source, scanned).compile()
	if compiled is CompileError:
		return compiled

	var vm := VirtualMachine.new()
	StandardLibrary.register(vm, output)
	return vm.interpret(compiled)
