extends RefCounted

const LanguageInterpreter = preload("res://engine/interpreter.gd")
const Token = preload("res://engine/frontend/token.gd")
const VM = preload("res://engine/virtual_machine/virtual_machine.gd")
const StandardLibrary = preload("res://engine/standard_library/standard_library.gd")

static var _builtins: Array = []


## Presentation categories are independent of each frontend's token enum.
static func tokenize(source: String, language: String, revision: int) -> Dictionary:
	var result := {"language": language, "revision": revision, "tokens": []}
	var lexer: GDScript = LanguageInterpreter.LEXERS.get(language)
	if lexer == null:
		return result
	if _builtins.is_empty():
		var vm := VM.new()
		StandardLibrary.register(vm)
		_builtins = vm._globals.keys()
	var scanned: Array = lexer.new(source).scan_for_editor()
	var previous := Token.Type.EOF
	for token in scanned:
		var kind := _kind(token.type)
		if token.type == Token.Type.IDENTIFIER:
			if previous == Token.Type.DEF:
				kind = "function"
			elif previous == Token.Type.VAR:
				kind = "definition"
			elif source.substr(token.start, token.length) in _builtins:
				kind = "builtin"
		result.tokens.append({"start": token.start, "length": token.length, "kind": kind})
		if token.type != Token.Type.COMMENT:
			previous = token.type
	return result


static func _kind(type: Token.Type) -> String:
	match type:
		Token.Type.NUMBER: return "number"
		Token.Type.STRING: return "string"
		Token.Type.TRUE, Token.Type.FALSE: return "bool"
		Token.Type.NONE: return "null"
		Token.Type.IDENTIFIER: return "identifier"
		Token.Type.COMMENT: return "comment"
		Token.Type.INVALID: return "invalid"
	if type in [
		Token.Type.ASTERISK, Token.Type.MINUS, Token.Type.PERCENT, Token.Type.PLUS,
		Token.Type.SLASH, Token.Type.BANG_EQUAL, Token.Type.EQUAL, Token.Type.EQUAL_EQUAL,
		Token.Type.GREATER, Token.Type.GREATER_EQUAL, Token.Type.LESS, Token.Type.LESS_EQUAL,
	]:
		return "operator"
	if type >= Token.Type.AND and type <= Token.Type.EXECUTE:
		return "keyword"
	return "punctuation"

