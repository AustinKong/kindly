extends RefCounted

## Compiles expressions directly to bytecode using a binding power Pratt parser.
## Prefix handlers parse the start of an expression; infix handlers extend an existing one.

const Compiler = preload("res://engine/frontend/compiler/compiler.gd")
const Function = preload("res://engine/runtime/function.gd")
const Token = preload("res://engine/frontend/token.gd")
const OpCode = preload("res://engine/runtime/opcode.gd")
const CompileError = preload("res://engine/frontend/compiler/compile_error.gd")

const MIN_JUMP_OFFSET: int = -0x8000
const MAX_JUMP_OFFSET: int = 0x7fff


class ParseRule extends RefCounted:
	## Handler used when this token starts an expression. E.g. -x, 42, (x).
	var prefix: Callable
	var prefix_bp: int
	## Handler used when this token follows an existing expression. E.g. x + y, f().
	var infix: Callable
	var left_bp: int
	var right_bp: int

	func _init(
		p_prefix: Callable = Callable(),
		p_prefix_bp: int = 0,
		p_infix: Callable = Callable(),
		p_left_bp: int = 0,
		p_right_bp: int = 0
	) -> void:
		prefix = p_prefix
		prefix_bp = p_prefix_bp
		infix = p_infix
		left_bp = p_left_bp
		right_bp = p_right_bp


class Local extends RefCounted:
	var name: String
	var depth: int
	var is_initialized: bool = false

	func _init(p_name: String, p_depth: int) -> void:
		name = p_name
		depth = p_depth


class Upvalue extends RefCounted:
	## Tracks the index this upvalue references in enclosing's _upvalues or _locals arrays.
	var index_in_enclosing: int
	## If true, index_in_enclosing references _locals array, otherwise references _upvalues array.
	var is_local: bool

	func _init(p_index_in_enclosing: int, p_is_local: bool) -> void:
		index_in_enclosing = p_index_in_enclosing
		is_local = p_is_local


var RULES: Dictionary[int, ParseRule]

# https://www.youtube.com/watch?v=0c8b7YfsBKs

var _tokens: Array[Token] = []
# TODO: Maybe make this point to the current parsed token instead so we dont' have to keep checking previous.
## Index of the current unconsumed token; equals the token count after consuming EOF.
var _token_index: int = 0
## Retained to look up lexemes during compilation using each token's start and length.
var _source: String

var _function: Function = Function.new()
## Whether the _function referenced is the script-level function object.
var _is_script: bool

var _locals: Array[Local] = []
var _scope_depth := 0

var _enclosing: Compiler
var _upvalues: Array[Upvalue] = []

## Only the first error is retained; any partial function is discarded on failure.
var _compile_error: CompileError


# TODO: Technically enclosing holds enough info to identify is_script?
## Creates a compilation context over source and tokens, starting at the given unconsumed token.
func _init(p_source: String, p_tokens: Array[Token], p_enclosing: Compiler = null, p_is_script: bool = true, p_token_index: int = 0) -> void:
	_source = p_source
	_tokens = p_tokens
	_enclosing = p_enclosing
	_is_script = p_is_script
	_token_index = p_token_index

	# Need to be assigned in _init because we use Callable which are not compile time assignable.
	RULES = {
		Token.Type.NUMBER: ParseRule.new(_parse_number),
		Token.Type.STRING: ParseRule.new(_parse_string),
		Token.Type.IDENTIFIER: ParseRule.new(_parse_variable),
		Token.Type.TRUE: ParseRule.new(_parse_literal),
		Token.Type.FALSE: ParseRule.new(_parse_literal),
		Token.Type.NONE: ParseRule.new(_parse_literal),
		Token.Type.LEFT_PARENTHESES: ParseRule.new(
			_parse_grouping, 0, _parse_call, 170, 171
		),
		Token.Type.LEFT_BRACKET: ParseRule.new(
			_parse_list, 0, _parse_index, 170, 171
		),
		Token.Type.LEFT_BRACE: ParseRule.new(_parse_dictionary),
		Token.Type.DOT: ParseRule.new(
			Callable(), 0, _parse_property, 170, 171
		),
		Token.Type.PLUS: ParseRule.new(
			_parse_unary, 140, _parse_binary, 120, 121
		),
		Token.Type.MINUS: ParseRule.new(
			_parse_unary, 140, _parse_binary, 120, 121
		),
		Token.Type.ASTERISK: ParseRule.new(
			Callable(), 0, _parse_binary, 130, 131
		),
		Token.Type.SLASH: ParseRule.new(
			Callable(), 0, _parse_binary, 130, 131
		),
		Token.Type.PERCENT: ParseRule.new(
			Callable(), 0, _parse_binary, 130, 131
		),
		Token.Type.EQUAL_EQUAL: ParseRule.new(
			Callable(), 0, _parse_binary, 70, 71
		),
		Token.Type.BANG_EQUAL: ParseRule.new(
			Callable(), 0, _parse_binary, 70, 71
		),
		Token.Type.LESS: ParseRule.new(
			Callable(), 0, _parse_binary, 70, 71
		),
		Token.Type.LESS_EQUAL: ParseRule.new(
			Callable(), 0, _parse_binary, 70, 71
		),
		Token.Type.GREATER: ParseRule.new(
			Callable(), 0, _parse_binary, 70, 71
		),
		Token.Type.GREATER_EQUAL: ParseRule.new(
			Callable(), 0, _parse_binary, 70, 71
		),
		Token.Type.NOT: ParseRule.new(_parse_unary, 60),
		Token.Type.AND: ParseRule.new(
			Callable(), 0, _parse_and, 50, 51
		),
		Token.Type.OR: ParseRule.new(
			Callable(), 0, _parse_or, 40, 41
		),
	}


