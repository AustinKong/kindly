extends GdUnitTestSuite

const Lexer = preload("res://engine/frontend/kindly/lexer.gd")
const Token = preload("res://engine/frontend/token.gd")
const ScanError = preload("res://engine/frontend/scan_error.gd")


func _scan(source: String) -> Array:
	var result: Variant = Lexer.new(source).scan()
	assert_bool(result is Array).is_true()
	return result if result is Array else []


func _types(source: String) -> Array:
	return _scan(source).map(func(token): return token.type)


func _lexemes(source: String, type: Token.Type) -> Array:
	return _scan(source).filter(func(token): return token.type == type).map(
		func(token): return source.substr(token.start, token.length)
	)


func _error(source: String, message: String, line: int, start: int, length: int) -> void:
	var result: Variant = Lexer.new(source).scan()
	assert_bool(result is ScanError).is_true()
	if result is ScanError:
		assert_bool(message in result.message).is_true()
		assert_int(result.line).is_equal(line)
		assert_int(result.start).is_equal(start)
		assert_int(result.length).is_equal(length)


func test_email_envelope_has_phrase_tokens_and_required_punctuation() -> void:
	var source := "\nDear Compiler,\n\nBest regards.\n"
	assert_array(_types(source)).is_equal([
		Token.Type.GREETING, Token.Type.COMMA, Token.Type.NEWLINE,
		Token.Type.SIGNOFF, Token.Type.DOT, Token.Type.NEWLINE,
		Token.Type.EOF,
	])
	assert_array(_lexemes(source, Token.Type.GREETING)).is_equal(["Dear Compiler"])
	assert_array(_lexemes(source, Token.Type.SIGNOFF)).is_equal(["Best regards"])
	var tokens := _scan(source)
	assert_int(tokens[0].line).is_equal(1)
	assert_int(tokens[0].start).is_equal(1)
	assert_int(tokens[3].line).is_equal(3)


func test_courtesy_words_are_contextual_identifiers() -> void:
	var source := "Please let update be 10.\nPlease update update to 20.\nKindly execute print(update).\n"
	assert_array(_lexemes(source, Token.Type.IDENTIFIER)).is_equal([
		"update", "be", "update", "to", "print", "update",
	])
	for word in ["let", "be", "update", "to", "define", "print", "from", "step", "if", "var", "return"]:
		assert_int(_scan(word)[0].type).is_equal(Token.Type.IDENTIFIER)


func test_all_fixed_phrase_words_keep_their_original_case() -> void:
	var source := "pLeAsE LeT Employee bE 10.\nPLEASE UPDATE employee TO 20.\nKiNdLy ExEcUtE PRINT(Employee).\n"
	assert_array(_lexemes(source, Token.Type.IDENTIFIER)).is_equal([
		"Employee", "bE", "employee", "TO", "PRINT", "Employee",
	])
	assert_array(_lexemes(source, Token.Type.VAR)).is_equal(["pLeAsE LeT"])
	assert_array(_lexemes(source, Token.Type.UPDATE)).is_equal(["PLEASE UPDATE"])
	assert_array(_lexemes(source, Token.Type.EXECUTE)).is_equal(["KiNdLy ExEcUtE"])


func test_expression_keywords_are_ascii_case_insensitive() -> void:
	assert_array(_types("TrUe AND false Or NoT nOnE\n")).is_equal([
		Token.Type.TRUE, Token.Type.AND, Token.Type.FALSE, Token.Type.OR, Token.Type.NOT,
		Token.Type.NONE, Token.Type.NEWLINE, Token.Type.EOF,
	])
	assert_array(_lexemes("true True TRUE False FALSE None NONE\n", Token.Type.TRUE)).is_equal([
		"true", "True", "TRUE",
	])
	assert_int(_scan("null")[0].type).is_equal(Token.Type.IDENTIFIER)


func test_identifier_boundaries_and_case_are_preserved() -> void:
	var source := "Employee employee EMPLOYEE true_value andrew _not False2\n"
	assert_array(_lexemes(source, Token.Type.IDENTIFIER)).is_equal([
		"Employee", "employee", "EMPLOYEE", "true_value", "andrew", "_not", "False2",
	])


func test_print_is_an_ordinary_function_identifier() -> void:
	assert_array(_types("Kindly execute print(value).\n")).is_equal([
		Token.Type.EXECUTE, Token.Type.IDENTIFIER,
		Token.Type.LEFT_PARENTHESES, Token.Type.IDENTIFIER, Token.Type.RIGHT_PARENTHESES,
		Token.Type.DOT, Token.Type.NEWLINE, Token.Type.EOF,
	])


