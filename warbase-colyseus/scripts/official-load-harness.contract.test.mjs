import test from 'node:test';
import assert from 'node:assert/strict';
import { admissionCacheReusable, evaluateSteadySample, peerDropExpired, stageVehicleControls, vehiclePosition } from './official-load-harness.mjs';

const fullLiveSample = {
  gateOpen: true,
  stateFresh: true,
  liveClients: 64,
  humanPlayers: 64,
  observerPresent: true,
  cohortOpen: true,
};

test('cached full schema is rejected when the live room has no clients', () => {
  assert.equal(evaluateSteadySample({ ...fullLiveSample, liveClients: 0 }), false);
});

test('steady occupancy is rejected when any cohort connection is closed', () => {
  assert.equal(evaluateSteadySample({ ...fullLiveSample, cohortOpen: false }), false);
});

test('steady occupancy accepts only a fresh, connected, full live room', () => {
  assert.equal(evaluateSteadySample(fullLiveSample), true);
  assert.equal(evaluateSteadySample({ ...fullLiveSample, stateFresh: false }), false);
  assert.equal(evaluateSteadySample({ ...fullLiveSample, gateOpen: false }), false);
});

test('brief automatic reconnect gaps are non-full but tolerated; expired gaps fail', () => {
  const droppedSample = { ...fullLiveSample, cohortOpen: false };
  assert.equal(evaluateSteadySample(droppedSample), false);
  assert.equal(peerDropExpired(10_000, 11_900), false);
  assert.equal(peerDropExpired(10_000, 12_001), true);
  assert.equal(peerDropExpired(0, 100_000), false);
  assert.equal(evaluateSteadySample(fullLiveSample), true);
});

test('vehicle input carries the player seat index and generation', () => {
  const data = {};
  stageVehicleControls(data, { driving_vehicle: 'CAR_2', vehicle_index: 2, vehicle_generation: 9 }, Math.PI / 2);
  assert.deepEqual(data, {
    vehicle_index: 2,
    vehicle_generation: 9,
    vehicle_throttle: 0.65,
    vehicle_steer: 0.25,
    vehicle_brake: 0,
    vehicle_gear: 1,
  });
});

test('vehicle input is neutral while on foot', () => {
  const data = {};
  stageVehicleControls(data, { vehicle_index: -1, vehicle_generation: 12 }, 1);
  assert.deepEqual(data, {
    vehicle_index: -1,
    vehicle_generation: 12,
    vehicle_throttle: 0,
    vehicle_steer: 0,
    vehicle_brake: 1,
    vehicle_gear: 1,
  });
});

test('admission cache requires matching endpoint, ticket count, and full remaining horizon', () => {
  const cache = { endpoint: 'https://war.vaidik.blog/colyseus', tickets: [
    { token: 'opaque-a', expiresAt: 5000 },
    { token: 'opaque-b', expiresAt: 5000 },
  ] };
  const criteria = { endpoint: cache.endpoint, count: 2, nowMs: 1000, minimumRemainingMs: 3000 };
  assert.equal(admissionCacheReusable(cache, criteria), true);
  assert.equal(admissionCacheReusable(cache, { ...criteria, endpoint: 'https://example.test' }), false);
  assert.equal(admissionCacheReusable(cache, { ...criteria, count: 63 }), false);
  assert.equal(admissionCacheReusable({ ...cache, tickets: [{ ...cache.tickets[0], expiresAt: 3999 }, cache.tickets[1]] }, criteria), false);
});

test('vehicle position prefers protocol-7 scalars with legacy array fallback', () => {
  assert.deepEqual(vehiclePosition({x:1,y:2,z:3,pos:[9,9,9]}),[1,2,3]);
  assert.deepEqual(vehiclePosition({pos:[4,5,6]}),[4,5,6]);
  assert.equal(vehiclePosition({x:NaN,y:0,z:0}),null);
});