## Returns a compiled Function or the first CompileError, discarding partial output on failure.
func compile() -> Variant:
	if _is_script:
		while _compile_error == null and _current().type != Token.Type.EOF:
			_parse_declaration()
	else:
		_scope_depth += 1

		_parse_parameters()
		_parse_block()

		_end_scope()

	if not _is_script:
		_emit_byte(OpCode.NONE)
	_emit_byte(OpCode.RETURN)

	if _compile_error != null:
		return _compile_error
	return _function


#region Parsing


## Parses a variable or function declaration, falling back to a statement.
func _parse_declaration():
	if _match(Token.Type.VAR):
		_parse_variable_declaration()
	elif _match(Token.Type.DEF):
		_parse_function_declaration()
	else:
		_parse_statement()


## Parses 'var name' with an optional initializer, then defines the variable.
func _parse_variable_declaration() -> void:
	_consume(Token.Type.IDENTIFIER, "Expect variable name after 'var'.")

	var constant_index: int
	var local_index: Variant = null
	if _scope_depth == 0:
		constant_index = _add_constant(_previous_lexeme())
	else:
		# Detect duplicate local variables within scope.
		local_index = _declare_local(_previous_lexeme())
		if local_index == null:
			return

	if _match(Token.Type.EQUAL):
		_parse_expression()
	else:
		_emit_byte(OpCode.NONE)

	_consume(Token.Type.NEWLINE, "Expect newline after variable declaration.")

	if _scope_depth == 0:
		_emit_byte(OpCode.DEFINE_GLOBAL)
		_emit_byte(constant_index)
	else:
		_emit_byte(OpCode.DEFINE_LOCAL)
		_locals[local_index].is_initialized = true


func _parse_function_declaration():
	if not _consume(Token.Type.IDENTIFIER, "Expect function name."):
		return
	var function_name := _previous_lexeme()
	var name_constant_index := _add_constant(function_name)

	# Need to add function to locals before compilation and CLOSURE, such that the closure captures its own name for recursion.
	var local_index: Variant
	if _scope_depth > 0:
		local_index = _declare_local(function_name, true)
		if local_index == null:
			return
		# Register as NONE first as the function isn't compiled yet.
		_emit_byte(OpCode.NONE)
		_emit_byte(OpCode.DEFINE_LOCAL)

	var function_compiler := Compiler.new(_source, _tokens, self, false, _token_index)

	var compiled: Variant = function_compiler.compile()
	# Continue where the function compilation left-off.
	_token_index = function_compiler._token_index

	if compiled is CompileError:
		if _compile_error == null:
			_compile_error = compiled
		return

	var function: Function = compiled
	function.name = function_name

	_emit_byte(OpCode.CLOSURE)
	_emit_byte(_add_constant(function))

	# Emit pairs of is_local and index.
	for i in range(function.upvalue_count):
		_emit_byte(1 if function_compiler._upvalues[i].is_local else 0)
		_emit_byte(function_compiler._upvalues[i].index_in_enclosing)

	if _scope_depth == 0:
		_emit_byte(OpCode.DEFINE_GLOBAL)
		_emit_byte(name_constant_index)
	else:
		_emit_byte(OpCode.SET_LOCAL)
		_emit_byte(local_index)
		_emit_byte(OpCode.POP)


