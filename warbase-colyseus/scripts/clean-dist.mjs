import { rmSync } from 'node:fs';
// A clean build must not retain modules removed from the source tree.
rmSync(new URL('../dist/', import.meta.url), { recursive: true, force: true });
