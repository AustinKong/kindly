class_name Trie
extends RefCounted

const SENTINEL: String = ""

var _root: Dictionary = {}


func _init(entries: Dictionary) -> void:
	for key in entries:
		insert(key, entries[key])


func insert(key: String, value: Variant) -> void:
	var curr := _root

	for chr in key:
		if not chr in curr:
			curr[chr] = {}

		curr = curr[chr]

	curr[SENTINEL] = value


func search(key: String) -> Variant:
	var curr := _root

	for chr in key:
		if not chr in curr:
			return null

		curr = curr[chr]

	return curr.get(SENTINEL)


## Whether key is the beginning of an entry, including a complete entry.
func has_prefix(key: String) -> bool:
	var curr := _root
	for chr in key:
		if not chr in curr:
			return false
		curr = curr[chr]
	return true
