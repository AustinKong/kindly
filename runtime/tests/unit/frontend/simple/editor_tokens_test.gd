extends GdUnitTestSuite

const Lexer = preload("res://engine/frontend/simple/lexer.gd")
const Token = preload("res://engine/frontend/token.gd")
const ScanError = preload("res://engine/frontend/scan_error.gd")
const EditorTokens = preload("res://engine/frontend/editor_tokens.gd")


func test_editor_tokens_preserve_compiler_tokens_and_capture_comments() -> void:
	var source := "# intro\nvar x = [1, 2.5] # items\nprint(x)\n"
	var strict: Array = Lexer.new(source).scan()
	var scanned := Lexer.new(source).scan_for_editor()
	var actual: Array = []
	for token in scanned:
		if token.type != Token.Type.COMMENT:
			actual.append([token.type, token.start, token.length, token.line])
	var expected: Array = []
	for token in strict:
		if token.type not in [Token.Type.INDENT, Token.Type.DEDENT, Token.Type.NEWLINE, Token.Type.EOF]:
			expected.append([token.type, token.start, token.length, token.line])
	assert_array(actual).is_equal(expected)
	assert_int(scanned.filter(func(token): return token.type == Token.Type.COMMENT).size()).is_equal(2)


func test_editor_recovers_after_incomplete_strings_and_invalid_characters() -> void:
	var source := "var text = \"unfinished\n@ !\nvar value = 42\n# comment"
	assert_bool(Lexer.new(source).scan() is ScanError).is_true()
	var scanned := Lexer.new(source).scan_for_editor()
	assert_int(scanned.filter(func(token): return token.type == Token.Type.STRING).size()).is_equal(1)
	var names: Array = []
	for token in scanned:
		if token.type == Token.Type.IDENTIFIER:
			names.append(source.substr(token.start, token.length))
	assert_array(names).is_equal(["text", "value"])
	assert_int(scanned[-1].type).is_equal(Token.Type.COMMENT)


func test_bracket_and_indentation_errors_terminate_and_preserve_later_tokens() -> void:
	for source in [
		"([)\nprint(1)\n",
		")\nprint(1)\n",
		"var items = [\n1, 2\n",
		"  var x = 1\nprint(x)\n",
		"if True:\n\t\tvar x = 1\n\tprint(x)\n",
	]:
		assert_bool(Lexer.new(source).scan() is ScanError).is_true()
		var scanned := Lexer.new(source).scan_for_editor()
		assert_bool(scanned.any(func(token): return token.type == Token.Type.NUMBER or token.type == Token.Type.IDENTIFIER)).is_true()


func test_bridge_tokens_use_original_unicode_spans_and_runtime_builtins() -> void:
	var source := "var text = \"你好 😀\"\nprint(text)\n"
	var result := EditorTokens.tokenize(source, "simple", 7)
	assert_int(result.revision).is_equal(7)
	assert_str(result.language).is_equal("simple")
	assert_bool(result.has("diagnostics")).is_false()
	var builtin: Dictionary = result.tokens.filter(func(token): return token.kind == "builtin")[0]
	assert_int(builtin.start).is_equal(source.find("print"))
	assert_int(builtin.length).is_equal(5)
	assert_int(result.tokens[0].start).is_equal(0)
	assert_str(result.tokens[0].kind).is_equal("keyword")


func test_unclosed_brackets_preserve_prefix_tokens_without_reporting_diagnostics() -> void:
	var result := EditorTokens.tokenize("print([1, 2", "simple", 0)
	assert_bool(result.has("diagnostics")).is_false()
	assert_int(result.tokens.size()).is_equal(6)
	assert_str(result.tokens[0].kind).is_equal("builtin")


func test_unsupported_language_produces_no_tokens() -> void:
	var result := EditorTokens.tokenize("var x = 1", "missing", 2)
	assert_array(result.tokens).is_empty()
	assert_int(result.revision).is_equal(2)