func test_branch_and_loop_phrases_are_single_tokens() -> void:
	var source := "Alternatively, if approved:\n\tKindly proceed.\nFor each i from 0 to 10 step 2:\n\tKindly cease.\n"
	assert_array(_lexemes(source, Token.Type.IDENTIFIER)).is_equal([
		"approved", "i", "from", "to", "step",
	])
	assert_int(_scan(source).filter(func(token): return token.type == Token.Type.COMMA).size()).is_equal(0)
	assert_array(_lexemes(source, Token.Type.ELIF)).is_equal(["Alternatively, if"])
	assert_array(_lexemes(source, Token.Type.FOR)).is_equal(["For each"])
	assert_array(_lexemes(source, Token.Type.CONTINUE)).is_equal(["Kindly proceed"])
	assert_array(_lexemes(source, Token.Type.BREAK)).is_equal(["Kindly cease"])


func test_decimal_period_and_statement_period_are_distinct_tokens() -> void:
	var source := "Please let x be 10.5.\nPlease update x to -2.\n"
	assert_array(_lexemes(source, Token.Type.NUMBER)).is_equal(["10.5", "2"])
	assert_array(_lexemes(source, Token.Type.DOT)).is_equal([".", "."])
	var decimal: Variant = _scan(source).filter(func(token): return token.type == Token.Type.NUMBER)[0]
	assert_int(decimal.start).is_equal(source.find("10.5"))
	assert_int(decimal.length).is_equal(4)
	assert_int(_scan(source).filter(func(token): return token.type == Token.Type.MINUS).size()).is_equal(1)


func test_periods_after_indexing_and_calls_remain_sentence_tokens() -> void:
	var source := "Kindly execute print(items[0]).\nobject.name.\n"
	assert_array(_lexemes(source, Token.Type.DOT)).is_equal([".", ".", "."])
	assert_array(_lexemes(source, Token.Type.NUMBER)).is_equal(["0"])
	assert_array(_lexemes(source, Token.Type.IDENTIFIER)).is_equal([
		"print", "items", "object", "name",
	])


func test_operators_match_the_existing_expression_language() -> void:
	assert_array(_types("+ - * / % = == != < <= > >=\n")).is_equal([
		Token.Type.PLUS, Token.Type.MINUS, Token.Type.ASTERISK, Token.Type.SLASH,
		Token.Type.PERCENT, Token.Type.EQUAL, Token.Type.EQUAL_EQUAL, Token.Type.BANG_EQUAL,
		Token.Type.LESS, Token.Type.LESS_EQUAL, Token.Type.GREATER, Token.Type.GREATER_EQUAL,
		Token.Type.NEWLINE, Token.Type.EOF,
	])
	_error("!", "must be followed", 0, 0, 1)


func test_strings_preserve_case_punctuation_and_comment_characters() -> void:
	var source := "Kindly execute print(\"Please let # Employee be 10.5.\").\n"
	assert_array(_lexemes(source, Token.Type.STRING)).is_equal(["\"Please let # Employee be 10.5.\""])
	assert_int(_scan(source).filter(func(token): return token.type == Token.Type.DOT).size()).is_equal(1)
	assert_int(_scan(source).filter(func(token): return token.type == Token.Type.COMMENT).size()).is_equal(0)


func test_strings_use_existing_double_quote_and_literal_backslash_rules() -> void:
	var source := "Kindly execute print(\"ends\\\").\n"
	assert_array(_lexemes(source, Token.Type.STRING)).is_equal(["\"ends\\\""])
	_error("'text'", "Unexpected character", 0, 0, 1)


func test_tabs_produce_indents_and_dedents_for_nested_blocks() -> void:
	var source := "Dear Compiler,\nPlease define f():\n\tWith respect to true:\n\t\tKindly return 1.\n\tOtherwise:\n\t\tKindly return 0.\nBest regards.\n"
	var structure := _scan(source).filter(func(token): return token.type in [Token.Type.INDENT, Token.Type.DEDENT])
	assert_array(structure.map(func(token): return token.type)).is_equal([
		Token.Type.INDENT, Token.Type.INDENT, Token.Type.DEDENT, Token.Type.INDENT,
		Token.Type.DEDENT, Token.Type.DEDENT,
	])
	for token in structure:
		if token.type == Token.Type.DEDENT:
			assert_int(token.length).is_equal(0)


func test_blank_and_comment_only_lines_do_not_change_indentation() -> void:
	var source := "# intro\nDear Compiler,\n\t  # ignored indentation\n \t \nBest regards. # farewell\n"
	var tokens := _scan(source)
	assert_int(tokens.filter(func(token): return token.type in [Token.Type.INDENT, Token.Type.DEDENT]).size()).is_equal(0)
	assert_int(tokens.filter(func(token): return token.type == Token.Type.NEWLINE).size()).is_equal(2)
	assert_int(tokens[0].line).is_equal(1)


