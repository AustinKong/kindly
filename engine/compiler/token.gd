class_name Token
extends RefCounted

enum Type {
	# Single-character tokens.
	ASTERISK, COLON, COMMA,
	LEFT_BRACE, RIGHT_BRACE,
	LEFT_BRACKET, RIGHT_BRACKET,
	LEFT_PARENTHESES, RIGHT_PARENTHESES,
	MINUS, PERCENT, PERIOD, PLUS, SLASH,
	# One or two character tokens.
	# Call it BANG_EQUAL instead of NOT_EQUAL to disambiguate with NOT.
	BANG_EQUAL,
	EQUAL, EQUAL_EQUAL,
	GREATER, GREATER_EQUAL,
	LESS, LESS_EQUAL,
	# Literals.
	IDENTIFIER, NUMBER, STRING,
	# Keywords.
	AND, DEF, ELSE, FALSE, FOR, IF,
	NONE, NOT, OR, RETURN, TRUE, WHILE,
	# Whitespace.
	DEDENT, INDENT, NEWLINE,
	# Misc.
	EOF, ERROR
}

var type: Type
var line: int
## Character offset in the lexer's normalized source.
var start: int
var length: int
## Diagnostic text for ERROR tokens; empty for other token types.
var message: String

func _init(p_type: Type, p_line: int, p_start: int, p_length: int, p_message: String = ""):
	type = p_type
	line = p_line
	start = p_start
	length = p_length
	message = p_message
