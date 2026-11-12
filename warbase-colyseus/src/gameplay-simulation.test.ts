import assert from 'node:assert/strict';
import test from 'node:test';
import { grenadeDamageAt, grenadeVehicleDamageAt, GrenadeSimulation, validateGrenadeLaunch } from './grenade-simulation.js';
import { INDUSTRIAL_SPAWNS, INDUSTRIAL_VEHICLE_SPAWNS } from './world-geometry.js';

test('authored Industrial vehicle spawns are present and finite', () => {
  assert.equal(INDUSTRIAL_VEHICLE_SPAWNS.length, 2);
  assert.deepEqual(INDUSTRIAL_VEHICLE_SPAWNS[0], [-20, 0.5, 20, 0]);
  assert.deepEqual(INDUSTRIAL_VEHICLE_SPAWNS[1], [20, 0.5, 20, 1.57079637050629]);
  for (const spawn of [...INDUSTRIAL_SPAWNS, ...INDUSTRIAL_VEHICLE_SPAWNS]) assert.ok(spawn.every(Number.isFinite));
});

test('grenade launch rejects malformed, excessive, remote, blocked, and rate-limited requests', () => {
  const player: [number, number, number] = [-20, 0.5, 20];
  const eye: [number, number, number] = [-20, 1.8, 20];
  const base = { owner: 'alice', kind: 'frag', position: [-20, 1.4, 20] as [number, number, number], velocity: [1, 4, -8] as [number, number, number] };
  assert.equal(validateGrenadeLaunch(base, player, eye, 'frag', 0, 2000, 2), true);
  assert.equal(validateGrenadeLaunch({ ...base, velocity: [0, 31, 0] }, player, eye, 'frag', 0, 2000, 2), false);
  assert.equal(validateGrenadeLaunch({ ...base, position: [-10, 1.4, 20] }, player, eye, 'frag', 0, 2000, 2), false);
  assert.equal(validateGrenadeLaunch({ ...base, kind: 'impact' }, player, eye, 'frag', 0, 2000, 2), false);
  assert.equal(validateGrenadeLaunch(base, player, eye, 'frag', 1500, 2000, 2), false);
  assert.equal(validateGrenadeLaunch(base, player, eye, 'frag', 0, 2000, 0), false);
  assert.equal(validateGrenadeLaunch({ ...base, position: [Number.NaN, 1, 1] }, player, eye, 'frag', 0, 2000, 2), false);
});

test('fuse and impact grenades simulate and produce authoritative explosion positions', () => {
  const frag = new GrenadeSimulation();
  const spawn = INDUSTRIAL_SPAWNS[0];
  const launched = frag.launch({ owner: 'alice', kind: 'frag', position: [spawn[0], spawn[1] + 1.3, spawn[2]], velocity: [0, 0, 0] });
  assert.ok(launched);
  for (let i = 0; i < 29; i++) assert.equal(frag.step(0.1).length, 0);
  const blast = frag.step(0.25);
  assert.equal(blast.length, 1);
  assert.equal(blast[0].owner, 'alice');
  assert.equal(blast[0].id, launched.id);
  assert.equal(frag.grenades.length, 0);

  const impact = new GrenadeSimulation();
  assert.ok(impact.launch({ owner: 'bob', kind: 'impact', position: [spawn[0], spawn[1], spawn[2]], velocity: [0, 0, 0] }));
  assert.equal(impact.step(0.25).length, 0);
  assert.equal(impact.step(0.1).length, 1);
});

test('explosions use distance falloff and actual map occlusion', () => {
  assert.equal(grenadeDamageAt('frag', [0, 1.5, 0], [0, 1.5, 0]), 90);
  assert.ok(grenadeDamageAt('frag', [0, 1.5, 0], [4, 1.5, 0]) > 0);
  assert.equal(grenadeDamageAt('impact', [0, 1.5, 0], [6, 1.5, 0]), 0);
  assert.equal(grenadeDamageAt('frag', [-12, 1.1, -10], [-8, 1.1, -10]), 0, 'Industrial warehouse wall blocks blast LOS');
  assert.equal(grenadeVehicleDamageAt('frag', [0, 1.5, 0], [0, 1.5, 0]), 360);
});

test('grenade system rejects non-finite time and invalid throwables without leaking active projectiles', () => {
  const sim = new GrenadeSimulation();
  assert.equal(sim.launch({ owner: 'x', kind: 'frag', position: [0, 0, 0], velocity: [Number.NaN, 0, 0] }), null);
  assert.equal(sim.launch({ owner: 'x', kind: 'smoke', position: [0, 0, 0], velocity: [0, 0, 0] }), null);
  assert.deepEqual(sim.step(Number.NaN), []);
  assert.equal(sim.grenades.length, 0);
  sim.clear();
  assert.equal(sim.grenades.length, 0);
});
