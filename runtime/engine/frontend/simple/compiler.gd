extends "res://engine/frontend/compiler.gd"


func _parse_program() -> void:
	while _compile_error == null and _current().type != Token.Type.EOF:
		_parse_declaration()


func _parse_declaration() -> void:
	if _match(Token.Type.VAR):
		_parse_variable_declaration()
	elif _match(Token.Type.DEF):
		_parse_function_declaration()
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
		_parse_return_statement()
	elif _match(Token.Type.BREAK) or _match(Token.Type.CONTINUE):
		_parse_loop_jump(_previous().type == Token.Type.BREAK)
	else:
		_parse_expression_statement()


func _parse_initializer() -> void:
	if _match(Token.Type.EQUAL):
		_parse_expression()
	else:
		_emit_instruction(OpCode.NONE)


func _parse_return_statement() -> void:
	if _match(Token.Type.NEWLINE):
		_emit_instruction(OpCode.NONE)
	else:
		_parse_expression()
		_end_statement()
	_emit_instruction(OpCode.RETURN)


func _match_keyword(type: Token.Type) -> bool:
	return _match(type)


func _match_assignment() -> bool:
	return _match(Token.Type.EQUAL)


func _end_statement() -> bool:
	return _consume(Token.Type.NEWLINE, "Expect newline after statement.")