## Parses parameter names and registers them as initialized locals in the function's scope.
func _parse_parameters() -> void:
	if not _consume(Token.Type.LEFT_PARENTHESES, "Expect '(' before parameters."):
		return
	if _current().type != Token.Type.RIGHT_PARENTHESES:
		while true:
			if not _consume(Token.Type.IDENTIFIER, "Expect parameter name."):
				return
			var local_index: Variant = _declare_local(_previous_lexeme(), true)
			if local_index == null:
				return
			_function.arity += 1

			if not _match(Token.Type.COMMA):
				break

	_consume(Token.Type.RIGHT_PARENTHESES, "Expect ')' after parameters.")


## Scope lifetime is managed outside of _parse_block as function parameters should exist in same scope as its block.
func _parse_block():
	_consume(Token.Type.COLON, "Expect ':' before block.")
	_consume(Token.Type.NEWLINE, "Expect newline before block.")
	_consume(Token.Type.INDENT, "Expect indent before block.")

	while _compile_error == null and _current().type != Token.Type.DEDENT and _current().type != Token.Type.EOF:
		_parse_declaration()

	_consume(Token.Type.DEDENT, "Expect dedent after block.")


## Parses a block in a new scope and emits cleanup for its locals.
func _parse_scoped_block() -> void:
	_scope_depth += 1
	_parse_block()
	_end_scope()


func _parse_statement():
	if _match(Token.Type.IF):
		_parse_if_statement()
	elif _match(Token.Type.WHILE):
		_parse_while_statement()
	elif _match(Token.Type.FOR):
		_parse_for_statement()
	elif _match(Token.Type.RETURN):
		_parse_return_statement()
	elif _current().type == Token.Type.IDENTIFIER and _peek().type == Token.Type.EQUAL:
		_parse_variable_assignment()
	else:
		_parse_expression_statement()


func _parse_return_statement():
	if _match(Token.Type.NEWLINE):
		_emit_byte(OpCode.NONE)
	else:
		_parse_expression()
		_consume(Token.Type.NEWLINE, "Expect newline after return value.")

	_emit_byte(OpCode.RETURN)


func _parse_if_statement():
	_parse_expression()

	var if_jump_backpatch_position := _emit_jump(OpCode.JUMP_IF_FALSE)
	_emit_byte(OpCode.POP)

	_parse_scoped_block()

	var else_jump_backpatch_position := _emit_jump(OpCode.JUMP)
	_patch_jump(if_jump_backpatch_position)
	_emit_byte(OpCode.POP)

	if _match(Token.Type.ELSE):
		_parse_scoped_block()
	_patch_jump(else_jump_backpatch_position)


func _parse_while_statement():
	var loop_start := len(_function.chunk.code)
	_parse_expression()

	var exit_backpatch_position := _emit_jump(OpCode.JUMP_IF_FALSE)
	_emit_byte(OpCode.POP)

	_parse_scoped_block()

	_emit_jump(OpCode.JUMP, loop_start)

	_patch_jump(exit_backpatch_position)
	_emit_byte(OpCode.POP)


