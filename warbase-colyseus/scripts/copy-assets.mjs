import { cpSync, mkdirSync } from 'node:fs';
mkdirSync('dist/data', { recursive: true });
cpSync('src/data', 'dist/data', { recursive: true });
