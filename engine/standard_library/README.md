# Standard library

Functions are called directly by name. Arguments are positional; optional arguments show their default values. Mutating functions return `None` unless another return value is specified.

| Function | Accepted containers | Behavior |
| --- | --- | --- |
| `append(collection, value)` | List, deque | Adds a value at the back. |
| `append_front(deque, value)` | Deque | Adds a value at the front. |
| `contains(collection, value)` | List, deque, dictionary | Returns whether a value exists in a list/deque, or a key exists in a dictionary. |
| `copy(collection)` | List, deque, dictionary | Returns an independent shallow copy of the same type. Nested values remain shared. |
| `deque()` / `deque(list)` | Optional list input | Creates an empty deque or one containing the list's values in order. Nested values remain shared. |
| `extend(destination, source)` | List, deque | Appends all source elements to the destination. Either argument may be a list or deque; self-extension is safe. |
| `get(dict, key, fallback = None)` | Dictionary | Returns the existing value, or fallback if missing. Does not insert. |
| `index(list, value)` | List | Returns the first matching index. Errors if absent. |
| `insert(list, index, value)` | List | Inserts before an integer index. Negative indices count from the end; out-of-range positions clamp to either end. |
| `keys(dict)` | Dictionary | Returns a snapshot list of keys in insertion order. |
| `len(collection)` | List, deque, dictionary | Returns the element or entry count. |
| `pop(collection)` | List, deque | Removes and returns the back value. Errors when empty. |
| `pop(dict, key, fallback = None)` | Dictionary | Removes and returns the key's value. If missing, returns fallback without changing the dictionary. |
| `pop_front(deque)` | Deque | Removes and returns the front value. Errors when empty. |
| `print(value)` | Any value | Prints one formatted value, including nested containers. Handles cycles safely; returns `None`. |
| `remove(collection, value)` | List, dictionary | Removes the first matching list value or the specified dictionary key. Errors if absent. |
| `reverse(list)` | List | Reverses the list in place. |
| `sort(list)` | List | Sorts ascending in place. Accepts numbers (integers/floats may mix) or strings; rejects other or incompatible types before mutation. |
| `values(dict)` | Dictionary | Returns a snapshot list of values in insertion order. Nested values remain shared. |

Dictionary keys must be strings, numbers, booleans, or `None`. An existing value of `None` counts as present. Fallback expressions evaluate before the call, even when unused. Invalid argument types or counts produce runtime errors.
