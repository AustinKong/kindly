# Kindly website

This directory will contain the browser editor, controls, and output display. The web framework and editor library have not been selected yet.

The language implementation lives in `../runtime/`. Godot resource paths stay relative to that project; website files are outside the Godot resource tree.

The future bridge will send source to Godot and receive printed output, completion, or a structured error. That bridge and a Godot web export entry scene are not implemented yet.

Generate Godot web exports under `runtime/build/web/`, then copy their assets into the website during its build. Keep generated exports, `node_modules/`, and `website/dist/` out of Git.
