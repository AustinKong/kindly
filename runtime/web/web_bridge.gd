extends Node

const LanguageInterpreter = preload("res://engine/interpreter.gd")
const CompileError = preload("res://engine/frontend/compiler/compile_error.gd")
const RuntimeError = preload("res://engine/virtual_machine/runtime_error.gd")

var _host: JavaScriptObject
# Keep this reference alive for as long as JavaScript can call run. As per:
# https://docs.godotengine.org/en/stable/tutorials/platform/web/javascript_bridge.html#callbacks
var _run_callback: JavaScriptObject
var _running := false


func _ready() -> void:
	if not OS.has_feature("web"):
		return

	_host = JavaScriptBridge.get_interface("window").parent
	_run_callback = JavaScriptBridge.create_callback(_on_run)
	_host.run = _run_callback

	_host.onReady()


func _on_run(arguments: Array) -> void:
	if arguments.size() != 2 or not arguments[0] is String or typeof(arguments[1]) not in [TYPE_INT, TYPE_FLOAT]:
		_host.onBridgeError("Invalid interpreter request.")
		return

	if _running:
		return

	_running = true
	# Return to JavaScript before interpreting on Godot's next frame.
	_run.call_deferred(arguments[0], int(arguments[1]))


func _run(source: String, run_id: int) -> void:
	var output: Array[String] = []
	var error: Variant = LanguageInterpreter.new().interpret(
		source,
		func(text: String) -> void: output.append(text)
	)

	var result := {"runId": run_id, "ok": error == null, "output": output, "error": null}
	if error != null:
		var phase := "runtime" if error is RuntimeError else ("compile" if error is CompileError else "scan")
		result.error = {"phase": phase, "message": error.message, "line": error.line, "stackTrace": []}

		if error is RuntimeError:
			result.error.stackTrace = error.stack_trace
		else:
			result.error.start = error.start
			result.error.length = error.length

	_running = false
	_host.onDone(JSON.stringify(result))