func test_multiline_collections_allow_spaces_and_suppress_logical_newlines() -> void:
	var source := "Please let records be [\n    {\"Name\": \"Alice\", \"scores\": [1, 2]},\n    {\"Name\": \"Bob\", \"scores\": [3, 4]}\n].\n"
	var tokens := _scan(source)
	assert_int(tokens.filter(func(token): return token.type == Token.Type.NEWLINE).size()).is_equal(1)
	assert_int(tokens.filter(func(token): return token.type in [Token.Type.INDENT, Token.Type.DEDENT]).size()).is_equal(0)
	assert_array(_lexemes(source, Token.Type.NUMBER)).is_equal(["1", "2", "3", "4"])
	assert_int(tokens[-2].line).is_equal(3)


func test_eof_flushes_newline_and_dedents_without_a_final_line_break() -> void:
	var tokens := _scan("Please define f():\n\tKindly return 1.")
	assert_int(tokens[-4].type).is_equal(Token.Type.DOT)
	assert_int(tokens[-3].type).is_equal(Token.Type.NEWLINE)
	assert_int(tokens[-2].type).is_equal(Token.Type.DEDENT)
	assert_int(tokens[-1].type).is_equal(Token.Type.EOF)
	for token in tokens.slice(-3):
		assert_int(token.length).is_equal(0)
		assert_int(token.line).is_equal(1)


func test_indentation_errors_keep_original_locations() -> void:
	var spaces := "Dear Compiler,\n    Kindly execute print(1).\n"
	_error(spaces, "Spaces are not allowed", 1, spaces.find("    "), 4)
	var dedent := "Please define f():\n\t\tKindly return 1.\n\tKindly return 2.\n"
	_error(dedent, "Unindent does not match", 2, dedent.find("\tKindly return 2"), 1)


func test_bracket_errors_mark_the_original_opening_or_closing_token() -> void:
	_error(")", "Unmatched closing", 0, 0, 1)
	_error("([)]", "does not match", 0, 2, 1)
	_error("([", "Unclosed '['", 0, 1, 1)


func test_unterminated_strings_stop_at_newline_or_eof() -> void:
	_error("\"unfinished\nnext", "Unterminated string", 0, 0, 11)
	_error("\"unfinished", "Unterminated string", 0, 0, 11)


func test_invalid_characters_and_crlf_are_reported_without_normalizing_offsets() -> void:
	_error("@", "Unexpected character", 0, 0, 1)
	_error("Dear Compiler,\r\n", "Unexpected character", 0, 14, 1)
	var source := "Please let naïve be 1.\n"
	_error(source, "Unexpected character", 0, source.find("ï"), 1)


func test_unicode_string_spans_count_code_points() -> void:
	var source := "Please let text be \"你好 😀\".\nKindly execute print(text).\n"
	var tokens := _scan(source)
	var string_token: Variant = tokens.filter(func(token): return token.type == Token.Type.STRING)[0]
	assert_int(string_token.start).is_equal(source.find("\""))
	assert_int(string_token.length).is_equal(6)
	var print_token: Variant = tokens.filter(func(token): return source.substr(token.start, token.length) == "print")[0]
	assert_int(print_token.start).is_equal(source.find("print"))
	assert_int(print_token.line).is_equal(1)


func test_editor_mode_preserves_valid_tokens_and_adds_comments() -> void:
	var source := "# greeting\nDear Compiler,\nPlease let update be true. # binding\nBest regards.\n"
	var strict := _scan(source).filter(func(token): return token.type not in [Token.Type.INDENT, Token.Type.DEDENT, Token.Type.NEWLINE, Token.Type.EOF])
	var editor := Lexer.new(source).scan_for_editor()
	var visible := editor.filter(func(token): return token.type != Token.Type.COMMENT)
	var fields := func(token): return [token.type, token.line, token.start, token.length]
	assert_array(visible.map(fields)).is_equal(strict.map(fields))
	assert_int(editor.filter(func(token): return token.type == Token.Type.COMMENT).size()).is_equal(2)


func test_editor_mode_silently_recovers_incomplete_kindly_source() -> void:
	var source := "Please let text be \"unfinished\n@ ! )\n  Please let number be 42.\n# comment"
	var tokens := Lexer.new(source).scan_for_editor()
	assert_int(tokens.filter(func(token): return token.type == Token.Type.STRING).size()).is_equal(1)
	assert_int(tokens.filter(func(token): return token.type == Token.Type.INVALID).size()).is_equal(2)
	assert_int(tokens.filter(func(token): return token.type == Token.Type.NUMBER).size()).is_equal(1)
	assert_int(tokens[-1].type).is_equal(Token.Type.COMMENT)
	for unfinished in ["([)", "[", "\t\tPlease let x be 1.\n\tKindly return x."]:
		assert_bool(not Lexer.new(unfinished).scan_for_editor().is_empty()).is_true()


