extends RefCounted

const Token = preload("res://engine/frontend/token.gd")
const ScanError = preload("res://engine/frontend/scan_error.gd")

# Assumptions:
# - Source string is tab indented, enforced by host application.
# - Source string uses "\n" instead of "\r\n", enforced by host application.

# Courtesy phrases are matched contextually by the compiler, not reserved here.
static var KEYWORD_TRIE: Trie = Trie.new({
	"and": Token.Type.AND,
	"false": Token.Type.FALSE,
	"none": Token.Type.NONE,
	"not": Token.Type.NOT,
	"or": Token.Type.OR,
	"true": Token.Type.TRUE,
})

var _source: String
var _start: int = 0
var _current: int = 0
var _line: int = 0

var _needs_line_start_processing: bool = true
## Whether the current logical line has code.
var _has_code_on_line: bool = false
var _indentation_stack: Array = [0]
var _current_indentation: int = 0
## Opening bracket tokens, to validate pairs and locate unclosed brackets.
var _brackets: Array[Token] = []
var _editor_mode := false
var _editor_tokens: Array[Token] = []


func _init(p_source: String):
	_source = p_source


## Returns all tokens including EOF, or the first ScanError without partial tokens.
func scan() -> Variant:
	var tokens: Array[Token] = []
	while true:
		var scanned: Variant = scan_token()
		if scanned is ScanError:
			return scanned

		var token: Token = scanned
		tokens.append(token)

		if token.type == Token.Type.EOF:
			return tokens

	return tokens


## Silently recovers partial tokens for highlighting, including comments.
func scan_for_editor() -> Array[Token]:
	_editor_mode = true
	while true:
		var token: Token = scan_token()
		if token.type == Token.Type.EOF:
			break
		if token.type not in [Token.Type.INDENT, Token.Type.DEDENT, Token.Type.NEWLINE]:
			_editor_tokens.append(token)
	return _editor_tokens


## Returns the next Token or a ScanError.
func scan_token() -> Variant:
	_start = _current

	# Handle empty lines and comment only lines.
	if _needs_line_start_processing:
		while true:
			var has_spaces := false
			_start = _current

			while _peek() == "\t" or _peek() == " ":
				match _advance():
					"\t": _current_indentation += 1
					" ": has_spaces = true

			# Blank line: restart and ignore whitespace correctness.
			if _peek() == "\n":
				_advance()
				_line += 1
				_current_indentation = 0
				continue

			# Comment only line: consume, restart, and ignore whitespace correctness.
			if _peek() == "#":
				_skip_comment()
				continue

			# As per Python, no whitespace validation is done inside brackets.
			if has_spaces and _peek() != "" and _brackets.is_empty():
				if not _editor_mode:
					return _build_error("Spaces are not allowed for indentation.")

			break

		# Only a new logical line can change indentation; EOF dedents are flushed in EOF block below.
		if _current < len(_source) and _brackets.is_empty():
			if _current_indentation > _indentation_stack[-1]:
				# As per Python, indenting multiple times is valid and only emits one INDENT.
				_indentation_stack.append(_current_indentation)
				_needs_line_start_processing = false
				return _build_token(Token.Type.INDENT)
			elif _current_indentation < _indentation_stack[-1]:
				if not _indentation_stack.any(func(level): return level == _current_indentation):
					if not _editor_mode:
						return _build_error("Unindent does not match any outer indentation level.")
					_indentation_stack = [0, _current_indentation]
				else:
					# Keep the line-start flag set until every dedent has been emitted.
					_indentation_stack.pop_back()
					# DEDENT is synthetic and consumes no source characters.
					_start = _current
					return _build_token(Token.Type.DEDENT)

		_needs_line_start_processing = false

	# Consume whitespace within or after code-line.
	while true:
		match _peek():
			" ", "\t": _advance()
			"#": _skip_comment()
			"\n":
				_start = _current
				_advance()
				# Build token first so the Token.line is set pre-incremented line.
				var newline_token := _build_token(Token.Type.NEWLINE)
				_line += 1
				_current_indentation = 0
				_needs_line_start_processing = true
				# Suppress NEWLINE in brackets.
				if not _brackets.is_empty():
					continue
				_has_code_on_line = false
				return newline_token
			_: break

	_start = _current

	# Handle EOF, flush unclosed newlines and dedentations.
	if _current >= len(_source):
		if not _brackets.is_empty():
			if not _editor_mode:
				var opening := _brackets[-1]
				return ScanError.new("Unclosed '%s'." % _source[opening.start], opening.line, opening.start, opening.length)
			_brackets.clear()

		if _has_code_on_line:
			_has_code_on_line = false
			return _build_token(Token.Type.NEWLINE)

		if len(_indentation_stack) > 1:
			_indentation_stack.pop_back()
			return _build_token(Token.Type.DEDENT)

		return _build_token(Token.Type.EOF)

	# A token on a continuation line also ends its physical line-start state.
	_needs_line_start_processing = false
	_has_code_on_line = true

	var chr := _advance()

	# Numbers.
	if StringUtils.is_digit(chr):
		return _scan_number()

	# Keywords and identifiers.
	if StringUtils.is_alpha(chr):
		return _scan_identifier()

	match chr:
		# Single-character tokens.
		"*": return _build_token(Token.Type.ASTERISK)
		":": return _build_token(Token.Type.COLON)
		",": return _build_token(Token.Type.COMMA)
		"{": return _open_bracket(Token.Type.LEFT_BRACE)
		"}": return _close_bracket(Token.Type.RIGHT_BRACE, Token.Type.LEFT_BRACE)
		"[": return _open_bracket(Token.Type.LEFT_BRACKET)
		"]": return _close_bracket(Token.Type.RIGHT_BRACKET, Token.Type.LEFT_BRACKET)
		"(": return _open_bracket(Token.Type.LEFT_PARENTHESES)
		")": return _close_bracket(Token.Type.RIGHT_PARENTHESES, Token.Type.LEFT_PARENTHESES)
		"-": return _build_token(Token.Type.MINUS)
		"%": return _build_token(Token.Type.PERCENT)
		".": return _build_token(Token.Type.DOT)
		"+": return _build_token(Token.Type.PLUS)
		"/": return _build_token(Token.Type.SLASH)
		# One or two character tokens.
		"!":
			if not _match('='):
				if _editor_mode:
					return _build_token(Token.Type.INVALID)
				return _build_error("'!' must be followed by '='.")
			return _build_token(Token.Type.BANG_EQUAL)
		"=":
			return _build_token(Token.Type.EQUAL_EQUAL if _match('=') else Token.Type.EQUAL)
		"<":
			return _build_token(Token.Type.LESS_EQUAL if _match('=') else Token.Type.LESS)
		">":
			return _build_token(Token.Type.GREATER_EQUAL if _match('=') else Token.Type.GREATER)
		# Literals.
		'"': return _scan_string()

	return _build_token(Token.Type.INVALID) if _editor_mode else _build_error("Unexpected character.")


