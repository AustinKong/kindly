"""Build Kindly's small web template. Requires Python and Git; tools stay local."""

import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import zipfile

GODOT_VERSION = "4.7.2-stable"
EMSCRIPTEN_VERSION = "4.0.20"
SCONS_VERSION = "4.10.1"
ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "runtime/build"
TOOLS = BUILD / "toolchain"


def run(*args, **kwargs):
    subprocess.run([str(arg) for arg in args], check=True, **kwargs)


def clone(name, url, tag):
    destination = TOOLS / name
    if not destination.exists():
        run("git", "clone", "--depth", "1", "--branch", tag, url, destination)
    version = subprocess.check_output(
        ["git", "-C", str(destination), "describe", "--tags", "--exact-match"], text=True
    ).strip()
    if version != tag:
        raise RuntimeError(f"{destination} is {version}, expected {tag}. Use a fresh toolchain cache.")
    return destination


BUILD.mkdir(parents=True, exist_ok=True)
(BUILD / ".gdignore").touch()
TOOLS.mkdir(exist_ok=True)
godot = clone("godot", "https://github.com/godotengine/godot.git", GODOT_VERSION)
emsdk = clone("emsdk", "https://github.com/emscripten-core/emsdk.git", EMSCRIPTEN_VERSION)
python = TOOLS / "python" / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
if not python.exists():
    run(sys.executable, "-m", "venv", TOOLS / "python")
run(python, "-m", "pip", "install", f"scons=={SCONS_VERSION}")
run(python, emsdk / "emsdk.py", "install", EMSCRIPTEN_VERSION)
run(python, emsdk / "emsdk.py", "activate", EMSCRIPTEN_VERSION, "--embedded")

# Ask the SDK for its environment without changing the user's shell or PATH.
env = os.environ.copy()
env.pop("EMSDK_CMD", None)
env.pop("EMSDK_POWERSHELL", None)
env.pop("EMSDK_BASH", None)
env["EMSDK_CMD" if os.name == "nt" else "EMSDK_BASH"] = "1"
exports = subprocess.check_output(
    [str(python), str(emsdk / "emsdk.py"), "construct_env"], env=env, text=True
)
if os.name == "nt":
    exports = (emsdk / "emsdk_set_env.bat").read_text()
for line in exports.splitlines():
    if line.upper().startswith("SET "):
        key, value = line[4:].split("=", 1)
        if value:
            env[key] = value
        else:
            env.pop(key, None)
    elif line.startswith("export "):
        key, value = shlex.split(line)[1].split("=", 1)
        env[key] = value
    elif line.startswith("unset "):
        env.pop(line.split()[1].rstrip(";"), None)

run(
    python,
    "-m",
    "SCons",
    "platform=web",
    "target=template_release",
    "optimize=size_extra",
    f"profile={ROOT / 'runtime/web/template.py'}",
    f"-j{min(os.cpu_count() or 2, 8)}",
    cwd=godot,
    env=env,
)
templates = list((godot / "bin").glob("godot.web.template_release*.zip"))
if len(templates) != 1:
    raise RuntimeError(f"Expected one release template, found {templates}")
with zipfile.ZipFile(templates[0]) as archive:
    wasm = archive.getinfo("godot.wasm")
    if wasm.file_size >= 25 * 1024 * 1024:
        raise RuntimeError(f"Template WASM is still too large: {wasm.file_size} bytes")
destination = BUILD / "web-template.zip"
shutil.copyfile(templates[0], destination)
print(f"Template ready: {destination} ({wasm.file_size / 1024 / 1024:.1f} MiB WASM)")