func _parse_for_statement():
	# TODO: Allow non declaration in for loop as well.
	_consume(Token.Type.VAR, "Expected 'var' after 'for'.")
	_consume(Token.Type.IDENTIFIER, "Expected loop variable.")

	_scope_depth += 1
	# No need any duplicate detection checks as this is always the first local in this scope.
	var name := _previous_lexeme()
	var counter_local_index: Variant = _declare_local(name)
	if counter_local_index == null:
		_end_scope()
		return

	_consume(Token.Type.EQUAL, "Expected '=' after loop variable.")
	_parse_expression()
	_emit_byte(OpCode.DEFINE_LOCAL)
	_locals[counter_local_index].is_initialized = true

	_consume(Token.Type.TO, "Expected 'to' after loop initializer.")

	# Evaluate expression once only.
	_parse_expression()
	# Unnammed local is one that user cannot reference.
	var end_local_index: Variant = _declare_local("", true)
	if end_local_index == null:
		_end_scope()
		return
	_emit_byte(OpCode.DEFINE_LOCAL)

	if _match(Token.Type.STEP):
		_parse_expression()
	else:
		# Default step to 1.
		_emit_constant(1)

	var step_local_index: Variant = _declare_local("", true)
	if step_local_index == null:
		_end_scope()
		return
	_emit_byte(OpCode.DEFINE_LOCAL)

	var loop_start := len(_function.chunk.code)

	# Check (i - end) * step < 0 at runtime to handle both positive and negative steps.
	_emit_byte(OpCode.GET_LOCAL)
	_emit_byte(counter_local_index)
	_emit_byte(OpCode.GET_LOCAL)
	_emit_byte(end_local_index)
	_emit_byte(OpCode.SUBTRACT)
	_emit_byte(OpCode.GET_LOCAL)
	_emit_byte(step_local_index)
	_emit_byte(OpCode.MULTIPLY)
	_emit_constant(0)
	_emit_byte(OpCode.LESS)

	var exit_backpatch_position := _emit_jump(OpCode.JUMP_IF_FALSE)
	_emit_byte(OpCode.POP)

	_parse_scoped_block()

	# Increment counter by step.
	_emit_byte(OpCode.GET_LOCAL)
	_emit_byte(counter_local_index)
	_emit_byte(OpCode.GET_LOCAL)
	_emit_byte(step_local_index)
	_emit_byte(OpCode.ADD)
	_emit_byte(OpCode.SET_LOCAL)
	_emit_byte(counter_local_index)
	_emit_byte(OpCode.POP)

	_emit_jump(OpCode.JUMP, loop_start)

	_patch_jump(exit_backpatch_position)
	_emit_byte(OpCode.POP)

	_end_scope()


## Reassigns one existing variable; chained assignment is rejected.
func _parse_variable_assignment() -> void:
	_advance()

	var name := _previous_lexeme()

	var set_opcode
	var operand

	var local_index: Variant = _resolve_local(name)
	if local_index != null:
		set_opcode = OpCode.SET_LOCAL
		operand = local_index
	else:
		var upvalue_index: Variant = _resolve_upvalue(name)
		if upvalue_index != null:
			set_opcode = OpCode.SET_UPVALUE
			operand = upvalue_index
		else:
			set_opcode = OpCode.SET_GLOBAL
			operand = _add_constant(name)

	_consume(Token.Type.EQUAL, "Expect '=' after assignment target.")
	_parse_expression()
	_consume(Token.Type.NEWLINE, "Expect newline after assignment.")

	_emit_byte(set_opcode)
	_emit_byte(operand)
	_emit_byte(OpCode.POP)


func _parse_expression_statement():
	# Parse things like functions.
	_parse_expression()
	_consume(Token.Type.NEWLINE, "Expect newline after expression.")
	_emit_byte(OpCode.POP)


## Parses an expression starting at _current(), using min_bp as its binding power threshold.
func _parse_expression(min_bp: int = 0) -> void:
	_advance()

	var rule: ParseRule = RULES.get(_previous().type)
	if rule == null or not rule.prefix.is_valid():
		_error("Expected expression.", _previous())
		return
	rule.prefix.call(rule.prefix_bp)

	while _compile_error == null:
		rule = RULES.get(_current().type)
		if rule == null or not rule.infix.is_valid():
			break
		if rule.left_bp < min_bp:
			break

		_advance()
		rule.infix.call(rule.right_bp)


func _parse_number(_min_bp: int) -> void:
	_emit_constant(_previous_lexeme().to_float())


func _parse_string(_min_bp: int) -> void:
	var lexeme := _previous_lexeme()
	_emit_constant(lexeme.substr(1, len(lexeme) - 2))


func _parse_literal(_min_bp: int) -> void:
	match _previous().type:
		Token.Type.TRUE: _emit_byte(OpCode.TRUE)
		Token.Type.FALSE: _emit_byte(OpCode.FALSE)
		Token.Type.NONE: _emit_byte(OpCode.NONE)


func _parse_variable(_min_bp: int) -> void:
	var name := _previous_lexeme()

	var local_index: Variant = _resolve_local(name)
	if local_index != null:
		if not _locals[local_index].is_initialized:
			_error("Cannot read local variable in its own initializer.", _previous())
		_emit_byte(OpCode.GET_LOCAL)
		_emit_byte(local_index)
		return

	var upvalue_index: Variant = _resolve_upvalue(name)
	if upvalue_index != null:
		_emit_byte(OpCode.GET_UPVALUE)
		_emit_byte(upvalue_index)
		return

	_emit_byte(OpCode.GET_GLOBAL)
	_emit_byte(_add_constant(name))


## Parses a parenthesized expression with a fresh binding power threshold and consumes ')'.
func _parse_grouping(_min_bp: int) -> void:
	_parse_expression()
	_consume(Token.Type.RIGHT_PARENTHESES, "Expect ')' after expression.")


