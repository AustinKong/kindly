# Kindly website

Astro and React provide the browser UI. The language implementation lives in `../runtime/`.

From this directory:

| Command                       | Purpose                                     |
| ----------------------------- | ------------------------------------------- |
| `npm ci`                      | Install locked dependencies.                |
| `npm run dev -- --background` | Start the Astro development server.         |
| `npm run astro -- dev stop`   | Stop the background server.                 |
| `npm run build`               | Export Godot and build the site in `dist/`. |
| `npm run preview`             | Preview the production build.               |
| `npm run format`              | Format the website.                         |
| `npm run format:check`        | Check formatting.                           |

From the repository root, use `npm --prefix website run <script>` or the Website tasks in VS Code.

`src/layouts/` holds the page shell, `src/pages/` defines routes, `src/styles/` holds shared styles,
and `public/` contains static assets. Formatting uses two spaces, single quotes, and a 100-character
line width. Godot keeps its own GDScript formatting settings.

The homepage is a landing page with editable syntax examples and uses `public/images/hero.png` for its full-width banner. `/docs` contains a documentation starter page.

The `/editor` page mounts a React playground island with `client:load`. CodeMirror uses tab indentation and LF (`\n`) line endings, including pasted text, so the bridge passes source directly to the interpreter.
Send runs the editor source in the Godot interpreter and adds a reply to the inbox with that run's
output and any error. Replies can be selected or cleared; inbox history lasts until the page is
closed or refreshed. Each run starts a fresh interpreter session.

## Icons

Use Lucide SVG components directly: import icons from `@lucide/astro` in Astro pages and
`lucide-react` in React components. For example, `import { ArrowRight } from '@lucide/astro'`
or `import { Send } from 'lucide-react'`. Set `aria-hidden="true"` on decorative icons and give
icon-only buttons an accessible label. Both packages use the same icon set and inherit text color.

## Godot web runtime

Install the web export templates matching your Godot version. Set `GODOT_BIN` if `godot` is not on PATH:

```powershell
$env:GODOT_BIN = 'C:\path\to\godot.exe'
npm run runtime:export
npm run dev -- --background
```

`runtime:export` exports `../runtime/` using its Web preset into `runtime/build/web/` and copies the
generated files to `public/runtime/`. Both locations are ignored by Git. Run the export again after
changing GDScript. `npm run build` exports first; `npm run build:site` rebuilds only Astro using the
existing export.

The Godot runtime runs in a tiny same-origin iframe, leaving the visible UI to React. Its main scene
retains a `JavaScriptBridge.create_callback` reference and exposes it on the parent window. Source is
passed as a string, never interpolated into JavaScript. A deferred Godot call invokes
`Interpreter.interpret()` and collects print output before signalling completion.

| Parent-window global     | Contract                                                              |
| ------------------------ | --------------------------------------------------------------------- |
| `run(source, runId)`     | Installed by Godot when ready; requests one interpretation.           |
| `onReady()`              | Installed by the website; enables Run after Godot initializes.        |
| `onDone(resultJson)`     | Installed by the website; receives one JSON result per completed run. |
| `onBridgeError(message)` | Reports a web-runtime startup or bridge error.                        |

The completion result is `{ runId, ok, output: string[], error }`. Errors include `phase`, `message`,
zero-based `line`, and `stackTrace`; scan/compile errors also include `start` and `length`. The UI adds
one to source lines for display and preserves output printed before an error. It ignores completion
results belonging to another request. The component removes its callbacks and iframe when unmounted.

The export uses the compatibility renderer and single-thread web templates. Execution currently
runs on the browser's main thread within the existing VM instruction budget; this is not a worker
or a cancellable execution API. The deployment target remains undecided.
