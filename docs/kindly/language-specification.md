# Kindly language specification

**Version:** 0.1  
**Status:** draft; proposed syntax, not implemented  
**Implementation:** a GDScript compiler and bytecode VM hosted by Godot

Kindly is a Python-like language in which programs resemble excessively polite corporate correspondence. Statements are requests, blocks are indented, and each source file opens and closes like an email.

This document defines the proposed v0.1 language. The existing Simple frontend defines the currently executable syntax. Existing interpreter behavior is the baseline for runtime semantics; the greeting, polite phrases, case-insensitive keywords, and sentence terminators described here require future frontend work.

## 1. Scope and conformance

The terms **must**, **must not**, and **may** describe requirements for a future conforming v0.1 implementation. They do not describe features already present in the current compiler.

The v0.1 implementation must:

1. Parse deterministic syntax rather than arbitrary natural language.
2. Compile directly to the existing bytecode without a source-to-source translation layer.
3. Preserve runtime values, instruction formats, lexical scope resolution, calls, recursion, and mutable captured variables.
4. Implement the language changes primarily in the lexer and compiler, without adding runtime features solely to support the theme.
5. Report malformed programs with useful source locations.

This specification intentionally excludes iterable for-each loops, collections, indexing, property access, modules, classes, exceptions, asynchronous execution, and assignment expressions. A recognized token or placeholder parse rule in the current code is not evidence that a feature is implemented.

## 2. Reference program

```text
Dear Compiler,

Please define factorial(n):
	With respect to n <= 1:
		Kindly return 1.
	Otherwise:
		Kindly return n * factorial(n - 1).

Please let result be factorial(5).
Kindly print result.

Best regards.
```

This program must produce one output value representing the number `120`. The current host uses Godot's numeric-to-string conversion; floating-point formatting such as `120.0` does not change that numeric requirement. Unless specified otherwise, output formatting follows the existing host implementation.

All indented examples in this document use literal tab characters.

## 3. Source files and layout

### 3.1 Envelope

Every source file must have this structure:

```text
Dear Compiler,

<zero or more statements>

Best regards.
```

- `Dear Compiler,` must be the first nonblank line.
- `Best regards.` must be the last nonblank line.
- Both envelope lines must appear at indentation level zero, each on its own line.
- Leading and trailing blank lines are allowed. Comment-only lines may appear inside the envelope; they do not replace either envelope line. A comment-only line before the greeting or after the sign-off is not blank and is therefore invalid.
- No statement may appear before the greeting or after the sign-off. Envelope phrases cannot be nested inside a block.
- The comma in the greeting and period in the sign-off are mandatory. The courtesy suffix is not permitted on either envelope line.
- Greeting and sign-off are compile-time syntax and must emit no executable instructions of their own.

An empty envelope is a valid program. A final newline after the sign-off is optional.

### 3.2 Whitespace and comments

Source is UTF-8 text supplied to the interpreter as a string. The existing frontend expects LF line endings; hosts must normalize CRLF or CR input to LF before invoking it.

Leading indentation on a nonblank, non-comment line must consist of **tabs**, following the current lexer. Spaces are allowed between tokens, but space indentation and mixed space/tab indentation are errors. A tab is one indentation unit. A block must be deeper than its header; dedentation must return to an existing enclosing level. Blank and comment-only lines do not open or close blocks.

`#` begins a comment outside a string and continues to the end of the physical line. Comments may follow complete statements or block headers. Comment characters inside strings are literal content.

Newlines separate statements. A logical newline is suppressed inside parentheses, permitting multiline expressions and calls. Statement headers and the envelope cannot be split across physical lines. Backslash continuation and semicolon-separated statements are not supported. Blank logical lines are ignored.

### 3.3 Case and phrase recognition

Keywords and fixed phrases are ASCII case-insensitive: `Please let`, `PLEASE LET`, and `please let` have the same meaning. Identifiers remain case-sensitive, and string contents are never case-folded. This applies to the envelope and literal keywords as well.

Words within a fixed phrase must be separated by one or more spaces or tabs, on the same physical line. Punctuation remains required. Keyword recognition must respect identifier boundaries: `pleaselet` is not `Please let`, and `true_value` is not the literal `true`.

Phrase words such as `let`, `be`, `update`, `to`, `define`, and `print` must be recognized in their grammatical context rather than globally reserved. For example, the following declaration is valid:

```text
Please let update be 10.
```

The statement-leading words `please`, `kindly`, `with`, `otherwise`, and `as`, together with the expression words `and`, `or`, `not`, `true`, `false`, and `none`, are reserved case-insensitively. `dear` and `best` are recognized as envelope words only where the envelope is expected. These rules avoid accidentally turning a variable named `to` or `be` into an unconditional keyword token.

## 4. Statements

The following examples are statement fragments; a complete file must include the envelope.

