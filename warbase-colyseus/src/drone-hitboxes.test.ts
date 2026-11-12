import assert from 'node:assert/strict';
import test from 'node:test';
import { traceDroneHit } from './drone-hitboxes.js';

test('drone hit sphere reports torso and first segment intersection', () => {
  const hit = traceDroneHit([-2, 0, 0], [2, 0, 0], [0, 0, 0]);
  assert.equal(hit?.zone, 'torso');
  assert.ok(Math.abs((hit?.fraction ?? 0) - 0.3875) < 1e-12);
});

test('drone hit sphere rejects misses and intersections beyond segment', () => {
  assert.ok(traceDroneHit([-2, 0.44, 0], [2, 0.44, 0], [0, 0, 0]));
  assert.equal(traceDroneHit([-2, 0.46, 0], [2, 0.46, 0], [0, 0, 0]), null);
  assert.equal(traceDroneHit([-2, 0, 0], [-1, 0, 0], [0, 0, 0]), null);
});

test('drone hit sphere handles rays starting inside', () => {
  assert.deepEqual(traceDroneHit([0, 0, 0], [2, 0, 0], [0, 0, 0]), { zone: 'torso', fraction: 0 });
});
