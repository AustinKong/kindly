extends RefCounted

# TODO: Consider error recovery afterwards. Right now we have a few error recovery infinite loops
# when handling errors to do with indentation. We can decide whether we want actual recovery.

# Assumptions:
# - Source string is tab indented, enforced by host application.
# - Source string uses "\n" instead of "\r\n", enforced by host application.

static var KEYWORD_TRIE := Trie.new({
	"and": Token.Type.AND,
	"def": Token.Type.DEF,
	"else": Token.Type.ELSE,
	"False": Token.Type.FALSE,
	"for": Token.Type.FOR,
	"if": Token.Type.IF,
	"None": Token.Type.NONE,
	"not": Token.Type.NOT,
	"or": Token.Type.OR,
	"return": Token.Type.RETURN,
	"True": Token.Type.TRUE,
	"while": Token.Type.WHILE,
})

var _source: String
var _start: int = 0
var _current: int = 0
var _line: int = 0

## Whether _current is at a physical line start.
var _is_line_start: bool = true
## Whether the current logical line has code.
var _has_code_on_line: bool = false
var _indentation_stack: Array = [0]
var _current_indentation: int = 0
var _bracket_depth: int = 0


func _init(p_source: String):
	_source = p_source


func scan():
	while true:
		var token := scan_token()

		if token.type == Token.Type.EOF:
			break