| Operation | Syntax | Existing semantic counterpart |
| --- | --- | --- |
| Declare a variable | `Please let x be 10.` | `var x = 10` |
| Assign an existing variable | `Please update x to 20.` | `x = 20` |
| Declare a function | `Please define greet(name):` | `def greet(name):` |
| Conditional | `With respect to x > 5:` | `if x > 5:` |
| Alternative branch | `Otherwise:` | `else:` |
| While loop | `As long as x < 10:` | `while x < 10:` |
| Return | `Kindly return x.` | `return x` |
| Print | `Kindly print x.` | `print(x)` |
| Evaluate and discard | `Kindly execute greet("Alice").` | `greet("Alice")` |

Every statement must use one of these forms. The former bare `var`, `def`, `if`, `else`, `while`, `for`, and `return` statement forms are not part of v0.1. Bare assignments and bare expression statements are also invalid. This does not prevent calling a named function inside an expression.

### 4.1 Variables and assignment

```text
Please let name be "Alice".
Please let age be 25.
Please let active be true.
Please update age to age + 1.
```

A declaration requires an initializer. Assignment targets one identifier and must update an existing binding according to the current local, enclosing, and global resolution rules. It must not implicitly declare a missing variable.

Declarations at the script's outermost level create globals. Function bodies and conditional/loop blocks use the existing lexical scopes; a declaration inside a block does not become a new global merely because its enclosing function is the script. Duplicate declarations in one local scope and reading a local inside its own initializer must retain the current compiler's errors. Assignment to a captured local updates its shared cell.

Chained assignment, assignment expressions, destructuring, and compound assignment are outside v0.1.

### 4.2 Functions and return

```text
Please define greet(name):
	Kindly print "Hello, " + name.

Please define double(x):
	Kindly return x * 2.
```

A function takes zero or more comma-separated identifier parameters. Parameters are required positional parameters; there are no defaults, annotations, variadic parameters, or trailing commas. Calls must supply the declared number of arguments. Functions are values, support recursion and nesting, and capture enclosing locals using the existing closure machinery.

`Kindly return` is valid only inside a function. Its expression is optional:

```text
Kindly return.
```

A bare return and falling off the end of a function both return the existing null value. Rejecting a top-level return is a frontend validation requirement; it requires no VM change.

### 4.3 Conditionals

```text
With respect to age >= 18:
	Kindly print "Approved".
Otherwise:
	Kindly print "Rejected".
```

`With respect to` introduces a conditional statement, not an expression. `Otherwise:` is optional and must align with its matching conditional. An unmatched `Otherwise` is an error. There is no `elif` form; nest another conditional in an alternative block.

Conditions use the VM's existing truth conversion, which delegates to Godot's `bool(value)`. This specification does not replace that behavior with Python's truth rules.

### 4.4 While loops

```text
Please let x be 0.
As long as x < 3:
	Kindly print x.
	Please update x to x + 1.
```

The condition is evaluated before every iteration. The existing conditional jumps and lexical block cleanup must be reused. `break`, `continue`, and loop `Otherwise` clauses are not included in v0.1.

**For-each is deferred.** The current compiler implements a numeric range loop (`for var i = start to end step increment:`), but it has no general iterable protocol, collection literals, or iterator instructions. Consequently, `For each x in items:` is not in the v0.1 grammar. The numeric range syntax is also not carried into the polite grammar; `As long as` covers the initial iteration requirement without inventing a new phrase or runtime feature.

### 4.5 Printing and expression statements

```text
Kindly print "Hello world".
Kindly execute greet("Alice").
```

`Kindly print` takes exactly one expression and must compile to a call to the existing one-argument `print` native. It adds no print opcode or formatting engine. Its result is discarded.

`Kindly execute` accepts any supported expression, not only a call. It evaluates the expression and discards its result using the existing expression-statement behavior.

## 5. Sentence terminators

A simple statement must end with either a period or the courtesy suffix:

```text
Please let x be 10.
Please let y be 20, thank you.
Kindly print x + y, thank you.
```

The courtesy suffix consists of a comma, `thank you`, and the final period. It is optional only as a whole, belongs to the preceding statement, and is not itself a statement. Whitespace may appear between the suffix's tokens, but the suffix must be on the expression's final physical line.

A complete terminator must be followed by a logical newline, a trailing comment and newline, or the end of input where applicable. Another statement cannot follow it on the same line. A newline alone does not terminate a simple statement. Block headers end with `:` and do not accept a period or courtesy suffix.

A period inside a string is string content. A period belongs to a decimal literal only when it appears between digits. Therefore `10.` is the number `10` followed by a terminator, and `10.5.` is the number `10.5` followed by a terminator. Property access is outside this grammar, so it does not compete with the sentence period.

## 6. Expressions and values

### 6.1 Literals and identifiers

