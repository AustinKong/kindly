extends "res://engine/frontend/compiler.gd"

const PHRASES = {
	"greeting": ["dear", "compiler"],
	"signoff": ["best", "regards"],
	"var": ["please", "let"],
	"define": ["please", "define"],
	"update": ["please", "update"],
	"execute": ["kindly", "execute"],
	"return": ["kindly", "return"],
	"break": ["kindly", "cease"],
	"continue": ["kindly", "proceed"],
	"if": ["with", "respect", "to"],
	"elif": ["alternatively", ",", "if"],
	"else": ["otherwise"],
	"while": ["as", "long", "as"],
	"for": ["for", "each"],
}

var _updating := false
var _did_update := false
var _expression_depth := 0


func _parse_program() -> void:
	_consume_phrase(PHRASES.greeting, "Expect 'Dear Compiler,' at the start of the program.")
	_consume(Token.Type.COMMA, "Expect ',' after 'Dear Compiler'.")
	_consume(Token.Type.NEWLINE, "Expect newline after greeting.")
	while _compile_error == null and _current().type != Token.Type.EOF and not _check_phrase(PHRASES.signoff):
		_parse_declaration()
	_consume_phrase(PHRASES.signoff, "Expect 'Best regards.' at the end of the program.")
	_consume(Token.Type.DOT, "Expect '.' after 'Best regards'.")
	_consume(Token.Type.NEWLINE, "Expect newline after sign-off.")
	_consume(Token.Type.EOF, "Sign-off must be the last statement.")


func _parse_declaration() -> void:
	if _match_phrase(PHRASES.var):
		_parse_variable_declaration()
	elif _match_phrase(PHRASES.define):
		_parse_function_declaration()
	elif _match_phrase(PHRASES.update):
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
	if _match_phrase(PHRASES.if):
		_parse_if_statement()
	elif _match_phrase(PHRASES.while):
		_parse_while_statement()
	elif _match_phrase(PHRASES.for):
		_parse_for_statement()
	elif _match_phrase(PHRASES.return):
		if _enclosing == null:
			_error("Cannot return from top-level code.", _previous())
			return
		_parse_return_statement()
	elif _match_phrase(PHRASES.break):
		_parse_loop_jump(true)
	elif _match_phrase(PHRASES.continue):
		_parse_loop_jump(false)
	elif _match_phrase(PHRASES.execute):
		_parse_expression_statement()
	else:
		_error("Expected a courteous statement.")


func _parse_initializer() -> void:
	_consume_phrase(["be"], "Expect 'be' after variable name.")
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
	if _updating and _expression_depth == 1 and _match_phrase(["to"]):
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
		Token.Type.ELIF: return _match_phrase(PHRASES.elif)
		Token.Type.ELSE: return _match_phrase(PHRASES.else)
		Token.Type.EQUAL: return _match_phrase(["from"])
		Token.Type.TO: return _match_phrase(["to"])
		Token.Type.STEP: return _match_phrase(["step"])
	return false


func _check_phrase(words: Array) -> bool:
	for offset in range(words.size()):
		var token := _tokens[mini(_token_index + offset, _tokens.size() - 1)]
		if words[offset] == ",":
			if token.type != Token.Type.COMMA:
				return false
		elif token.type != Token.Type.IDENTIFIER or _source.substr(token.start, token.length).to_lower() != words[offset]:
			return false
	return true


func _match_phrase(words: Array) -> bool:
	if not _check_phrase(words):
		return false
	for word in words:
		_advance()
	return true


func _consume_phrase(words: Array, message: String) -> bool:
	if _match_phrase(words):
		return true
	_error(message)
	return false


func _end_statement() -> bool:
	if not _consume(Token.Type.DOT, "Expect '.' after statement."):
		return false
	return _consume(Token.Type.NEWLINE, "Expect newline after statement.")
