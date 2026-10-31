class_name StringUtils
extends RefCounted

static func is_digit(chr: String) -> bool:
	return chr >= "0" and chr <= "9" and len(chr) == 1


static func is_alpha(chr: String) -> bool:
	return (chr >= "a" and chr <= "z") or (chr >= "A" and chr <= "Z") or chr == "_"