| Kind | v0.1 syntax and behavior |
| --- | --- |
| Boolean | `true`, `false`; case-insensitive |
| Null | `None`; case-insensitive, preserving the existing literal name |
| Number | One or more ASCII digits, optionally followed by `.` and one or more digits; compiled as a floating-point value |
| String | Double-quoted, single-line text; no escape processing |
| Identifier | `[A-Za-z_][A-Za-z0-9_]*`, excluding reserved words; case-sensitive |

This draft chooses the supplied proposal's "existing equivalent" option for null: **`None`**. `nil` is not an additional literal. The literal value remains Godot's `null` internally.

Signs are operators rather than part of number tokens. Exponents, hexadecimal numbers, `.5`, single-quoted strings, escape sequences, and multiline strings are not included.

### 6.2 Operators and precedence

The following table preserves the current Pratt parser's precedence, from tightest to loosest. Binary operators associate left to right; prefix operators group with their operand. Comparison chaining is not a separate construct.

| Precedence | Syntax | Meaning |
| --- | --- | --- |
| Highest | `callee(arguments)` | Function call |
| | `+x`, `-x` | Unary identity, numeric negation |
| | `*`, `/` | Numeric multiplication and division |
| | `+`, `-` | Numeric addition/subtraction; `+` also concatenates two strings |
| | `==`, `!=`, `<`, `<=`, `>`, `>=` | Equality and numeric ordering, at the same precedence |
| | `not` | Logical negation |
| | `and` | Short-circuit conjunction |
| Lowest | `or` | Short-circuit disjunction |

Parentheses explicitly group an expression. Call arguments are comma-separated expressions, with no trailing comma. Evaluation follows the existing compiler's left-to-right emission order. `and` and `or` return the selected operand, not necessarily a boolean. Unary `+` preserves the operand as the current compiler does. `/` performs floating-point division. Numeric ordering, subtraction, multiplication, division, and unary negation use the existing numeric operand checks; addition accepts two numbers or two strings.

For a precise definition, expressions use the existing Pratt binding powers:

| Parse rule | Prefix operand binding power | Left binding power | Right binding power |
| --- | --- | --- | --- |
| Call `(...)` | — | 170 | — |
| Prefix `+`, `-` | 140 | — | — |
| `*`, `/` | — | 130 | 131 |
| Infix `+`, `-` | — | 120 | 121 |
| Equality and ordering | — | 70 | 71 |
| Prefix `not` | 60 | — | — |
| `and` | — | 50 | 51 |
| `or` | — | 40 | 41 |

`parse_expression(minimum = 0)` first consumes a primary or a prefix operator. A primary is a literal, identifier, or parenthesized expression. A prefix operator parses its operand using its prefix binding power. The parser then consumes infix operators while their left binding power is at least `minimum`, parsing each right operand with the corresponding right binding power. A call suffix instead parses zero or more full expressions as its comma-separated arguments. Grouping and call arguments start with binding power zero.

This definition preserves the current parser even when a low-binding prefix occurs where an operand is expected, such as `1 + not false`. That expression is syntactically accepted; the VM's existing operand checks determine whether evaluation succeeds. Comparison chains remain ordinary left-associated operations rather than Python's special chained-comparison construct.

Examples:

```text
Please let total be (10 + 20) * 3.
Please let valid be total >= 50 and total < 100.
Please let result be factorial(5).
```

`%`, list/dictionary literals, subscripting, and property access remain unsupported. In particular, token definitions for brackets and `%` do not make those expressions part of v0.1.

## 7. Grammar

The EBNF below describes the token stream after indentation processing and removal of comments and blank lines. Quoted words and phrases match case-insensitively using the lexical rules above. `NEWLINE` denotes a logical newline; `INDENT` and `DEDENT` are synthetic indentation tokens. The sign-off may have an optional final logical newline. The `expression` nonterminal is defined by the Pratt rules in section 6.2.

```ebnf
program          = greeting, NEWLINE, { statement }, signoff, [ NEWLINE ], EOF ;
greeting         = "Dear Compiler", "," ;
signoff          = "Best regards", "." ;

statement        = declaration | assignment | function_decl | if_stmt
                 | while_stmt | return_stmt | print_stmt | expression_stmt ;

declaration      = "Please let", IDENTIFIER, "be", expression, terminator, NEWLINE ;
assignment       = "Please update", IDENTIFIER, "to", expression, terminator, NEWLINE ;
function_decl    = "Please define", IDENTIFIER, "(", [ parameters ], ")", ":", block ;
if_stmt          = "With respect to", expression, ":", block,
                   [ "Otherwise", ":", block ] ;
while_stmt       = "As long as", expression, ":", block ;
return_stmt      = "Kindly return", [ expression ], terminator, NEWLINE ;
print_stmt       = "Kindly print", expression, terminator, NEWLINE ;
expression_stmt  = "Kindly execute", expression, terminator, NEWLINE ;
terminator       = "." | ",", "thank you", "." ;
block            = NEWLINE, INDENT, statement, { statement }, DEDENT ;
parameters       = IDENTIFIER, { ",", IDENTIFIER } ;
arguments        = expression, { ",", expression } ;
primary          = NUMBER | STRING | IDENTIFIER | "true" | "false" | "None"
                 | "(", expression, ")" ;
```

