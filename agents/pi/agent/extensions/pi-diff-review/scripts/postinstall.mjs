import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const target = join(process.cwd(), 'node_modules', 'glimpseui', 'src', 'chromium-backend.mjs');

const source = readFileSync(target, 'utf8');
const original = `  for (const name of candidates) {\n    try {\n      const path = execSync(\`which \${name}\`, { encoding: 'utf8', timeout: 2000 }).trim();\n      if (path) return path;\n    } catch {}\n  }\n`;
const patched = `  for (const name of candidates) {\n    try {\n      const path = execFileSync('which', [name], {\n        encoding: 'utf8',\n        timeout: 2000,\n        stdio: ['ignore', 'pipe', 'ignore'],\n      }).trim();\n      if (path) return path;\n    } catch {}\n  }\n`;

if (source.includes(patched)) {
  console.log('glimpseui chromium lookup already patched');
} else if (source.includes(original)) {
  writeFileSync(target, source.replace(original, patched));
  console.log('patched glimpseui chromium lookup');
} else {
  console.warn('glimpseui chromium lookup patch target not found');
}