func scan_token() -> Token:
	_start = _current

	# Handle empty lines and comment only lines.
	if _is_line_start:
		while true:
			var has_spaces := false
			_current_indentation = 0
			_start = _current

			while _peek() == "\t" or _peek() == " ":
				match _advance():
					"\t": _current_indentation += 1
					" ": has_spaces = true

			# Blank line: restart and ignore whitespace correctness.
			if _peek() == "\n":
				_advance()
				_line += 1
				continue

			# Comment only line: consume, restart, and ignore whitespace correctness.
			if _peek() == "#":
				while _peek() != "\n" and _peek() != "":
					_advance()
				continue

			# As per Python, no whitespace validation is done inside brackets.
			if has_spaces and _peek() != "" and _bracket_depth == 0:
				return _build_error_token("Spaces are not allowed for indentation.")

			break

		_is_line_start = false

	# Handle indentation/dedentation.
	# Defer handling of EOF dedentation to EOF block below.
	# Suppress indentation/dedentation handling in brackets.
	if _current < len(_source) and _bracket_depth == 0:
		if _current_indentation > _indentation_stack[-1]:
			# As per Python, indenting multiple times is valid and only emits one INDENT.
			_indentation_stack.append(_current_indentation)
			return _build_token(Token.Type.INDENT)
		elif _current_indentation < _indentation_stack[-1]:
			if not _indentation_stack.any(func(level): return level == _current_indentation):
				return _build_error_token("Unindent does not match any outer indentation level.")

			_indentation_stack.pop_back()
			# DEDENT is synthetic and consumes no source characters.
			_start = _current
			return _build_token(Token.Type.DEDENT)

	# Consume whitespace within or after code-line.
	while true:
		match _peek():
			" ", "\t": _advance()
			"#":
				while _peek() != "\n" && _peek() != "":
					_advance()
			"\n":
				_start = _current
				_advance()
				# Build token first so the Token.line is set pre-incremented line.
				var newline_token := _build_token(Token.Type.NEWLINE)
				_line += 1
				_is_line_start = true
				# Suppress NEWLINE in brackets.
				if _bracket_depth > 0:
					continue
				_has_code_on_line = false
				return newline_token
			_: break

	_start = _current

	# Handle EOF, flush unclosed newlines and dedentations.
	if _current >= len(_source):
		if _has_code_on_line:
			_has_code_on_line = false
			return _build_token(Token.Type.NEWLINE)

		if _indentation_stack.size() > 1:
			_indentation_stack.pop_back()
			return _build_token(Token.Type.DEDENT)

		return _build_token(Token.Type.EOF)

	_has_code_on_line = true

	var chr := _advance()

	# Numbers.
	if StringUtils.is_digit(chr):
		while StringUtils.is_digit(_peek()):
			_advance()

		if _peek() == "." and StringUtils.is_digit(_peek_next()):
			_advance()
			while StringUtils.is_digit(_peek()):
				_advance()

		return _build_token(Token.Type.NUMBER)

	# Keywords and identifiters.
	if StringUtils.is_alpha(chr):
		# Allow digits after first character.
		while StringUtils.is_alpha(_peek()) or StringUtils.is_digit(_peek()):
			_advance()

		var keyword := _source.substr(_start, _current - _start)
		var token_type: Variant = KEYWORD_TRIE.search(keyword)

		# Enum value of 0 is falsy, use != comparison.
		if token_type != null:
			return _build_token(token_type)

		return _build_token(Token.Type.IDENTIFIER)

	match chr:
		# Single-character tokens.
		"*": return _build_token(Token.Type.ASTERISK)
		":": return _build_token(Token.Type.COLON)
		",": return _build_token(Token.Type.COMMA)
		"{":
			_bracket_depth += 1
			return _build_token(Token.Type.LEFT_BRACE)
		"}":
			_bracket_depth -= 1
			return _build_token(Token.Type.RIGHT_BRACE)
		"[":
			_bracket_depth += 1
			return _build_token(Token.Type.LEFT_BRACKET)
		"]":
			_bracket_depth -= 1
			return _build_token(Token.Type.RIGHT_BRACKET)
		"(":
			_bracket_depth += 1
			return _build_token(Token.Type.LEFT_PARENTHESES)
		")":
			_bracket_depth -= 1
			return _build_token(Token.Type.RIGHT_PARENTHESES)
		"-": return _build_token(Token.Type.MINUS)
		"%": return _build_token(Token.Type.PERCENT)
		".": return _build_token(Token.Type.PERIOD)
		"+": return _build_token(Token.Type.PLUS)
		"/": return _build_token(Token.Type.SLASH)
		# One or two character tokens.
		"!":
			if not _match('='):
				return _build_error_token("'!' must be followed by '='.")
			return _build_token(Token.Type.BANG_EQUAL)
		"=":
			return _build_token(Token.Type.EQUAL_EQUAL if _match('=') else Token.Type.EQUAL)
		"<":
			return _build_token(Token.Type.LESS_EQUAL if _match('=') else Token.Type.LESS)
		">":
			return _build_token(Token.Type.GREATER_EQUAL if _match('=') else Token.Type.GREATER)
		# Literals.
		'"':
			while _peek() not in ['"', "\n", ""]:
				_advance()

			# Require a closing quote before a newline or EOF.
			if not _match('"'):
				return _build_error_token("Unterminated string.")

			return _build_token(Token.Type.STRING)

	return _build_error_token("Unexpected character.")


## Returns the current character without consuming it, or empty string if EOF.
func _peek() -> String:
	if _current >= len(_source):
		return ""

	return _source[_current]


## Returns the next character without consuming it, or empty string if EOF.
func _peek_next() -> String:
	if _current + 1 >= len(_source):
		return ""

	return _source[_current + 1]


## Consumes current character if it matches expected and returns true; returns false otherwise.
func _match(expected: String) -> bool:
	if _current >= len(_source):
		return false

	if _source[_current] != expected:
		return false

	_current += 1
	return true


## Consumes current character and returns it.
func _advance() -> String:
	var c := _source[_current]
	_current += 1
	return c


## Builds a token spanning the characters consumed since _start.
func _build_token(type: Token.Type) -> Token:
	return Token.new(type, _line, _start, _current - _start)


## Builds an error token with a source span and a separate diagnostic message.
func _build_error_token(message: String) -> Token:
	return Token.new(Token.Type.ERROR, _line, _start, _current - _start, message)