Blocks must contain at least one statement; there is no `pass` form. A complete courtesy suffix must be consumed before a statement's `NEWLINE`. Commas inside call parentheses belong to the argument list; the courtesy comma is recognized only after a complete top-level statement expression.

## 8. Runtime and implementation requirements

The existing frontend, bytecode, and VM remain the implementation baseline:

- Greeting, sign-off, courteous prefixes, and terminators must not introduce runtime operations.
- Variable and function declarations must use the existing global, local, and captured-variable instructions.
- Returned closures must retain shared cells, including mutation and capture through multiple enclosing functions.
- Print statements must call the existing native function and preserve the output callback contract.
- Conditionals, while loops, short-circuit expressions, and early returns must preserve stack balance and scope cleanup.
- Runtime errors must retain the existing structured error result. User-facing diagnostics should display source lines as one-based, although current error objects store zero-based lines.
- Current VM limits remain implementation limits: 256 active call frames and 1,000,000 instructions per invocation. Numeric formatting, truth conversion, and host value behavior remain unchanged.

An implementation may recognize multiword phrases as token sequences or composite tokens. Token names are not part of the language contract. Contextual phrase recognition must not prevent ordinary identifiers such as `to`, `be`, or `update` from being used outside their phrase positions. Lowercasing entire source files would violate identifier and string semantics.

Malformed input must return a scan or compile error rather than execute partially compiled code. Diagnostics must identify missing or incomplete envelope lines, missing terminators, malformed phrases, invalid indentation, misplaced alternative branches, top-level returns, and constructs outside this grammar. Existing errors for invalid bindings and unsupported expressions must remain useful.

The current frontend does not yet implement these new validations. This document requests them for v0.1; it does not change executable behavior.

## 9. Acceptance criteria

These are requirements for future conformance tests, not tests included in this source export.

| Case | Expected behavior |
| --- | --- |
| Canonical factorial program | Produces the numeric result `120` through the print callback |
| Empty envelope | Compiles and completes without output |
| Declaration followed by update | Reads the updated value |
| Shadowing within a nested block | Retains existing lexical scope behavior |
| Update of an undeclared variable | Reports an undefined-variable error |
| Nested conditionals and aligned alternatives | Selects the correct branch |
| `Otherwise` without a matching conditional | Compile error |
| While loop with an updated condition variable | Repeats and terminates as expected |
| Recursive and nested functions | Retain existing call and scope behavior |
| Closure returned from its enclosing function | Reads and updates its captured local after the outer call returns |
| Two closures from separate outer invocations | Maintain independent captured state |
| Bare return and implicit function return | Return the null value |
| Top-level return | Compile error |
| `.`, `, thank you.` | Both terminate simple statements |
| Missing terminator or incomplete courtesy suffix | Scan or compile error |
| Period in a string or between decimal digits | Does not terminate the statement |
| `Kindly print 10.5.` | Prints `10.5`; final period terminates the statement |
| Commas in a multi-argument call | Are parsed as argument separators |
| Keyword capitalization changes | Do not change syntax meaning |
| Identifier capitalization changes | Continue to name distinct bindings |
| Contextual words used as variable names | Accepted outside their phrase positions |
| Missing, repeated, or misplaced envelope lines | Scan or compile error |
| Tabs and valid dedentation | Accepted |
| Leading spaces on a code line | Indentation error |
| Empty block, iterable for-each, collections, or `%` | Rejected as outside v0.1 |
| Raw pre-v0.1 statements inside the envelope | Rejected |

## 10. Delivery sequence

Future implementation work should proceed in independently reviewable changes:

1. Add contextual phrase recognition, case-insensitive keywords, and sentence punctuation handling without changing identifier spelling.
2. Require the greeting and sign-off, preserving source locations and indentation handling.
3. Add polite declarations, assignments, functions, conditionals, returns, and while loops.
4. Add print and expression statements and consume both complete terminator forms.
5. Add positive and negative conformance tests, including the current function and closure behavior.
6. Provide runnable factorial and closure examples and update the README's implementation status.

The supplied concept's four-space presentation is resolved here in favor of the existing tab-only lexer. Its null-literal choice is resolved as `None`. Its conditional for-each proposal is deferred because the current numeric loop does not provide iterable semantics. These are explicit scope decisions for review, not interpreter changes made by this documentation.
