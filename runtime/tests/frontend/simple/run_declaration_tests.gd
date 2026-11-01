extends SceneTree

const LanguageInterpreter = preload("res://engine/interpreter.gd")
const CompileError = preload("res://engine/frontend/compile_error.gd")

var _failed := 0


func _initialize() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	for declarations in [
		["var name = 1\n", "var name = 2\n"],
		["def name():\n\treturn 1\n", "def name():\n\treturn 2\n"],
		["var name = 1\n", "def name():\n\treturn 2\n"],
		["def name():\n\treturn 1\n", "var name = 2\n"],
	]:
		var source: String = declarations[0] + declarations[1]
		var output: Array[String] = []
		var error: Variant = LanguageInterpreter.new().interpret(source, func(text: String) -> void: output.append(text))
		_expect(error is CompileError, "duplicate globals are rejected: " + source)
		if error is CompileError:
			_expect(error.start == source.rfind("name") and error.length == 4, "diagnostic marks the second name")
			_expect(error.line == declarations[0].count("\n"), "diagnostic reports the second declaration's line")
		_expect(output.is_empty(), "compile failure does not execute the program")

	for source in [
		"def f():\n\tvar name = 1\n\tvar name = 2\n",
		"def f(name, name):\n\treturn name\n",
		"def f(name):\n\tvar name = 2\n",
	]:
		_expect(LanguageInterpreter.new().interpret(source) is CompileError, "duplicate locals and parameters remain rejected")

	for test_case in [
		["var name = 1\nname = 2\nprint(name)\n", ["2"]],
		["var name = 1\nif True:\n\tvar name = 2\n\tprint(name)\nprint(name)\n", ["2", "1"]],
		["if True:\n\tvar name = 1\nif True:\n\tvar name = 2\n\tprint(name)\n", ["2"]],
		["def f(n):\n\tif n == 0:\n\t\treturn 0\n\treturn f(n - 1)\nprint(f(3))\n", ["0"]],
	]:
		var output: Array[String] = []
		var error: Variant = LanguageInterpreter.new().interpret(test_case[0], func(text: String) -> void: output.append(text))
		_expect(error == null and output == test_case[1], "assignment, nested shadowing, sibling scopes, and recursion still work: " + test_case[0])

	var interpreter := LanguageInterpreter.new()
	_expect(interpreter.interpret("var name = 1\n") == null and interpreter.interpret("var name = 2\n") == null, "separate runs have independent declaration state")
	print("Declaration tests: %d failures" % _failed)
	quit(0 if _failed == 0 else 1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		_failed += 1
		push_error(description)
