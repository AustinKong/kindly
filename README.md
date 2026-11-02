# Kindly

A programming language and bytecode interpreter built in GDScript, with an Astro/React playground.
Simple and Kindly use separate lexers and compiler subclasses with a shared compilation core and virtual machine.
Select a language in the playground or use `/editor?language=simple` or `/editor?language=kindly`.

## Requirements

- Godot 4.7.2.
- Node.js >=22.23.4 and npm for the website.
- Python >=3.9 and Git for building the custom web export template.

## Development

Import and open the runtime from the repository root:

```sh
godot --headless --editor --path runtime --import --quit
godot --editor --path runtime
```

The main scene hosts the browser bridge. Run the playground through the website:

```sh
cd website
npm ci
npm run runtime:template
npm run runtime:export
npm run dev
```

Build the template once per checkout and rebuild after changing its profile or Godot version.
Set `GODOT_BIN` if Godot is not on PATH. See [website/README.md](website/README.md) for build commands
and runtime export details.

## Tests

Run after importing the runtime:

```sh
godot --headless --path runtime --script res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/unit -rd res://.godot/gdunit-reports
godot --headless --path runtime --script res://tests/frontend/simple/run_declaration_tests.gd
godot --headless --path runtime --script res://tests/frontend/run_language_tests.gd
npm --prefix website test
```

VS Code tasks cover runtime import, editor launch, tests, and website development.

## Repository layout

| Path              | Contents                                                |
| ----------------- | ------------------------------------------------------- |
| `runtime/engine/` | Lexer, compiler, virtual machine, and standard library. |
| `runtime/web/`    | Browser bridge, HTML shell, and template build profile. |
| `runtime/tests/`  | Runtime tests.                                          |
| `website/`        | Astro site and React playground.                        |
| `docs/`           | Language documentation.                                 |

Godot's `res://` paths are relative to `runtime/`. The interpreter entry point is
[`runtime/engine/interpreter.gd`](runtime/engine/interpreter.gd).

## Credits

Based on Robert Nystrom's [Crafting Interpreters](https://craftinginterpreters.com/).

## License

[MIT](LICENSE). Austin Kong [@AustinKong](https://github.com/AustinKong).
