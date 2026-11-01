extends RefCounted

## Compiles expressions directly to bytecode using a binding power Pratt parser.
## Prefix handlers parse the start of an expression; infix handlers extend an existing one.

const Compiler = preload("res://engine/frontend/compiler/compiler.gd")
const Token = preload("res://engine/frontend/token.gd")
const CompileError = preload("res://engine/frontend/compiler/compile_error.gd")
const CompiledFunction = preload("res://engine/bytecode/compiled_function.gd")
const OpCode = preload("res://engine/bytecode/opcode.gd")

const MAX_LOCALS: int = 255
const MAX_CONSTANTS: int = 256
const MAX_ARGUMENTS: int = 255
const MAX_LIST_ELEMENTS: int = 255
const MAX_DICTIONARY_ENTRIES: int = 255
const MAX_UPVALUES: int = 256
const MIN_JUMP_OFFSET: int = -0x8000
const MAX_JUMP_OFFSET: int = 0x7fff

const ASSIGNMENT_BP: int = 0


# Fixed grammar table. Rule objects and bound handlers require instance initialization.
# Pratt parser reference: https://www.youtube.com/watch?v=0c8b7YfsBKs
var RULES: Dictionary[int, ParseRule] = {
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
		_parse_list, 0, _parse_subscript, 170, 171
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


class Binding extends RefCounted:
	## Resolved operand and the instructions which read or update that binding.
	var index: int
	var get_opcode: int
	var set_opcode: int

	func _init(p_index: int, p_get_opcode: int, p_set_opcode: int) -> void:
		index = p_index
		get_opcode = p_get_opcode
		set_opcode = p_set_opcode


class Local extends RefCounted:
	var name: String
	var depth: int
	var is_initialized: bool = false

	func _init(p_name: String, p_depth: int) -> void:
		name = p_name
		depth = p_depth


class Upvalue extends RefCounted:
	## Index into the enclosing compiler's locals or upvalues, selected by is_local.
	var index_in_enclosing: int
	var is_local: bool

	func _init(p_index_in_enclosing: int, p_is_local: bool) -> void:
		index_in_enclosing = p_index_in_enclosing
		is_local = p_is_local


class Loop extends RefCounted:
	var scope_depth: int
	var break_jumps: Array[int] = []
	var continue_jumps: Array[int] = []

	func _init(p_scope_depth: int) -> void:
		scope_depth = p_scope_depth


var _tokens: Array[Token] = []
## Index of the current unconsumed token; equals the token count after consuming EOF.
var _token_index: int = 0
## Retained to look up lexemes during compilation using each token's start and length.
var _source: String

var _function: CompiledFunction = CompiledFunction.new()

## Null for the script; declared functions reference their enclosing compiler.
var _enclosing: Compiler
var _scope_depth: int = 0
var _globals: Dictionary[String, bool] = {}
var _locals: Array[Local] = []
var _upvalues: Array[Upvalue] = []
var _loops: Array[Loop] = []

## Only the first error is retained; any partial function is discarded on failure.
var _compile_error: CompileError


## Creates a compilation context over source and tokens, starting at the given unconsumed token.
func _init(
	p_source: String,
	p_tokens: Array[Token],
	p_enclosing: Compiler = null,
	p_token_index: int = 0
) -> void:
	_source = p_source
	_tokens = p_tokens
	_enclosing = p_enclosing
	_token_index = p_token_index


## Returns a CompiledFunction or the first CompileError, discarding partial output on failure.
func compile() -> Variant:
	if _enclosing == null:
		while _compile_error == null and _current().type != Token.Type.EOF:
			_parse_declaration()
	else:
		_scope_depth += 1

		_parse_parameters()
		_parse_block()

		_end_scope()

	if _enclosing != null:
		_emit_instruction(OpCode.NONE)
	_emit_instruction(OpCode.RETURN)

	if _compile_error != null:
		return _compile_error
	return _function


#region Parsing


## Parses a variable or function declaration, falling back to a statement.
func _parse_declaration() -> void:
	if _match(Token.Type.VAR):
		_parse_variable_declaration()
	elif _match(Token.Type.DEF):
		_parse_function_declaration()
	else:
		_parse_statement()


## Parses 'var name' with an optional initializer, then defines the variable.
func _parse_variable_declaration() -> void:
	if not _consume(Token.Type.IDENTIFIER, "Expect variable name after 'var'."):
		return

	var constant_index: Variant = null
	var local_index: Variant = null
	if _scope_depth == 0:
		constant_index = _declare_global(_previous_lexeme())
		if constant_index == null:
			return
	else:
		# Detect duplicate local variables within scope.
		local_index = _declare_local(_previous_lexeme())
		if local_index == null:
			return

	if _match(Token.Type.EQUAL):
		_parse_expression()
	else:
		_emit_instruction(OpCode.NONE)

	_consume(Token.Type.NEWLINE, "Expect newline after variable declaration.")

	if _scope_depth == 0:
		_emit_instruction(OpCode.DEFINE_GLOBAL, constant_index)
	else:
		_emit_instruction(OpCode.DEFINE_LOCAL)
		_locals[local_index].is_initialized = true


func _parse_function_declaration() -> void:
	if not _consume(Token.Type.IDENTIFIER, "Expect function name."):
		return
	var function_name := _previous_lexeme()
	var name_constant_index: Variant = _declare_global(function_name) if _scope_depth == 0 else _add_constant(function_name)
	if name_constant_index == null:
		return

	# Reserve the binding before compiling the body so local recursion can capture it.
	var local_index: Variant
	if _scope_depth > 0:
		local_index = _declare_local(function_name, true)
		if local_index == null:
			return
		# The closure replaces this temporary null value after compilation.
		_emit_instruction(OpCode.NONE)
		_emit_instruction(OpCode.DEFINE_LOCAL)

	var child_compiler := Compiler.new(_source, _tokens, self, _token_index)

	var compiled: Variant = child_compiler.compile()
	# Resume after the nested function's body.
	_token_index = child_compiler._token_index

	if compiled is CompileError:
		if _compile_error == null:
			_compile_error = compiled
		return

	var function: CompiledFunction = compiled
	function.name = function_name

	var function_index: Variant = _add_constant(function)
	if function_index == null:
		return
	_emit_instruction(OpCode.CLOSURE, function_index)

	for upvalue in child_compiler._upvalues:
		_emit_capture(upvalue.is_local, upvalue.index_in_enclosing)

	if _scope_depth == 0:
		_emit_instruction(OpCode.DEFINE_GLOBAL, name_constant_index)
	else:
		_emit_instruction(OpCode.SET_LOCAL, local_index)
		_emit_instruction(OpCode.POP)


## Parses parameter names and registers them as initialized locals in the function's scope.
func _parse_parameters() -> void:
	if not _consume(Token.Type.LEFT_PARENTHESES, "Expect '(' before parameters."):
		return
	if _match(Token.Type.RIGHT_PARENTHESES):
		return

	while _compile_error == null:
		if not _consume(Token.Type.IDENTIFIER, "Expect parameter name."):
			return

		var local_index: Variant = _declare_local(_previous_lexeme())
		if local_index == null:
			return

		if _match(Token.Type.EQUAL):
			# For optional args, emit the bytecode to check if arg count > index. If so, skip past default value definition.
			_emit_instruction(OpCode.ARGUMENT_COUNT)
			_emit_constant(local_index)
			_emit_instruction(OpCode.GREATER)
			var skip_default: Variant = _emit_jump(OpCode.JUMP_IF_TRUE)
			if skip_default == null:
				return
			_parse_expression()
			_emit_instruction(OpCode.DEFINE_LOCAL)
			_patch_jump(skip_default)

			_emit_instruction(OpCode.POP)
		elif _function.min_arity != _function.max_arity:
			_error("Required parameters cannot follow optional parameters.", _previous())
			return
		else:
			_function.min_arity += 1

		_function.max_arity += 1
		_locals[local_index].is_initialized = true

		if not _match(Token.Type.COMMA):
			break

	_consume(Token.Type.RIGHT_PARENTHESES, "Expect ')' after parameters.")


## Parses a block in a new scope and emits cleanup for its locals.
func _parse_scoped_block() -> void:
	_scope_depth += 1
	_parse_block()
	_end_scope()


## The caller owns scope lifetime so function parameters share their body's scope.
func _parse_block() -> void:
	_consume(Token.Type.COLON, "Expect ':' before block.")
	_consume(Token.Type.NEWLINE, "Expect newline before block.")
	_consume(Token.Type.INDENT, "Expect indent before block.")

	while _compile_error == null and _current().type != Token.Type.DEDENT and _current().type != Token.Type.EOF:
		_parse_declaration()

	_consume(Token.Type.DEDENT, "Expect dedent after block.")


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
		_parse_loop_jump()
	else:
		_parse_expression_statement()


func _parse_expression_statement() -> void:
	_parse_expression()
	_consume(Token.Type.NEWLINE, "Expect newline after expression.")
	_emit_instruction(OpCode.POP)


func _parse_return_statement() -> void:
	if _match(Token.Type.NEWLINE):
		_emit_instruction(OpCode.NONE)
	else:
		_parse_expression()
		_consume(Token.Type.NEWLINE, "Expect newline after return value.")

	_emit_instruction(OpCode.RETURN)


func _parse_loop_jump() -> void:
	var keyword := _previous()
	var is_break := keyword.type == Token.Type.BREAK
	var name := "break" if is_break else "continue"
	if _loops.is_empty():
		_error("Cannot use '%s' outside a loop." % name, keyword)
		return
	if not _consume(Token.Type.NEWLINE, "Expect newline after '%s'." % name):
		return

	var loop := _loops[-1]
	# Cleanup runtime local variables via POP_LOCAL. But do not cleanup _locals array tracked by compiler, to not interfere.
	_emit_scope_cleanup(loop.scope_depth)
	var jump: Variant = _emit_jump(OpCode.JUMP)
	if jump != null:
		if is_break:
			loop.break_jumps.append(jump)
		else:
			loop.continue_jumps.append(jump)


func _parse_if_statement() -> void:
	var end_jumps: Array[int] = []
	while _compile_error == null:
		_parse_expression()

		var false_jump: Variant = _emit_jump(OpCode.JUMP_IF_FALSE)
		if false_jump == null:
			return
		_emit_instruction(OpCode.POP)

		_parse_scoped_block()

		var end_jump: Variant = _emit_jump(OpCode.JUMP)
		if end_jump == null:
			return
		end_jumps.append(end_jump)
		_patch_jump(false_jump)
		_emit_instruction(OpCode.POP)

		if not _match(Token.Type.ELIF):
			break

	if _match(Token.Type.ELSE):
		_parse_scoped_block()
	for end_jump in end_jumps:
		_patch_jump(end_jump)


func _parse_while_statement() -> void:
	var loop_start := len(_function.chunk.code)
	_parse_expression()

	var exit_jump: Variant = _emit_jump(OpCode.JUMP_IF_FALSE)
	if exit_jump == null:
		return
	_emit_instruction(OpCode.POP)

	var loop := Loop.new(_scope_depth)
	_loops.append(loop)
	_parse_scoped_block()
	_loops.pop_back()

	for jump in loop.continue_jumps:
		_patch_jump(jump)
	_emit_jump(OpCode.JUMP, loop_start)

	_patch_jump(exit_jump)
	_emit_instruction(OpCode.POP)
	for jump in loop.break_jumps:
		_patch_jump(jump)


func _parse_for_statement() -> void:
	var is_counter_declaration := _match(Token.Type.VAR)
	if not _consume(Token.Type.IDENTIFIER, "Expected loop variable."):
		return
	var name := _previous_lexeme()
	var counter: Binding
	if not is_counter_declaration:
		counter = _resolve_binding(name)
		if counter == null:
			return

	_scope_depth += 1
	# Only declared counters belong to this scope; both forms cache the bound and step.
	if is_counter_declaration:
		var local_index: Variant = _declare_local(name)
		if local_index == null:
			_end_scope()
			return
		counter = Binding.new(local_index, OpCode.GET_LOCAL, OpCode.SET_LOCAL)

	_consume(Token.Type.EQUAL, "Expected '=' after loop variable.")
	_parse_expression()
	if _compile_error != null:
		_end_scope()
		return
	if is_counter_declaration:
		_emit_instruction(OpCode.DEFINE_LOCAL)
		_locals[counter.index].is_initialized = true
	else:
		_emit_instruction(counter.set_opcode, counter.index)
		_emit_instruction(OpCode.POP)

	_consume(Token.Type.TO, "Expected 'to' after loop initializer.")

	# Evaluate and cache the upper bound once.
	_parse_expression()
	# Anonymous locals cannot be referenced by source names.
	var end_local_index: Variant = _declare_local("", true)
	if end_local_index == null:
		_end_scope()
		return
	_emit_instruction(OpCode.DEFINE_LOCAL)

	if _match(Token.Type.STEP):
		_parse_expression()
	else:
		# Default step to 1.
		_emit_constant(1)

	var step_local_index: Variant = _declare_local("", true)
	if step_local_index == null:
		_end_scope()
		return
	_emit_instruction(OpCode.DEFINE_LOCAL)

	var loop_start := len(_function.chunk.code)

	# Check (i - end) * step < 0 at runtime to handle both positive and negative steps.
	_emit_instruction(counter.get_opcode, counter.index)
	_emit_instruction(OpCode.GET_LOCAL, end_local_index)
	_emit_instruction(OpCode.SUBTRACT)
	_emit_instruction(OpCode.GET_LOCAL, step_local_index)
	_emit_instruction(OpCode.MULTIPLY)
	_emit_constant(0)
	_emit_instruction(OpCode.LESS)

	var exit_jump: Variant = _emit_jump(OpCode.JUMP_IF_FALSE)
	if exit_jump == null:
		_end_scope()
		return
	_emit_instruction(OpCode.POP)

	var loop := Loop.new(_scope_depth)
	_loops.append(loop)
	_parse_scoped_block()
	_loops.pop_back()

	# Continue still increments the counter.
	for jump in loop.continue_jumps:
		_patch_jump(jump)
	# Increment counter by step.
	_emit_instruction(counter.get_opcode, counter.index)
	_emit_instruction(OpCode.GET_LOCAL, step_local_index)
	_emit_instruction(OpCode.ADD)
	_emit_instruction(counter.set_opcode, counter.index)
	_emit_instruction(OpCode.POP)

	_emit_jump(OpCode.JUMP, loop_start)

	_patch_jump(exit_jump)
	_emit_instruction(OpCode.POP)

	# Both break and normal exit release the counter and cached range locals.
	for jump in loop.break_jumps:
		_patch_jump(jump)
	_end_scope()


## Parses an expression starting at _current(), using min_bp as its binding power threshold.
func _parse_expression(min_bp: int = 0) -> void:
	_advance()

	var can_assign := min_bp <= ASSIGNMENT_BP

	var rule: ParseRule = RULES.get(_previous().type)
	if rule == null or not rule.prefix.is_valid():
		_error("Expected expression.", _previous())
		return
	rule.prefix.call(rule.prefix_bp, can_assign)

	while _compile_error == null:
		rule = RULES.get(_current().type)
		if rule == null or not rule.infix.is_valid():
			break
		if rule.left_bp < min_bp:
			break

		_advance()
		rule.infix.call(rule.right_bp, can_assign)

	if _compile_error == null and can_assign and _match(Token.Type.EQUAL):
		_error("Invalid assignment target.", _previous())


func _parse_number(_min_bp: int, _can_assign: bool) -> void:
	var lexeme := _previous_lexeme()
	if lexeme.contains("."):
		var value := lexeme.to_float()
		if not is_finite(value):
			_error("Float literal is out of range.", _previous())
			return
		_emit_constant(value)
	else:
		# Check decimal digits before conversion: Godot can wrap or clamp overflowing integers.
		var digits := lexeme.lstrip("0")
		if len(digits) > 19 or (len(digits) == 19 and digits > "9223372036854775807"):
			_error("Integer literal is out of range.", _previous())
			return
		_emit_constant(lexeme.to_int())


func _parse_string(_min_bp: int, _can_assign: bool) -> void:
	var lexeme := _previous_lexeme()
	_emit_constant(lexeme.substr(1, len(lexeme) - 2))


func _parse_literal(_min_bp: int, _can_assign: bool) -> void:
	match _previous().type:
		Token.Type.TRUE: _emit_instruction(OpCode.TRUE)
		Token.Type.FALSE: _emit_instruction(OpCode.FALSE)
		Token.Type.NONE: _emit_instruction(OpCode.NONE)


func _parse_variable(_min_bp: int, can_assign: bool) -> void:
	var binding := _resolve_binding(_previous_lexeme())
	if binding == null:
		return

	if binding.get_opcode == OpCode.GET_LOCAL and not _locals[binding.index].is_initialized:
		var action := "assign to" if can_assign and _current().type == Token.Type.EQUAL else "read"
		_error("Cannot %s local variable in its own initializer." % action, _previous())
		return

	if can_assign and _match(Token.Type.EQUAL):
		_parse_expression(ASSIGNMENT_BP)
		_emit_instruction(binding.set_opcode, binding.index)
	else:
		_emit_instruction(binding.get_opcode, binding.index)


## Parses a parenthesized expression with a fresh binding power threshold and consumes ')'.
func _parse_grouping(_min_bp: int, _can_assign: bool) -> void:
	_parse_expression()
	_consume(Token.Type.RIGHT_PARENTHESES, "Expect ')' after expression.")


## Parses a unary operator's operand at min_bp, then emits the operator's instruction.
func _parse_unary(min_bp: int, _can_assign: bool) -> void:
	var operator := _previous()
	_parse_expression(min_bp)
	match operator.type:
		Token.Type.MINUS: _emit_instruction(OpCode.NEGATE)
		Token.Type.NOT: _emit_instruction(OpCode.NOT)


## Parses a binary operator's right operand at min_bp, then emits the operator's instruction.
func _parse_binary(min_bp: int, _can_assign: bool) -> void:
	var operator := _previous()
	_parse_expression(min_bp)
	match operator.type:
		Token.Type.PLUS: _emit_instruction(OpCode.ADD)
		Token.Type.MINUS: _emit_instruction(OpCode.SUBTRACT)
		Token.Type.ASTERISK: _emit_instruction(OpCode.MULTIPLY)
		Token.Type.SLASH: _emit_instruction(OpCode.DIVIDE)
		Token.Type.PERCENT: _emit_instruction(OpCode.MODULO)
		Token.Type.EQUAL_EQUAL: _emit_instruction(OpCode.EQUAL)
		Token.Type.BANG_EQUAL:
			_emit_instruction(OpCode.EQUAL)
			_emit_instruction(OpCode.NOT)
		Token.Type.GREATER: _emit_instruction(OpCode.GREATER)
		Token.Type.GREATER_EQUAL:
			_emit_instruction(OpCode.LESS)
			_emit_instruction(OpCode.NOT)
		Token.Type.LESS: _emit_instruction(OpCode.LESS)
		Token.Type.LESS_EQUAL:
			_emit_instruction(OpCode.GREATER)
			_emit_instruction(OpCode.NOT)
		_: _error("Binary operator is not implemented yet.", operator)


func _parse_and(min_bp: int, _can_assign: bool) -> void:
	var end_jump: Variant = _emit_jump(OpCode.JUMP_IF_FALSE)
	if end_jump == null:
		return
	_emit_instruction(OpCode.POP)
	_parse_expression(min_bp)
	_patch_jump(end_jump)


func _parse_or(min_bp: int, _can_assign: bool) -> void:
	var end_jump: Variant = _emit_jump(OpCode.JUMP_IF_TRUE)
	if end_jump == null:
		return
	_emit_instruction(OpCode.POP)
	_parse_expression(min_bp)
	_patch_jump(end_jump)


func _parse_call(_min_bp: int, _can_assign: bool) -> void:
	var arg_count := 0
	if _current().type != Token.Type.RIGHT_PARENTHESES:
		while _compile_error == null:
			_parse_expression()
			if arg_count == MAX_ARGUMENTS:
				_error("Can't have more than 255 arguments.", _previous())
				return
			arg_count += 1

			if not _match(Token.Type.COMMA):
				break

	_consume(Token.Type.RIGHT_PARENTHESES, "Expect ')' after arguments.")
	_emit_instruction(OpCode.CALL, arg_count)


func _parse_subscript(_min_bp: int, can_assign: bool) -> void:
	_parse_expression()
	_consume(Token.Type.RIGHT_BRACKET, "Expected ']'.")

	if can_assign and _match(Token.Type.EQUAL):
		_parse_expression(ASSIGNMENT_BP)
		_emit_instruction(OpCode.SET_SUBSCRIPT)
	else:
		_emit_instruction(OpCode.GET_SUBSCRIPT)


func _parse_property(_min_bp: int, _can_assign: bool) -> void:
	_error("Property access is not implemented yet.", _previous())


func _parse_list(_min_bp: int, _can_assign: bool) -> void:
	var count := 0
	if _current().type != Token.Type.RIGHT_BRACKET:
		while _compile_error == null:
			# This only restricts list literals, not runtime list sizes.
			if count == MAX_LIST_ELEMENTS:
				_error("Can't have more than 255 list elements.")
				return
			_parse_expression()
			count += 1

			if not _match(Token.Type.COMMA):
				break

	_consume(Token.Type.RIGHT_BRACKET, "Expected ']' after list.")
	_emit_instruction(OpCode.BUILD_LIST, count)


func _parse_dictionary(_min_bp: int, _can_assign: bool) -> void:
	var count := 0
	if _current().type != Token.Type.RIGHT_BRACE:
		while _compile_error == null:
			if count == MAX_DICTIONARY_ENTRIES:
				_error("Can't have more than 255 dictionary entries.")
				return

			_parse_expression()
			if not _consume(Token.Type.COLON, "Expect ':' after dictionary key."):
				return

			_parse_expression()
			count += 1

			# Allows trailing commas.
			if not _match(Token.Type.COMMA) or _current().type == Token.Type.RIGHT_BRACE:
				break

	_consume(Token.Type.RIGHT_BRACE, "Expect '}' after dictionary.")
	_emit_instruction(OpCode.BUILD_DICT, count)


#endregion


#region Scopes and captures


## Registers a script-level declaration, sharing one namespace for variables and functions.
func _declare_global(name: String) -> Variant:
	if _globals.has(name):
		_error("Already a variable with this name in this scope.", _previous())
		return null
	_globals[name] = true
	return _add_constant(name)


## Registers local metadata without consuming tokens or emitting bytecode; returns its index or null on failure.
## Empty names identify temporaries; initialized locals can be read immediately.
func _declare_local(name: String, is_initialized: bool = false) -> Variant:
	if len(_locals) >= MAX_LOCALS:
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


## Resolves access to an existing binding; globals remain late-bound in the VM.
## Returns null after a capture or constant-pool failure, without emitting instructions.
func _resolve_binding(name: String) -> Binding:
	var index: Variant = _resolve_local(name)
	if index != null:
		return Binding.new(index, OpCode.GET_LOCAL, OpCode.SET_LOCAL)

	index = _resolve_upvalue(name)
	if _compile_error != null:
		return null
	if index != null:
		return Binding.new(index, OpCode.GET_UPVALUE, OpCode.SET_UPVALUE)

	index = _add_constant(name)
	if index == null:
		return null
	return Binding.new(index, OpCode.GET_GLOBAL, OpCode.SET_GLOBAL)


## Returns the nearest index in _locals, or null if absent; indices address frame cells directly.
func _resolve_local(name: String) -> Variant:
	# Anonymous temporaries are accessed only by their allocated indexes.
	if name == "" or _scope_depth == 0:
		return null

	for local_index in range(len(_locals) - 1, -1, -1):
		if _locals[local_index].name == name:
			return local_index
	return null


## Carries the original reference token through forwarding captures for accurate errors.
func _resolve_upvalue(name: String, ref: Token = null) -> Variant:
	if _enclosing == null:
		return null
	if ref == null:
		ref = _previous()

	var enclosing_local: Variant = _enclosing._resolve_local(name)
	if enclosing_local != null:
		return _add_upvalue(enclosing_local, true, ref)

	var enclosing_upvalue: Variant = _enclosing._resolve_upvalue(name, ref)
	if _enclosing._compile_error != null:
		if _compile_error == null:
			_compile_error = _enclosing._compile_error
		return null
	if enclosing_upvalue != null:
		return _add_upvalue(enclosing_upvalue, false, ref)

	return null


## Returns a capture index, or null on overflow; existing captures remain reusable at capacity.
func _add_upvalue(index: int, is_local: bool, ref: Token = null) -> Variant:
	for i in range(len(_upvalues)):
		var upvalue := _upvalues[i]
		if upvalue.index_in_enclosing == index and upvalue.is_local == is_local:
			return i
	if len(_upvalues) >= MAX_UPVALUES:
		_error("Too many closure variables in function.", ref)
		return null
	_upvalues.append(Upvalue.new(index, is_local))
	_function.upvalue_count = len(_upvalues)
	return _function.upvalue_count - 1


## Emits runtime cleanup without changing the compiler's lexical scope.
func _emit_scope_cleanup(target_depth: int) -> void:
	for i in range(_locals.size() - 1, -1, -1):
		if _locals[i].depth <= target_depth:
			break
		_emit_instruction(OpCode.POP_LOCAL)


func _end_scope() -> void:
	_scope_depth -= 1
	# Runtime cleanup via POP_LOCAL.
	_emit_scope_cleanup(_scope_depth)
	# Compiler _locals tracking cleanup.
	while not _locals.is_empty() and _locals[-1].depth > _scope_depth:
		_locals.pop_back()


#endregion


#region Bytecode emission


## Emits an opcode and its optional one-byte operand, including operand zero.
func _emit_instruction(opcode: int, operand: Variant = null) -> void:
	_emit_byte(opcode)
	if operand != null:
		_emit_byte(operand)


## Adds a constant and emits the instruction that pushes its value onto the stack.
func _emit_constant(value: Variant) -> void:
	var constant_index: Variant = _add_constant(value)
	if constant_index == null:
		return
	_emit_instruction(OpCode.CONSTANT, constant_index)


## Encodes a closure capture descriptor.
func _emit_capture(is_local: bool, index: int) -> void:
	_emit_byte(1 if is_local else 0)
	_emit_byte(index)


## Returns the jump operand's position, or null on overflow without writing any bytes.
## An omitted target emits a zero placeholder for _patch_jump(); target zero is valid.
func _emit_jump(instruction: int, target: Variant = null) -> Variant:
	var operand_position := len(_function.chunk.code) + 1
	var offset := 0
	if target != null:
		offset = int(target) - operand_position - 2

	if offset < MIN_JUMP_OFFSET or offset > MAX_JUMP_OFFSET:
		_error("Jump offset must be between -32768 and 32767.", _previous())
		return null

	_emit_byte(instruction)
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


## Returns a one-byte constant index, or null on overflow without changing the pool.
func _add_constant(value: Variant) -> Variant:
	# Don't dedupe functions as we need to figure out semantics of whether a function equals another.
	if typeof(value) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
		# The pool is small; profile before adding a reverse-lookup dictionary if it grows.
		for i in range(len(_function.chunk.constants)):
			var existing: Variant = _function.chunk.constants[i]
			if typeof(existing) == typeof(value) and existing == value:
				return i

	if len(_function.chunk.constants) >= MAX_CONSTANTS:
		_error("Too many constants in one function.", _previous())
		return null
	return _function.chunk.add_constant(value)


## Emits a byte, using the current token's line if nothing has been consumed yet.
func _emit_byte(byte: int) -> void:
	var token := _previous()
	if token == null:
		token = _current()
	_function.chunk.append(byte, token.line)


#endregion


#region Parser helpers


## Returns the current unconsumed token, or EOF after the token list is exhausted.
func _current() -> Token:
	return _peek(0)


## Returns the token offset positions after _current() without advancing, or EOF past the end.
func _peek(offset: int = 1) -> Token:
	assert(offset >= 0, "Lookahead offset must be nonnegative.")
	return _tokens[mini(_token_index + offset, len(_tokens) - 1)]


## Returns the last consumed token, or null if no token has been consumed.
func _previous() -> Token:
	if _token_index == 0:
		return null
	return _tokens[_token_index - 1]


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


## Retains the first diagnostic; active handlers may finish, but their output is discarded.
func _error(message: String, token: Token = null) -> void:
	if _compile_error != null:
		return

	if token == null:
		token = _current()
	_compile_error = CompileError.new(message, token.line, token.start, token.length)


#endregion
