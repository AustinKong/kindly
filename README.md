# Kindly

A programming language that asks nicely.

## About

Kindly is a small programming language and bytecode interpreter built in GDScript. The goal is to write programs that read like excessively polite corporate emails.

The planned v0.1 syntax looks like this:

```text
Dear Compiler,

Please let message be "I hope this program finds you well".
Kindly print message, thank you.

Best regards.
```

**Work in progress:** the interpreter currently supports Python-like syntax. The polite syntax above is not implemented yet; its grammar is described in the [v0.1 language specification](docs/language-specification.md).

### Features

- Variables, arithmetic, comparisons, and short-circuit logical operators.
- Functions, recursion, lexical scoping, and closures with mutable captured variables.
- Conditionals, while loops, and numeric range loops with configurable steps.
- Indentation-based blocks, comments, and multiline expressions inside parentheses.
- Printed output that can be captured by the host application.

### Implementation

Built using Robert Nystrom's [Crafting Interpreters](https://craftinginterpreters.com/) as a reference, particularly its clox bytecode interpreter. Kindly retains direct compilation and lexical variable resolution, with several adaptations:

- **Shared local cells:** each call frame stores locals in reference-counted cells that closures can retain and update after the function returns. This replaces clox's stack slots and open/closed upvalue storage.
- **Indentation-sensitive lexer:** tracks logical lines, indentation levels, and bracket pairs to support Python-like blocks.
- **Pratt parser with explicit binding powers:** prefix, left, and right binding powers define operator precedence and associativity.
- **Numeric range loops and signed jumps:** range bounds and steps are evaluated once, while signed relative offsets handle both forward branches and backward loops.
- **Godot integration:** uses native GDScript values, output callbacks, source spans for scan/compile errors, and an instruction budget per invocation.

### Technology

- Godot 4.7 / GDScript, validated with Godot 4.7.2.
- A direct bytecode compiler and stack-based virtual machine.

## Getting Started

Clone the repository and import it with Godot:

```sh
git clone https://github.com/AustinKong/kindly.git
cd kindly
godot --headless --path . --import
godot --editor --path .
```

Use your Godot executable's full path if `godot` is not on `PATH`. This repository contains the interpreter source; there is no default main scene or standalone CLI.

From a GDScript in the project, run source through `Interpreter`:

```gdscript
func run_example() -> void:
	var source := "var answer = 6 * 7\nprint(answer)\n"
	var result: Variant = Interpreter.new().interpret(source)
	if result != null:
		push_error(result.message)
```

This example uses the currently supported syntax. Use tabs for source indentation and LF line endings. An optional second `Callable` argument captures printed output; each invocation starts with fresh globals. See [`engine/interpreter.gd`](engine/interpreter.gd) for the entry point.

## Authors

Austin Kong [@AustinKong](https://github.com/AustinKong)

## License

This project is licensed under the [MIT License](LICENSE).
