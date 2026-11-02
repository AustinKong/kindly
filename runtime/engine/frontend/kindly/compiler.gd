extends "res://engine/frontend/compiler.gd"

var _updating := false
var _did_update := false
var _expression_depth := 0


func _parse_program() -> void:
	_consume(Token.Type.GREETING, "Expect 'Dear Compiler,' at the start of the program.")
	_consume(Token.Type.COMMA, "Expect ',' after 'Dear Compiler'.")
	_consume(Token.Type.NEWLINE, "Expect newline after greeting.")
	while _compile_error == null and _current().type != Token.Type.EOF and _current().type != Token.Type.SIGNOFF:
		_parse_declaration()
	_consume(Token.Type.SIGNOFF, "Expect 'Best regards.' at the end of the program.")
	_consume(Token.Type.DOT, "Expect '.' after 'Best regards'.")
	_consume(Token.Type.NEWLINE, "Expect newline after sign-off.")
	_consume(Token.Type.EOF, "Sign-off must be the last statement.")


func _parse_declaration() -> void:
	if _match(Token.Type.VAR):
		_parse_variable_declaration()
	elif _match(Token.Type.DEF):
		_parse_function_declaration()
	elif _match(Token.Type.UPDATE):
		_updating = true
		_did_update = false
		_parse_expression()
		_updating = false
		if not _did_update:
			_error("Expect an assignment target followed by 'to'.")
		_end_statement()
		_emit_instruction(OpCode.POP)
	else:
		_parse_statement()


func _parse_statement() -> void:
	if _match(Token.Type.IF):
		_parse_if_statement()
	elif _match(Token.Type.WHILE):
		_parse_while_statement()
	elif _match(Token.Type.FOR):
		_parse_for_statement()
	elif _match(Token.Type.RETURN):
		if _enclosing == null:
			_error("Cannot return from top-level code.", _previous())
			return
		_parse_return_statement()
	elif _match(Token.Type.BREAK):
		_parse_loop_jump(true)
	elif _match(Token.Type.CONTINUE):
		_parse_loop_jump(false)
	elif _match(Token.Type.EXECUTE):
		_parse_expression_statement()
	else:
		_error("Expected a courteous statement.")


func _parse_initializer() -> void:
	_consume_word("be", "Expect 'be' after variable name.")
	_parse_expression()


func _parse_expression_statement() -> void:
	if not _parse_expression():
		_error("Expect a function call after 'Kindly execute'.")
	_end_statement()
	_emit_instruction(OpCode.POP)


func _parse_return_statement() -> void:
	if _current().type == Token.Type.DOT:
		_emit_instruction(OpCode.NONE)
	else:
		_parse_expression()
	_end_statement()
	_emit_instruction(OpCode.RETURN)


func _parse_expression(min_bp: int = 0) -> bool:
	_expression_depth += 1
	var is_call := super._parse_expression(min_bp)
	_expression_depth -= 1
	return is_call


func _match_assignment() -> bool:
	if _updating and _expression_depth == 1 and _match_word("to"):
		_updating = false
		_did_update = true
		return true
	return false


func _at_expression_end() -> bool:
	return _current().type == Token.Type.DOT and _peek().type in [Token.Type.NEWLINE, Token.Type.EOF, Token.Type.DEDENT]


func _for_declares_counter() -> bool:
	return true


func _match_keyword(type: Token.Type) -> bool:
	match type:
		Token.Type.EQUAL: return _match_word("from")
		Token.Type.TO: return _match_word("to")
		Token.Type.STEP: return _match_word("step")
	return _match(type)


func _match_word(word: String) -> bool:
	var token := _current()
	if token.type != Token.Type.IDENTIFIER or _source.substr(token.start, token.length).to_lower() != word:
		return false
	_advance()
	return true


func _consume_word(word: String, message: String) -> bool:
	if _match_word(word):
		return true
	_error(message)
	return false


func _end_statement() -> bool:
	if not _consume(Token.Type.DOT, "Expect '.' after statement."):
		return false
	return _consume(Token.Type.NEWLINE, "Expect newline after statement.")