#region Token scanning


## Consumes a comment, leaving its terminating newline unconsumed.
func _skip_comment() -> void:
	var start := _current
	while _peek() != "\n" and _peek() != "":
		_advance()
	if _editor_mode:
		_editor_tokens.append(Token.new(Token.Type.COMMENT, _line, start, _current - start))


## Scans a number after its first digit has been consumed.
func _scan_number() -> Token:
	while StringUtils.is_digit(_peek()):
		_advance()

	if _peek() == "." and StringUtils.is_digit(_peek(1)):
		_advance()
		while StringUtils.is_digit(_peek()):
			_advance()

	return _build_token(Token.Type.NUMBER)


## Only expression keywords are case-insensitive; identifier spelling is preserved by spans.
func _scan_identifier() -> Token:
	# Allow digits after the first character.
	while StringUtils.is_alpha(_peek()) or StringUtils.is_digit(_peek()):
		_advance()

	var keyword := _source.substr(_start, _current - _start)
	var token_type: Variant = KEYWORD_TRIE.search(keyword.to_lower())

	# Enum value of 0 is falsy, use != comparison.
	if token_type != null:
		return _build_token(token_type)

	return _build_token(Token.Type.IDENTIFIER)


## Scans a single-line string after its opening quote has been consumed.
func _scan_string() -> Variant:
	while _peek() not in ['"', "\n", ""]:
		_advance()

	# Require a closing quote before a newline or EOF.
	if not _match('"'):
		if not _editor_mode:
			return _build_error("Unterminated string.")

	return _build_token(Token.Type.STRING)


## Records an opening bracket so its matching closer can be validated.
func _open_bracket(type: Token.Type) -> Token:
	var token := _build_token(type)
	_brackets.append(token)
	return token


## Closes the most recent opening bracket, or reports an unmatched or mismatched closer.
func _close_bracket(type: Token.Type, expected_opening: Token.Type) -> Variant:
	if _brackets.is_empty():
		if not _editor_mode:
			return _build_error("Unmatched closing '%s'." % _source[_start])
		return _build_token(type)

	var opening := _brackets[-1]
	if opening.type != expected_opening:
		if not _editor_mode:
			return _build_error("Closing '%s' does not match opening '%s'." % [_source[_start], _source[opening.start]])

	_brackets.pop_back()
	return _build_token(type)


#endregion


#region Lexer helpers


## Returns the character without consuming it, or empty string past EOF.
func _peek(offset: int = 0) -> String:
	assert(offset >= 0, "Lookahead offset must be nonnegative.")
	if _current + offset >= len(_source):
		return ""

	return _source[_current + offset]


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


## Builds a scan error spanning the characters consumed since _start.
func _build_error(message: String) -> ScanError:
	return ScanError.new(message, _line, _start, _current - _start)


#endregion
