extends RefCounted

# Due to using byte for bytecode, our number of constants is capped at 256.
var code := PackedByteArray()
var constants: Array = []
var lines := PackedInt32Array()

## Appends a byte to the bytecode.
func append(byte: int, line: int) -> void:
	code.append(byte)
	lines.append(line)


# TODO: Dedupe immutable constants as variable declarations and assignments both add_constant.
## Adds a constant and returns its index.
func add_constant(value: Variant) -> int:
	constants.append(value)
	return len(constants) - 1
