import { cp, mkdir, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const runtime = fileURLToPath(new URL('../../runtime/', import.meta.url));
const exported = fileURLToPath(new URL('../../runtime/build/web/', import.meta.url));
const destination = fileURLToPath(new URL('../public/runtime/', import.meta.url));

await mkdir(exported, { recursive: true });
await writeFile(`${runtime}/build/.gdignore`, '');
const result = spawnSync(
  process.env.GODOT_BIN || 'godot',
  ['--headless', '--path', runtime, '--export-release', 'Web', `${exported}/index.html`],
  { stdio: 'inherit' }
);
if (result.error || result.status !== 0) {
  console.error(result.error?.message || 'Godot web export failed.');
  console.error(
    'Set GODOT_BIN to your Godot executable and install matching web export templates.'
  );
  process.exit(1);
}
await mkdir(destination, { recursive: true });
await cp(exported, destination, { recursive: true });
console.log('Godot runtime exported to website/public/runtime/.');