func test_envelope_and_statement_grammar_are_left_to_the_compiler() -> void:
	# Token recognition does not validate program structure.
	for source in ["", "Please let x be 1", "Kindly print x.", "Dear Compiler\nBest regards", "For the duration of i from 0 to 10:"]:
		var result: Variant = Lexer.new(source).scan()
		assert_bool(result is Array).is_true()


func test_all_statement_phrases_use_the_shared_token_types() -> void:
	for sample in [
		["Dear Compiler", Token.Type.GREETING], ["Best regards", Token.Type.SIGNOFF],
		["Please let", Token.Type.VAR], ["Please define", Token.Type.DEF],
		["Please update", Token.Type.UPDATE], ["Kindly execute", Token.Type.EXECUTE],
		["Kindly return", Token.Type.RETURN], ["Kindly cease", Token.Type.BREAK],
		["Kindly proceed", Token.Type.CONTINUE], ["With respect to", Token.Type.IF],
		["Alternatively, if", Token.Type.ELIF], ["Otherwise", Token.Type.ELSE],
		["As long as", Token.Type.WHILE], ["For each", Token.Type.FOR],
	]:
		var tokens := _scan(sample[0])
		assert_array(tokens.map(func(token): return token.type)).is_equal([sample[1], Token.Type.NEWLINE, Token.Type.EOF])
		assert_int(tokens[0].start).is_equal(0)
		assert_int(tokens[0].length).is_equal(sample[0].length())


func test_phrase_whitespace_case_and_source_locations_are_preserved() -> void:
	for sample in [
		["FoR  \teach", Token.Type.FOR],
		["With\trespect  TO", Token.Type.IF],
		["ALTERNATIVELY ,\tIF", Token.Type.ELIF],
		["Alternatively,if", Token.Type.ELIF],
	]:
		var source: String = "# intro\n\t" + sample[0] + " value:\n"
		var token: Variant = _scan(source)[1]
		assert_int(token.type).is_equal(sample[1])
		assert_int(token.line).is_equal(1)
		assert_int(token.start).is_equal(source.find(sample[0]))
		assert_int(token.length).is_equal(sample[0].length())
		assert_str(source.substr(token.start, token.length)).is_equal(sample[0])


func test_phrase_boundaries_and_failed_lookahead_leave_identifiers_intact() -> void:
	for source in ["For eachThing i", "For each2 i", "Please letx value", "With respect toad", "Kindly executex print"]:
		assert_bool(_scan(source).all(func(token): return token.type in [Token.Type.IDENTIFIER, Token.Type.NEWLINE, Token.Type.EOF])).is_true()
	assert_array(_lexemes("For eachThing i", Token.Type.IDENTIFIER)).is_equal(["For", "eachThing", "i"])
	for source in ["For\neach", "For # note\neach", "With respect\nto", "Please\nlet"]:
		assert_bool(_scan(source).all(func(token): return token.type in [Token.Type.IDENTIFIER, Token.Type.NEWLINE, Token.Type.EOF])).is_true()


func test_phrases_only_match_at_logical_statement_start() -> void:
	var source := "Please let each be [\nFor each, Otherwise\n].\nKindly execute print(Please, let, Otherwise).\n"
	var tokens := _scan(source)
	assert_int(tokens.filter(func(token): return token.type == Token.Type.FOR).size()).is_equal(0)
	assert_int(tokens.filter(func(token): return token.type == Token.Type.ELSE).size()).is_equal(0)
	assert_array(_lexemes(source, Token.Type.VAR)).is_equal(["Please let"])
	assert_array(_lexemes(source, Token.Type.EXECUTE)).is_equal(["Kindly execute"])
	assert_array(_lexemes(source, Token.Type.IDENTIFIER)).is_equal(["each", "be", "For", "each", "Otherwise", "print", "Please", "let", "Otherwise"])


func test_incomplete_phrases_recover_for_editor_tokenization() -> void:
	for source in ["For", "For ", "For\t", "For e", "Alternatively,", "With respect", "Please"]:
		var tokens := Lexer.new(source).scan_for_editor()
		assert_int(tokens[0].type).is_equal(Token.Type.IDENTIFIER)
		assert_int(tokens[0].start).is_equal(0)
	var complete := Lexer.new("For each").scan_for_editor()
	assert_int(complete.size()).is_equal(1)
	assert_int(complete[0].type).is_equal(Token.Type.FOR)
	assert_int(complete[0].length).is_equal(8)