## Parses a unary operator's operand at min_bp, then emits the operator's instruction.
func _parse_unary(min_bp: int) -> void:
	var operator := _previous().type
	_parse_expression(min_bp)
	match operator:
		Token.Type.MINUS: _emit_byte(OpCode.NEGATE)
		Token.Type.NOT: _emit_byte(OpCode.NOT)


## Parses a binary operator's right operand at min_bp, then emits the operator's instruction.
func _parse_binary(min_bp: int) -> void:
	var operator := _previous()
	_parse_expression(min_bp)
	match operator.type:
		Token.Type.PLUS: _emit_byte(OpCode.ADD)
		Token.Type.MINUS: _emit_byte(OpCode.SUBTRACT)
		Token.Type.ASTERISK: _emit_byte(OpCode.MULTIPLY)
		Token.Type.SLASH: _emit_byte(OpCode.DIVIDE)
		Token.Type.EQUAL_EQUAL: _emit_byte(OpCode.EQUAL)
		Token.Type.BANG_EQUAL:
			_emit_byte(OpCode.EQUAL)
			_emit_byte(OpCode.NOT)
		Token.Type.GREATER: _emit_byte(OpCode.GREATER)
		Token.Type.GREATER_EQUAL:
			_emit_byte(OpCode.LESS)
			_emit_byte(OpCode.NOT)
		Token.Type.LESS: _emit_byte(OpCode.LESS)
		Token.Type.LESS_EQUAL:
			_emit_byte(OpCode.GREATER)
			_emit_byte(OpCode.NOT)
		_: _error("Binary operator is not implemented yet.", operator)


func _parse_and(min_bp: int) -> void:
	var backpatch_position := _emit_jump(OpCode.JUMP_IF_FALSE)
	_emit_byte(OpCode.POP)
	_parse_expression(min_bp)
	_patch_jump(backpatch_position)


func _parse_or(min_bp: int) -> void:
	var backpatch_position := _emit_jump(OpCode.JUMP_IF_TRUE)
	_emit_byte(OpCode.POP)
	_parse_expression(min_bp)
	_patch_jump(backpatch_position)


func _parse_call(_min_bp: int) -> void:
	var arg_count := 0
	if _current().type != Token.Type.RIGHT_PARENTHESES:
		while true:
			_parse_expression()
			arg_count += 1

			if not _match(Token.Type.COMMA):
				break

	_consume(Token.Type.RIGHT_PARENTHESES, "Expect ')' after arguments.")
	_emit_byte(OpCode.CALL)
	_emit_byte(arg_count)


func _parse_index(_min_bp: int) -> void:
	_error("Indexing is not implemented yet.", _previous())


func _parse_property(_min_bp: int) -> void:
	_error("Property access is not implemented yet.", _previous())


func _parse_list(_min_bp: int) -> void:
	_error("List literals are not implemented yet.", _previous())


func _parse_dictionary(_min_bp: int) -> void:
	_error("Dictionary literals are not implemented yet.", _previous())


#endregion


#region Compiler helpers


## Returns the current unconsumed token, or EOF after the token list is exhausted.
func _current() -> Token:
	return _peek(0)


## Returns the last consumed token, or null if no token has been consumed.
func _previous() -> Token:
	if _token_index == 0:
		return null
	return _tokens[_token_index - 1]


## Returns the token offset positions after _current() without advancing, or EOF past the end.
func _peek(offset: int = 1) -> Token:
	assert(offset >= 0, "Lookahead offset must be nonnegative.")
	return _tokens[mini(_token_index + offset, len(_tokens) - 1)]


## Returns the source text covered by the last consumed token.
func _previous_lexeme() -> String:
	var token := _previous()
	return _source.substr(token.start, token.length)


## Consumes the current token, allowing EOF to be consumed once.
func _advance() -> void:
	_token_index = mini(_token_index + 1, len(_tokens))


## Consumes _current() and returns true if its type matches; otherwise returns false.
func _match(type: Token.Type) -> bool:
	if _current().type != type:
		return false

	_advance()
	return true


## Consumes _current() if its type matches, or records an error and returns false.
func _consume(type: Token.Type, message_if_invalid: String) -> bool:
	if _match(type):
		return true

	_error(message_if_invalid)
	return false


