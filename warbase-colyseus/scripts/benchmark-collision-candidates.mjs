#!/usr/bin/env node
/** Compare bounded BVH candidate reuse without changing the production source. */
import assert from 'node:assert/strict';
import { mkdtemp, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { performance } from 'node:perf_hooks';
import ts from 'typescript';

const sourceUrl = new URL('../src/world-geometry.ts', import.meta.url);
const source = await readFile(sourceUrl, 'utf8');
const temporary = await mkdtemp(path.join(tmpdir(), 'warbase-collision-cap-'));
try {
  const variants = [];
  for (const cap of [16, 32, 64, 128, 256, 512]) {
    const variant = source.replace(/const maximumReusableTriangles = \d+;/,
      `const maximumReusableTriangles = ${cap};`).replaceAll('import.meta.url', JSON.stringify(sourceUrl.href));
    const result = ts.transpileModule(variant, { compilerOptions: {
      target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022, useDefineForClassFields: false,
    } });
    const file = path.join(temporary, `cap-${cap}.mjs`);
    await writeFile(file, result.outputText);
    variants.push({ cap, module: await import(pathToFileURL(file).href), rounds: [] });
  }
  const baseline = variants.find(v => v.cap === 32).module;
  const workload = [];
  for (const map of baseline.PLAYABLE_MAPS) {
    for (const from of baseline.loadWorldGeometry(map).spawns.slice(0, 16)) {
      for (let i = 0; i < 12; i++) workload.push({ map, from,
        to: [from[0] + Math.sin(i) * 0.146, from[1] - 0.005, from[2] + Math.cos(i) * 0.146] });
    }
  }
  for (const variant of variants) for (const item of workload) {
    assert.deepEqual(variant.module.loadWorldGeometry(item.map).resolveMove(item.from, item.to),
      baseline.loadWorldGeometry(item.map).resolveMove(item.from, item.to));
  }
  // Alternate order, discard warm-up, and report raw rounds as well as median.
  for (let round = -1; round < 5; round++) {
    for (const variant of round % 2 ? variants.toReversed() : variants) {
      const start = performance.now();
      for (let repeat = 0; repeat < 3; repeat++) for (const item of workload) {
        variant.module.loadWorldGeometry(item.map).resolveMove(item.from, item.to);
      }
      if (round >= 0) variant.rounds.push(performance.now() - start);
    }
  }
  console.log(JSON.stringify({ scope: '10-map movement microbenchmark; not whole-server throughput',
    exactParityCases: workload.length, movesPerRound: workload.length * 3,
    results: variants.map(({ cap, rounds }) => ({ cap, rounds, median: rounds.toSorted((a, b) => a - b)[2] })),
  }, null, 2));
} finally {
  await rm(temporary, { recursive: true, force: true });
}
