extends SceneTree

const LanguageInterpreter = preload("res://engine/interpreter.gd")
const CompileError = preload("res://engine/frontend/compile_error.gd")
const EditorTokens = preload("res://engine/frontend/editor_tokens.gd")
var failed := 0

func _initialize() -> void:
	run_tests.call_deferred()

func run_tests() -> void:
	for sample in [
		['"Count: " + 3', "Count: 3"],
		['3 + " items"', "3 items"],
		['"total: " + (2 + 3)', "total: 5"],
		['1 + 2 + " items"', "3 items"],
		['"items: " + 1 + 2', "items: 12"],
		['"amount: " + 2.5', "amount: 2.5"],
	]:
		for language in ["simple", "kindly"]:
			var source: String = "print(" + sample[0] + ")\n" if language == "simple" else "Dear Compiler,\nKindly execute print(" + sample[0] + ").\nBest regards.\n"
			var output: Array[String] = []
			var error: Variant = LanguageInterpreter.new(language).interpret(source, func(text: String) -> void: output.append(text))
			expect(error == null and output == [sample[1]], language + " string concatenation: " + sample[0])
	for test_case in [
		["Please let message be \"Hello\".\nKindly execute print(message).", ["Hello"]],
		["pLeAsE LeT x bE 10.5.\nPlease update x to x + 1.\nKindly execute print(x).", ["11.5"]],
		["Please let x be [1, 2].\nPlease update x[0] to 3.\nKindly execute print(x[0]).", ["3"]],
		["Please define factorial(n):\n\tWith respect to n == 0:\n\t\tKindly return 1.\n\tKindly return n * factorial(n - 1).\nKindly execute print(factorial(5)).", ["120"]],
		["Please define outer(x):\n\tPlease define inner(y = 2):\n\t\tKindly return x + y.\n\tKindly return inner.\nPlease let f be outer(3).\nKindly execute print(f()).", ["5"]],
		["For each i from 0 to 5:\n\tWith respect to i == 1:\n\t\tKindly proceed.\n\tAlternatively, if i == 3:\n\t\tKindly cease.\n\tOtherwise:\n\t\tKindly execute print(i).", ["0", "2"]],
		["Please let i be 0.\nAs long as i < 3:\n\tPlease update i to i + 1.\nKindly execute print(i).", ["3"]],
		["For each i from 3 to 0 step -1:\n\tKindly execute print(i).", ["3", "2", "1"]],
		["Please let be be 2.\nPlease let to be 3.\nPlease update be to be + to.\nKindly execute print(be).", ["5"]],
	]:
		var source: String = "Dear Compiler,\n" + test_case[0] + "\nBest regards.\n"
		var output: Array[String] = []
		var error: Variant = LanguageInterpreter.new("kindly").interpret(source, func(text: String) -> void: output.append(text))
		expect(error == null and output == test_case[1], source + ("\n" + error.message if error != null else str(output)))
	for body in [
		"Please let x be 1, thank you.", "Kindly execute print(1), thank you.",
		"Please define f():\n\tKindly return, thank you.",
		"Please let x be 1", "Please let x be 1.\nPlease let x be 2.",
		"Kindly return 1.", "Kindly cease.", "Kindly proceed.",
		"Please update x + 1 to 2.", "Please update print(x to 1).",
		"Kindly execute 1 + 2.", "Kindly execute print(x = 1).", "var x = 1", "print(1).",
	]:
		expect(LanguageInterpreter.new("kindly").interpret("Dear Compiler,\n" + body + "\nBest regards.\n") is CompileError, "Reject " + body)
	for source in ["Please let x be 1.\nBest regards.", "Dear Compiler,\nPlease let x be 1.", "Dear Compiler,\nBest regards.\nKindly execute print(1)."]:
		expect(LanguageInterpreter.new("kindly").interpret(source) is CompileError, "Reject invalid envelope")
	expect(LanguageInterpreter.new("unknown").interpret("") is CompileError, "Unknown languages are rejected")
	expect(LanguageInterpreter.new("simple").interpret("var x = 1\nprint(x)\n") == null, "Explicit Simple remains runnable")
	var tokens := EditorTokens.tokenize("Please let message be \"hello\".\nKindly execute print(message).", "kindly", 7)
	expect(tokens.language == "kindly" and tokens.revision == 7 and tokens.tokens[0].kind == "keyword" and tokens.tokens[1].kind == "definition", "Kindly contextual highlighting")
	print("Language tests: %d failures" % failed)
	quit(0 if failed == 0 else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failed += 1
		push_error(message)
