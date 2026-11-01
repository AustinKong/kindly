# Kindly website

Astro/React site with a CodeMirror editor and a Godot WebAssembly interpreter.
Run commands from `website/`.

## Requirements

- Node.js >=22.23.4 and npm.
- Godot 4.7.2, available as `godot` or through `GODOT_BIN`.
- Python >=3.9 and Git for the initial template build.

## Development

```sh
npm ci
npm run runtime:template
npm run runtime:export
npm run dev
```

`runtime:template` builds the custom Godot release template using SCons and Emscripten. Toolchain
versions are pinned in `scripts/build-template.py`; engine features are configured in
`../runtime/web/template.py`. Rebuild after changing the profile or Godot version.

Generated toolchains, template, and exports are cached under `../runtime/build/` and ignored by Git.
The export is copied to `public/runtime/`. Re-export after changing GDScript.

Use a Godot executable native to the shell running the build. In WSL, use Linux Godot with a Linux
path; run Windows Godot builds from PowerShell.

## Commands

| Command                      | Purpose                                                |
| ---------------------------- | ------------------------------------------------------ |
| `npm run dev`                | Development server.                                    |
| `npm run dev:background`     | Background development server.                         |
| `npm run astro -- dev stop`  | Stop the background server.                            |
| `npm run runtime:template`   | Build the custom web export template.                  |
| `npm run runtime:export`     | Export the Godot runtime.                              |
| `npm run build`              | Export the runtime and build the site into `dist/`.    |
| `npm run build:site`         | Build the site using an existing runtime export.       |
| `npm run preview`            | Preview `dist/` locally.                               |
| `npm run preview:cloudflare` | Preview through Wrangler.                              |
| `npm run deploy`             | Build and deploy static assets using `wrangler.jsonc`. |
| `npm run format`             | Format source files.                                   |
| `npm run format:check`       | Check formatting.                                      |

Deployment requires Wrangler authentication. Build environments need Godot and the custom template;
`build:site` alone is insufficient in a clean checkout.

## Source layout

- `src/pages/`: routes.
- `src/layouts/`: page shell.
- `src/components/playground/`: runtime coordination, editor, and console.
- `src/styles/`: shared styles.
- `public/`: static assets and generated runtime export.

The playground communicates with a headless, single-threaded Godot runtime through a same-origin
iframe. Execution runs on the browser's main thread with a VM instruction budget.
