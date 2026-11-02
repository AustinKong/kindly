extends RefCounted

const LanguageInterpreter = preload("res://engine/interpreter.gd")
const KindlyCompiler = preload("res://engine/frontend/kindly/compiler.gd")
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
	var courtesy: Dictionary = {}
	if language == "kindly":
		courtesy = _courtesy_tokens(source, scanned)
	for token in scanned:
		var kind: String = courtesy.get(token.start, _kind(token.type))
		if token.type == Token.Type.IDENTIFIER and not courtesy.has(token.start):
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
	if type >= Token.Type.AND and type <= Token.Type.WHILE:
		return "keyword"
	return "punctuation"


# Match only statement prefixes, leaving identically named variables as identifiers.
static func _courtesy_tokens(source: String, scanned: Array) -> Dictionary:
	var kinds := {}
	var previous_line := -1
	var depth := 0
	for index in scanned.size():
		var token: Token = scanned[index]
		if token.line != previous_line and depth == 0 and token.type != Token.Type.COMMENT:
			for key in KindlyCompiler.PHRASES:
				var phrase: Array = KindlyCompiler.PHRASES[key]
				var matches := index + phrase.size() <= scanned.size()
				for offset in phrase.size():
					if not matches:
						break
					var part: Token = scanned[index + offset]
					matches = part.line == token.line and source.substr(part.start, part.length).to_lower() == phrase[offset]
				if matches:
					for offset in phrase.size():
						kinds[scanned[index + offset].start] = "keyword"
					if key in ["var", "define"] and index + phrase.size() < scanned.size():
						kinds[scanned[index + phrase.size()].start] = "definition" if key == "var" else "function"
					break
		previous_line = token.line
		if token.type in [Token.Type.LEFT_PARENTHESES, Token.Type.LEFT_BRACKET, Token.Type.LEFT_BRACE]:
			depth += 1
		elif token.type in [Token.Type.RIGHT_PARENTHESES, Token.Type.RIGHT_BRACKET, Token.Type.RIGHT_BRACE]:
			depth -= 1
	return kinds