## Returns the nearest index in _locals, or null if absent; indices address frame cells directly.
func _resolve_local(name: String) -> Variant:
	# Unnamed locals are referenced purely via index received at creation. Their lifecycle is managed by VM.
	if name == "" or _scope_depth == 0:
		return null

	for local_index in range(len(_locals) - 1, -1, -1):
		if _locals[local_index].name == name:
			return local_index
	return null


func _resolve_upvalue(name: String) -> Variant:
	if _enclosing == null:
		return null

	var enclosing_local: Variant = _enclosing._resolve_local(name)
	if enclosing_local != null:
		return _add_upvalue(enclosing_local, true)

	var enclosing_upvalue: Variant = _enclosing._resolve_upvalue(name)
	if enclosing_upvalue != null:
		return _add_upvalue(enclosing_upvalue, false)

	return null


## Attempts to add an upvalue to _upvalues array and returns index; returns existing index instead if found.
func _add_upvalue(index: int, is_local: bool) -> int:
	# Don't recreate an upvalue if it already exists with same index and is_local
	for i in range(len(_upvalues)):
		if _upvalues[i].index_in_enclosing == index and _upvalues[i].is_local == is_local:
			return i
	_upvalues.append(Upvalue.new(index, is_local))
	# This count should always match the length of _upvalues array.
	_function.upvalue_count += 1
	return _function.upvalue_count - 1


## Registers local metadata without consuming tokens or emitting bytecode; returns its index or null on failure.
## Empty names identify temporaries; initialized locals can be read immediately.
func _declare_local(name: String, is_initialized: bool = false) -> Variant:
	if len(_locals) >= 255:
		_error("Too many local variables in function.", _previous())
		return null

	var existing_local_index: Variant = _resolve_local(name)
	if existing_local_index != null and _locals[existing_local_index].depth == _scope_depth:
		_error("Already a variable with this name in this scope.", _previous())
		return null

	var local := Local.new(name, _scope_depth)
	local.is_initialized = is_initialized
	_locals.append(local)
	return len(_locals) - 1


func _end_scope() -> void:
	_scope_depth -= 1
	# Remove local cells belonging to the scope being exited.
	while len(_locals) > 0 and _locals[-1].depth > _scope_depth:
		_emit_byte(OpCode.POP_LOCAL)
		_locals.pop_back()


## Adds a constant that can be addressed by a one-byte operand.
func _add_constant(value: Variant) -> int:
	if len(_function.chunk.constants) >= 256:
		_error("Too many constants in one function.", _previous())
		return 0
	return _function.chunk.add_constant(value)


## Emits a byte, using the current token's line if nothing has been consumed yet.
func _emit_byte(byte: int) -> void:
	var token := _previous()
	if token == null:
		token = _current()
	_function.chunk.append(byte, token.line)


## Adds a constant and emits the instruction that pushes its value onto the stack.
func _emit_constant(value: Variant) -> void:
	var constant_index := _add_constant(value)
	_emit_byte(OpCode.CONSTANT)
	_emit_byte(constant_index)


## Emits a jump to an absolute bytecode position.
## If target is omitted, emits a placeholder for backpatching; in which case should be paired with _patch_jump.
func _emit_jump(instruction: int, target: Variant = null) -> int:
	var operand_position := len(_function.chunk.code) + 1
	# If target is not provided, this will just be garbage, expected to be backpatched over.
	var offset := 0
	if target != null:
		offset = int(target) - operand_position - 2

	_emit_byte(instruction)
	# TODO: Still return int? Or return null or the error contract is consistent.
	if offset < MIN_JUMP_OFFSET or offset > MAX_JUMP_OFFSET:
		_error("Jump offset must be between -32768 and 32767.", _previous())

	_emit_byte((offset >> 8) & 0xff)
	_emit_byte(offset & 0xff)
	return operand_position


## Backpatch a jump instruction's operand to the current bytecode location.
## Should be paired with _emit_jump.
func _patch_jump(operand_position: int) -> void:
	var offset := len(_function.chunk.code) - operand_position - 2
	if offset < MIN_JUMP_OFFSET or offset > MAX_JUMP_OFFSET:
		_error("Jump offset must be between -32768 and 32767.", _previous())
		return
	_function.chunk.code[operand_position] = (offset >> 8) & 0xff
	_function.chunk.code[operand_position + 1] = offset & 0xff


## Retains the first diagnostic; active handlers may finish, but their output is discarded.
func _error(message: String, token: Token = null) -> void:
	if _compile_error != null:
		return

	if token == null:
		token = _current()
	_compile_error = CompileError.new(message, token.line, token.start, token.length)


#endregion
