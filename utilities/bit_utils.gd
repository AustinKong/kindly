class_name BitUtils
extends RefCounted


## Interprets an unsigned 16-bit value (0..65535) as a signed integer.
static func to_signed_16(value: int) -> int:
	return value - 0x10000 if value & 0x8000 else value
