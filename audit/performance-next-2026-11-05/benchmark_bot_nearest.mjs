import { performance } from 'node:perf_hooks';
import { BotSimulation } from '../../warbase-colyseus/src/bot-simulation.ts';

const nodeCount = 2_000;
const pointCount = 40;
const measuredIterations = 1_500;
const warmupIterations = 4;
const rounds = 5;
const geometry = {
  name: 'bot-nearest-benchmark',
  navStep: 1,
  spawns: [],
  traceCalls: 0,
  trace() { this.traceCalls++; return null; },
  rayBlocked() { return false; },
  resolveMove(_from, to) { return to; },
};
const nodes = Array.from({ length: nodeCount }, (_, i) => ({
  position: [(i % 100) - 50, 0, Math.floor(i / 100) - 10],
  edges: [],
}));
const points = Array.from({ length: pointCount }, (_, i) => [i % 20 - 10, 0, Math.floor(i / 20)]);
const sim = new BotSimulation(geometry);

// Reference implementation from before the squared-distance optimization.
function previousNearest(point) {
  let nearest = -1;
  let best = 9;
  for (let i = 0; i < nodes.length; i++) {
    const position = nodes[i].position;
    const distance = Math.hypot(point[0] - position[0], point[1] - position[1], point[2] - position[2]);
    if (distance < best && Math.abs(point[1] - position[1]) < 1 && !movementBlocked(point, position)) {
      best = distance;
      nearest = i;
    }
  }
  return nearest;
}
function movementBlocked(from, to) {
  for (const offset of [[0, 0.9, 0], [-0.25, 0.9, 0], [0.25, 0.9, 0], [0, 0.9, -0.25], [0, 0.9, 0.25]]) {
    geometry.trace([from[0] + offset[0], from[1] + offset[1], from[2] + offset[2]], [to[0] + offset[0], to[1] + offset[1], to[2] + offset[2]]);
  }
  return false;
}
const optimizedNearest = (point) => sim.nearest(nodes, point);

function run(fn) {
  let checksum = 0;
  const started = performance.now();
  for (let iteration = 0; iteration < measuredIterations; iteration++) {
    for (const point of points) checksum += fn(point);
  }
  return { elapsedMs: performance.now() - started, checksum };
}
for (let i = 0; i < warmupIterations; i++) {
  for (const point of points) {
    if (previousNearest(point) !== optimizedNearest(point)) throw new Error('nearest result mismatch during warmup');
  }
}
const samples = { previous: [], optimized: [] };
const checksums = {};
for (let round = 0; round < rounds; round++) {
  const order = round % 2 === 0 ? [['previous', previousNearest], ['optimized', optimizedNearest]] : [['optimized', optimizedNearest], ['previous', previousNearest]];
  for (const [name, fn] of order) {
    const result = run(fn);
    samples[name].push(result.elapsedMs);
    checksums[name] = result.checksum;
  }
}
const median = (values) => [...values].sort((a, b) => a - b)[Math.floor(values.length / 2)];
const previousMedianMs = median(samples.previous);
const optimizedMedianMs = median(samples.optimized);
const result = {
  benchmark: 'bot-nearest-squared-distance',
  date: new Date().toISOString(),
  node: process.version,
  platform: `${process.platform}/${process.arch}`,
  workload: { nodeCount, pointCount, iterationsPerSample: measuredIterations, warmupIterations, rounds },
  collisionMock: 'trace always returns no hit; movementBlocked still performs all 5 traces for accepted candidates',
  equivalence: {
    checksPassed: warmupIterations * pointCount,
    previousChecksum: checksums.previous,
    optimizedChecksum: checksums.optimized,
    sameChecksum: checksums.previous === checksums.optimized,
  },
  samplesMs: samples,
  medianMs: { previous: previousMedianMs, optimized: optimizedMedianMs },
  speedup: previousMedianMs / optimizedMedianMs,
  traceCalls: geometry.traceCalls,
};
if (!result.equivalence.sameChecksum) throw new Error('benchmark checksum mismatch');
process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
